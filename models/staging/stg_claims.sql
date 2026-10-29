-- One row per claim (latest version).
-- Raw feed problems handled here:
--   1. claim_status arrives with mixed case and stray spaces  -> upper(trim())
--   2. resubmitted claims arrive again with the same claim_id -> keep the latest load
--   3. amounts arrive as text in some feeds                   -> cast to numeric(12,2)

with source as (

    select * from {{ ref('raw_claims') }}

),

cleaned as (

    select
        trim(claim_id)                                  as claim_id,
        trim(member_id)                                 as member_id,
        trim(cast(provider_npi as varchar))             as provider_npi,
        upper(trim(claim_type))                         as claim_type,
        trim(cast(procedure_code as varchar))           as procedure_code,
        upper(trim(primary_dx_code))                    as primary_dx_code,
        cast(service_date as date)                      as service_date,
        cast(received_date as date)                     as received_date,
        cast(paid_date as date)                         as paid_date,
        cast(billed_amount as numeric(12, 2))           as billed_amount,
        cast(allowed_amount as numeric(12, 2))          as allowed_amount,
        cast(paid_amount as numeric(12, 2))             as paid_amount,
        upper(trim(claim_status))                       as claim_status,
        nullif(upper(trim(denial_reason)), '')          as denial_reason,
        cast(loaded_at as timestamp)                    as loaded_at

    from source

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by claim_id
            order by loaded_at desc
        ) as version_rank

    from cleaned

)

select
    claim_id,
    member_id,
    provider_npi,
    claim_type,
    procedure_code,
    primary_dx_code,
    service_date,
    received_date,
    paid_date,
    billed_amount,
    allowed_amount,
    paid_amount,
    claim_status,
    denial_reason,
    loaded_at

from deduplicated
where version_rank = 1
  and service_date >= cast('{{ var("reporting_start_date") }}' as date)
