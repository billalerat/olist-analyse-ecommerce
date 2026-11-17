-- 00 - Chargement des CSV dans DuckDB


CREATE TABLE customers as SELECT * FROM read_csv_auto('data/olist_customers_dataset.csv');
CREATE TABLE orders as SELECT * FROM read_csv_auto('data/olist_orders_dataset.csv');
CREATE TABLE order_items as SELECT * FROM read_csv_auto('data/olist_order_items_dataset.csv');
CREATE TABLE order_payments as SELECT * FROM read_csv_auto('data/olist_order_payments_dataset.csv');
CREATE TABLE order_reviews as SELECT * FROM read_csv_auto('data/olist_order_reviews_dataset.csv');
CREATE TABLE products as SELECT * FROM read_csv_auto('data/olist_products_dataset.csv');
CREATE TABLE sellers as SELECT * FROM read_csv_auto('data/olist_sellers_dataset.csv');

-- Contrôle : nombre de lignes de chaque table
select 'orders' as table_name, count(*) as row_count from orders
union all
select 'order_items' as table_name, count(*) as row_count from order_items
union all
select 'order_payments' as table_name, count(*) as row_count from order_payments
union all
select 'order_reviews' as table_name, count(*) as row_count from order_reviews
union all
select 'products' as table_name, count(*) as row_count from products
union all
select 'sellers' as table_name, count(*) as row_count from sellers
union all
select 'customers' as table_name, count(*) as row_count from customers;
