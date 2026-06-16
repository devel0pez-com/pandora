-- Per-country rollup: customer + order counts across all statuses,
-- with revenue summed over completed orders only.
with fct as (

    select * from {{ ref('fct_orders') }}

)

select
    country_code,
    country_name,
    region,
    count(distinct customer_id)                                      as customers,
    count(order_id)                                                  as orders,
    sum(case when status = 'completed' then amount else 0 end)       as completed_revenue
from fct
group by country_code, country_name, region
