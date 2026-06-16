-- One row per order, enriched with customer + country.
with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

countries as (

    select * from {{ ref('countries') }}

)

select
    o.order_id,
    o.order_date,
    o.status,
    o.amount,
    c.customer_id,
    c.customer_name,
    c.country_code,
    n.country_name,
    n.region
from orders o
inner join customers c on o.customer_id = c.customer_id
left join countries n on c.country_code = n.country_code
