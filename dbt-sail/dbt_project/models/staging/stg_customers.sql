-- Clean the raw customers seed: typed columns, trimmed names.
with source as (

    select * from {{ ref('customers') }}

)

select
    cast(customer_id as int)        as customer_id,
    trim(customer_name)             as customer_name,
    upper(trim(country_code))       as country_code,
    cast(created_at as date)        as created_at
from source
