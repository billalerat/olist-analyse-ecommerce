--Qui sont les clients à forte valeur ?
--Résultat clé : le segment à risque (forte valeur, dernier achat ancien) pèse 29,22 % du CA, presque autant que les champions (30,61 %).


with payment as (select 
op.payment_value as montant,
date_trunc('month', o.order_purchase_timestamp) as order_month,
o.customer_id,
o.order_id,
order_purchase_timestamp
from orders as o
JOIN order_payments as op on op.order_id=o.order_id
where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'),
premier as (select customer_unique_id, max(p.order_purchase_timestamp) as last_order,COUNT(DISTINCT(p.order_id)) as frequency, sum(montant) as monetary 
from customers as c
JOIN payment as p on c.customer_id = p.customer_id
group by customer_unique_id),
deuxieme as (select customer_unique_id,last_order,frequency,monetary,DATE_DIFF( 'day', last_order,'2018-09-01' ) as recency_days, 
NTILE(5) over(order by last_order ) as r_score,
ntile(5) over (order by monetary ) as m_score,
CASE
    when r_score>=4 and m_score>=4 then 'champions'
    when r_score<=2 and m_score>=4 then 'a_risque'
    when r_score>=4 and m_score<=2 then 'nouveaux'
    when r_score<=2 and m_score<=2 then 'perdu'
    else 'autres'
    end as segment
from premier
)

select segment,
count(customer_unique_id) as nb_clients,
sum(monetary) as montant_segment,
round(sum(monetary) * 100.0 / sum(sum(monetary)) over(), 2) as pct_montant
from deuxieme
group by segment
order by montant_segment desc;