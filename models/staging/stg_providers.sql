-- One row per provider (NPI).

with source as (

    select * from {{ ref('raw_providers') }}

)

select
    trim(cast(provider_npi as varchar))     as provider_npi,
    trim(provider_name)                     as provider_name,
    trim(specialty)                         as specialty,
    upper(trim(provider_type))              as provider_type,
    trim(city)                              as city,
    upper(trim(state))                      as state,
    upper(trim(network_status)) = 'IN'      as is_in_network

from source
