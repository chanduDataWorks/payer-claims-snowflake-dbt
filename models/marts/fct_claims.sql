{{
    config(
        materialized='incremental',
        unique_key='claim_id',
        on_schema_change='append_new_columns'
    )
}}

-- Claim-grain fact table, loaded incrementally.
-- On each run only claims loaded since the last run (minus a 3-day lookback
-- for late corrections) are processed, then merged on claim_id.
-- Snowflake uses MERGE by default; a resubmitted claim overwrites its old row.

with claims as (

    select * from {{ ref('int_claims_enriched') }}

    {% if is_incremental() %}
    where loaded_at > (
        select {{ dbt.dateadd('day', -3, 'max(loaded_at)') }} from {{ this }}
    )
    {% endif %}

)

select
    claim_id,
    member_id,
    provider_npi,
    service_date,
    {{ dbt.date_trunc('month', 'service_date') }}       as service_month,
    received_date,
    paid_date,
    claim_type,
    procedure_code,
    primary_dx_code,
    claim_status,
    denial_reason,
    plan_code,
    plan_type,
    specialty,
    is_in_network,
    is_denied,
    billed_amount,
    allowed_amount,
    paid_amount,
    billed_amount - allowed_amount                      as contractual_discount,
    days_service_to_received,
    days_received_to_paid,
    member_age_at_service,
    loaded_at

from claims
