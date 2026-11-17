--Les clients reviennent-ils ?


with premier_achat as (select c.customer_unique_id, 
    date_trunc('month', min(o.order_purchase_timestamp)) as first_order_month
    from customers as c
    join orders as o on o.customer_id=c.customer_id
    where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
    group by c.customer_unique_id
    ),
    activite as (select c.customer_unique_id, 
    date_trunc('month', o.order_purchase_timestamp) as order_month
    from customers as c
    join orders as o on o.customer_id=c.customer_id
    where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
    group by c.customer_unique_id, order_month
    )

select first_order_month,
DATE_DIFF('month', first_order_month, order_month) as month_number,
count(DISTINCT(a.customer_unique_id)) as customers,
round(count(DISTINCT a.customer_unique_id) * 100.0
    / first_value(count(DISTINCT a.customer_unique_id)) over (partition by first_order_month order by month_number), 2) as retention_pct
from activite as a
join premier_achat as pa on a.customer_unique_id=pa.customer_unique_id
GROUP BY first_order_month,month_number
order by first_order_month, month_number;


-- Rétention moyenne à l'écart 1 et aux écarts suivants (cohorte d'août 2018 exclue)
-- Un écart n'est compté que s'il est observable : le dernier mois des données est août 2018.
with premier_achat as (select c.customer_unique_id,
    date_trunc('month', min(o.order_purchase_timestamp)) as first_order_month
    from customers as c
    join orders as o on o.customer_id=c.customer_id
    where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
    group by c.customer_unique_id
    ),
    activite as (select c.customer_unique_id,
    date_trunc('month', o.order_purchase_timestamp) as order_month
    from customers as c
    join orders as o on o.customer_id=c.customer_id
    where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
    group by c.customer_unique_id, order_month
    ),
    cohortes as (select first_order_month,
    DATE_DIFF('month', first_order_month, order_month) as month_number,
    count(DISTINCT a.customer_unique_id) as customers
    from activite as a
    join premier_achat as pa on a.customer_unique_id=pa.customer_unique_id
    group by first_order_month, month_number
    ),
    par_cohorte as (select first_order_month,
    sum(customers) filter (where month_number = 0) as taille,
    coalesce(sum(customers) filter (where month_number = 1), 0) as clients_ecart_1,
    coalesce(sum(customers) filter (where month_number >= 2), 0) as clients_ecarts_suivants,
    DATE_DIFF('month', first_order_month, (select max(first_order_month) from cohortes)) as nb_ecarts_observables
    from cohortes
    group by first_order_month
    )
select sum(clients_ecart_1) as clients_ecart_1,
       sum(taille) filter (where nb_ecarts_observables >= 1) as clients_ecart_0,
       round(sum(clients_ecart_1) * 100.0 / sum(taille) filter (where nb_ecarts_observables >= 1), 2) as retention_ecart_1_pct,
       sum(clients_ecarts_suivants) as clients_ecarts_suivants,
       sum(taille * greatest(nb_ecarts_observables - 1, 0)) as clients_ecart_0_x_ecarts_observables,
       round(sum(clients_ecarts_suivants) * 100.0 / sum(taille * greatest(nb_ecarts_observables - 1, 0)), 2) as retention_moyenne_ecarts_suivants_pct
from par_cohorte;
