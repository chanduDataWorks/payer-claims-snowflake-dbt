-- Claims joined to member and provider context, with business flags.
-- Ephemeral: compiled into the marts that use it, never built as a table.

with claims as (

    select * from {{ ref('stg_claims') }}

),

members as (

    select * from {{ ref('stg_members') }}

),

providers as (

    select * from {{ ref('stg_providers') }}

)

select
    c.claim_id,
    c.member_id,
    c.provider_npi,
    c.claim_type,
    c.procedure_code,
    c.primary_dx_code,
    c.service_date,
    c.received_date,
    c.paid_date,
    c.billed_amount,
    c.allowed_amount,
    c.paid_amount,
    c.claim_status,
    c.denial_reason,
    c.loaded_at,

    m.plan_code,
    m.plan_type,
    p.specialty,
    p.provider_type,
    p.is_in_network,

    -- business flags used by reporting
    c.claim_status = 'DENIED'                                           as is_denied,
    {{ dbt.datediff('c.service_date', 'c.received_date', 'day') }}      as days_service_to_received,
    case
        when c.paid_date is not null
        then {{ dbt.datediff('c.received_date', 'c.paid_date', 'day') }}
    end                                                                 as days_received_to_paid,
    -- member age at date of service, in whole years
    floor({{ dbt.datediff('m.date_of_birth', 'c.service_date', 'day') }} / 365.25) as member_age_at_service

from claims c
left join members m   on c.member_id = m.member_id
left join providers p on c.provider_npi = p.provider_npi
