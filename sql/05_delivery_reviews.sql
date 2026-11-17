--Les retards de livraison font-ils baisser les notes ?
--Résultat clé 1 : la note moyenne tombe à 1,70/5 pour les commandes livrées avec plus de 7 jours de retard, contre 4,32/5 pour celles livrées en avance de plus de 7 jours.
--Résultat clé 2 : parmi les États de plus de 500 commandes, le Maranhão (MA) est le plus touché, avec 17,21 % de commandes en retard et une note moyenne de 3,83/5.


-- Une ligne par commande livrée : retard, tranche de retard et note moyenne
create or replace view delivery_reviews as
with note as (
    select order_id, avg(review_score) as score_moyen
    from order_reviews
    group by order_id
)
select o.order_id,
       o.customer_id,
       date_trunc('month', o.order_purchase_timestamp) as order_month,
       date_diff('day', o.order_estimated_delivery_date, o.order_delivered_customer_date) as delay_days,
       n.score_moyen,
    case
       when delay_days<(-7) then '1_en_avance_de_plus_de_7_jours'
       when delay_days between -7 and 0 then '2_en_avance_de_7_jours_ou_moins'
       when delay_days between 1 and 3 then '3_retard_de_1_à_3_jours'
       when delay_days between 4 and 7 then '4_retard_de_4_à_7_jours'
       when 7<delay_days then '5_retard_de_plus_de_7_jours'
       end as delays
from orders o
join note n on n.order_id = o.order_id
where o.order_status = 'delivered'
  and o.order_purchase_timestamp >= '2017-01-01'
  and o.order_purchase_timestamp < '2018-09-01'
  and o.order_delivered_customer_date is not null;


-- Tableau 1 : note moyenne par tranche de retard
select delays,
       count(order_id) as nb_order,
       round(avg(score_moyen), 2) as note_moyenne
from delivery_reviews
group by delays
order by delays;


-- Tableau 2 : note moyenne et part de commandes en retard par État
select customer_state,
       round(avg(p.score_moyen), 2) as note_moyenne,
       count(p.order_id) as nb_order,
       round(count(*) filter (where p.delay_days > 0) * 100.0 / count(*), 2) as pct_retard
from customers as c
join delivery_reviews as p on c.customer_id=p.customer_id
group by customer_state
having nb_order>500
order by pct_retard desc;


-- Part des commandes livrées en retard (parmi les commandes livrées qui ont un avis)
select count(*) as nb_commandes,
       count(*) filter (where delay_days > 0) as nb_en_retard,
       round(count(*) filter (where delay_days > 0) * 100.0 / count(*), 2) as pct_en_retard
from delivery_reviews;
