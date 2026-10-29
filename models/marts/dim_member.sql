-- Current-state member dimension. History of plan changes lives in snap_members.

select
    member_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    plan_code,
    plan_type,
    county,
    coverage_start_date,
    coverage_end_date,
    is_active,
    case
        when {{ dbt.datediff('date_of_birth', 'current_date', 'day') }} / 365.25 < 18 then '0-17'
        when {{ dbt.datediff('date_of_birth', 'current_date', 'day') }} / 365.25 < 40 then '18-39'
        when {{ dbt.datediff('date_of_birth', 'current_date', 'day') }} / 365.25 < 65 then '40-64'
        else '65+'
    end as age_band

from {{ ref('stg_members') }}
