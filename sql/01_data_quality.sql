-- =====================================================================
-- 1. PAIEMENTS (order_payments)
-- =====================================================================

-- Lignes entièrement dupliquées sur les cinq colonnes
select count(*) - (select count(*) from (select distinct * from order_payments)) as lignes_dupliquees
from order_payments;
-- Résultat attendu : 0

-- Unicité de la clé (order_id, payment_sequential)
select count(*) - count(distinct (order_id, payment_sequential)) as doublons_de_cle
from order_payments;
-- Résultat attendu : 0 

-- Nombre de commandes distinctes dans order_payments, à comparer aux commandes de orders
select (select count(distinct order_id) from order_payments) as commandes_avec_paiement,
       (select count(*) from orders) as commandes_total;
-- Résultat attendu : 99 440 pour 99 441

-- Commandes sans aucun paiement (et leur statut)
select o.order_id, o.order_status
from orders o
left join order_payments op on op.order_id = o.order_id
where op.order_id is null;
-- Résultat attendu : 1 commande, bfbd0f9bdef84302105ad712db648a6c, au statut delivered

-- Nombre maximal de paiements pour une même commande
select max(nb_paiements) as paiements_max
from (select order_id, count(*) as nb_paiements
      from order_payments
      group by order_id);
-- Résultat attendu : 29

-- Commandes à paiements multiples, et lignes en trop par rapport au nombre de commandes
select count(*) filter (where nb_paiements > 1) as commandes_paiements_multiples,
       sum(nb_paiements) - count(*) as lignes_en_plus
from (select order_id, count(*) as nb_paiements
      from order_payments
      group by order_id);
-- Résultat attendu : 2 961 commandes, 4 446 lignes en plus (103 886 lignes - 99 440 commandes)

-- Répartition des paiements par type
select payment_type, count(*) as nb_paiements
from order_payments
group by payment_type
order by nb_paiements desc;

-- Valeur minimale des paiements (détection de valeurs nulles ou négatives)
select min(payment_value) as paiement_min
from order_payments;
-- Résultat attendu : 0 


-- =====================================================================
-- 2. ARTICLES (order_items)
-- =====================================================================

-- Unicité de la clé (order_id, order_item_id)
select count(*) - count(distinct (order_id, order_item_id)) as doublons_de_cle
from order_items;
-- Résultat attendu : 0

-- Cohérence entre le nombre de lignes et le nombre de commandes
select count(*) as nb_lignes,
       count(distinct order_id) as nb_commandes,
       count(*) - count(distinct order_id) as difference
from order_items;
-- Résultat attendu : 112 650 lignes, 98 666 commandes, 13 984 lignes en plus

-- Commandes contenant plusieurs articles
select count(*) as commandes_multi_articles
from (select order_id
      from order_items
      group by order_id
      having count(*) > 1);
-- Résultat attendu : 9 803

-- Commandes de orders sans aucun article, par statut
select o.order_status, count(*) as nb_commandes
from orders o
left join order_items oi on oi.order_id = o.order_id
where oi.order_id is null
group by o.order_status
order by nb_commandes desc;
-- Résultat attendu : 775 commandes au total (603 unavailable, 164 canceled, 5 created,
-- 2 invoiced, 1 shipped), aucune livrée


-- =====================================================================
-- 3. AVIS (order_reviews)
-- =====================================================================

-- Lignes, commandes distinctes et lignes en trop
select count(*) as nb_lignes,
       count(distinct order_id) as nb_commandes,
       count(*) - count(distinct order_id) as lignes_en_trop
from order_reviews;
-- Résultat attendu : 99 224 lignes, 98 673 commandes, 551 lignes en trop

-- Commandes ayant plusieurs avis
select count(*) as commandes_avec_plusieurs_avis
from (select order_id
      from order_reviews
      group by order_id
      having count(*) > 1);
-- Résultat attendu : 547 commandes

-- Commandes sans aucun avis
select count(*) as commandes_sans_avis
from orders o
left join order_reviews r on r.order_id = o.order_id
where r.order_id is null;
-- Résultat attendu : 768 commandes 


-- =====================================================================
-- 4. CLIENTS (customers)
-- =====================================================================

-- Nombre de customer_id et de customer_unique_id distincts
select count(distinct customer_id) as nb_customer_id,
       count(distinct customer_unique_id) as nb_customer_unique_id
from customers;
-- Résultat attendu : 99 441 customer_id pour 96 096 customer_unique_id.
-- Un même client reçoit un nouveau customer_id à chaque commande 
-- Toute analyse client utilise donc customer_unique_id.

-- Clients récurrents (au moins deux commandes livrées)
with commandes_par_client as (
    select c.customer_unique_id,
           count(distinct o.order_id) as nb_commandes
    from customers c
    join orders o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id
)
select count(*) as total_clients,
       count(*) filter (where nb_commandes > 1) as clients_recurrents,
       round(count(*) filter (where nb_commandes > 1) * 100.0 / count(*), 2) as pct_recurrents
from commandes_par_client;
-- Résultat attendu : 2 801 clients récurrents sur 93 358, soit 3,00 %


-- =====================================================================
-- 5. COMMANDES (orders) ET PÉRIODE D'ANALYSE
-- =====================================================================

-- Part des commandes par statut
select order_status,
       count(*) as nb_commandes,
       round(count(*) * 100.0 / sum(count(*)) over (), 2) as pct
from orders
group by order_status
order by nb_commandes desc;
-- Résultat attendu : delivered = 96 478 commandes sur 99 441, soit 97,02 %

-- Nombre de commandes par mois 
select date_trunc('month', order_purchase_timestamp) as mois,
       count(*) as nb_commandes
from orders
group by mois
order by mois;
-- Constat : fin 2016 et fin 2018 quasi vides, d'où une analyse de janvier 2017 à août 2018.

-- Dates incohérentes sur les commandes livrées
select count(*) filter (where order_delivered_customer_date is null) as livrees_sans_date_livraison,
       count(*) filter (where order_delivered_customer_date < order_purchase_timestamp) as livraison_avant_achat
from orders
where order_status = 'delivered';


-- =====================================================================
-- 6. DÉFINITION DU CHIFFRE D'AFFAIRES
-- Commandes livrées du 1er janvier 2017 au 31 août 2018 (borne haute exclusive : < '2018-09-01').
-- Chaque table est agrégée par order_id avant la jointure avec orders.
-- =====================================================================

-- CA 1 : prix des articles
with prix as (
    select oi.order_id, sum(oi.price) as total
    from order_items oi
    join orders o on oi.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by oi.order_id
)
select sum(total) as ca_prix from prix;
-- Résultat attendu : 13 181 027,13

-- CA 2 : prix des articles + frais de port
with prix_port as (
    select oi.order_id, sum(oi.price + oi.freight_value) as total
    from order_items oi
    join orders o on oi.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by oi.order_id
)
select sum(total) as ca_prix_port from prix_port;
-- Résultat attendu : 15 373 120,01

-- CA 3 : somme des paiements (définition retenue)
with paiements as (
    select op.order_id, sum(op.payment_value) as total
    from order_payments op
    join orders o on op.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by op.order_id
)
select sum(total) as ca_paiements from paiements;
-- Résultat attendu : 15 375 875,44, soit 2 755,43 de plus que le CA 2 (0,02 %)
