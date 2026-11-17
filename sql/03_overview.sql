
    with CA as (
        select date_trunc('month', order_purchase_timestamp) as month,op.order_id,sum(op.payment_value) as total_price
        from order_payments op
        join orders o on op.order_id = o.order_id
        where o.order_status = 'delivered' and order_purchase_timestamp >= '2017-01-01' and order_purchase_timestamp < '2018-09-01'
        group by month, op.order_id
    )
    select month, 
    sum(total_price) as total_revenue, 
    count(order_id) as total_orders,
    round(sum(total_price)/count(order_id), 2) as average_revenue_per_order,
    round(sum(total_price)*100.0/lag(sum(total_price)) over(order by month) - 100.0, 2) as revenue_variation_percentage
    from CA
    group by month
    order by month;