select
    provider_npi,
    provider_name,
    specialty,
    provider_type,
    city,
    state,
    is_in_network

from {{ ref('stg_providers') }}
