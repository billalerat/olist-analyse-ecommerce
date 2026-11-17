--Le CA dépend-il de quelques vendeurs ?
--Résultat clé 1 : 18 % des vendeurs (531 sur 2 945) font 80 % du CA des commandes livrées (test de Pareto).
--Résultat clé 2 : parmi les 100 plus gros vendeurs par CA, celui de rang 59 est le moins bien noté, avec 2,79/5.


-- Classement des vendeurs par CA, avec part du CA et part cumulée
with ca_vendeur as (
    select oi.seller_id, sum(oi.price) as ca
    from order_items oi
    join orders o on o.order_id = oi.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by oi.seller_id
)
select seller_id,
       round(ca, 2) as ca,
       rank() over (order by ca desc) as rang,
       round(ca * 100.0 / sum(ca) over (), 2) as pct_ca,
       round(sum(ca) over (order by ca desc, seller_id) * 100.0 / sum(ca) over (), 2) as pct_ca_cumule
from ca_vendeur
order by rang;


-- Test de Pareto : combien de vendeurs font 80 % du CA ?
with ca_vendeur as (
    select oi.seller_id, sum(oi.price) as ca
    from order_items oi
    join orders o on o.order_id = oi.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by oi.seller_id
),
classement as (
    select seller_id,
           sum(ca) over (order by ca desc, seller_id) * 100.0 / sum(ca) over () as pct_ca_cumule
    from ca_vendeur
)
select count(*) as nb_vendeurs,
       count(*) filter (where pct_ca_cumule < 80) + 1 as nb_vendeurs_80_pct_ca,
       round((count(*) filter (where pct_ca_cumule < 80) + 1) * 100.0 / count(*), 2) as pct_vendeurs
from classement;


-- Les 100 premiers vendeurs par CA, avec leur note moyenne 
create or replace view top100_notes as
with ca_vendeur as (
    select oi.seller_id, sum(oi.price) as ca
    from order_items oi
    join orders o on o.order_id = oi.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
    group by oi.seller_id
),
top100 as (
    select seller_id, ca, rank() over (order by ca desc) as rang
    from ca_vendeur
    order by ca desc
    limit 100
),
note_commande as (
    select order_id, avg(review_score) as note
    from order_reviews
    group by order_id
),
commande_vendeur as (
    select distinct oi.seller_id, oi.order_id
    from order_items oi
    join orders o on o.order_id = oi.order_id
    where o.order_status = 'delivered'
      and o.order_purchase_timestamp >= '2017-01-01'
      and o.order_purchase_timestamp < '2018-09-01'
),
note_vendeur as (
    select cv.seller_id,
           avg(nc.note) as note_moyenne,
           count(*) as nb_commandes_notees
    from commande_vendeur cv
    join note_commande nc on nc.order_id = cv.order_id
    group by cv.seller_id
)
select t.rang, t.seller_id, t.ca,
       n.note_moyenne, n.nb_commandes_notees
from top100 t
join note_vendeur n on n.seller_id = t.seller_id;


-- Les 10 vendeurs les moins bien notés parmi les 100 premiers par CA
select rang, seller_id, round(ca, 2) as ca,
       round(note_moyenne, 2) as note_moyenne, nb_commandes_notees
from top100_notes
order by note_moyenne asc, ca desc
limit 10;


-- Note moyenne des 100 premiers vendeurs par CA
select count(*) as nb_vendeurs,
       round(avg(note_moyenne), 2) as note_moyenne_des_vendeurs,
       round(sum(note_moyenne * nb_commandes_notees) / sum(nb_commandes_notees), 2) as note_moyenne_ponderee_par_commande
from top100_notes;
