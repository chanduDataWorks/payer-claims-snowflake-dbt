-- One row per member. Light cleaning only: types, trimming, naming.

with source as (

    select * from {{ ref('raw_members') }}

),

renamed as (

    select
        trim(member_id)                                 as member_id,
        trim(first_name)                                as first_name,
        trim(last_name)                                 as last_name,
        cast(date_of_birth as date)                     as date_of_birth,
        upper(trim(gender))                             as gender,
        upper(trim(plan_code))                          as plan_code,
        case
            when upper(plan_code) like 'HMO%'      then 'HMO'
            when upper(plan_code) like 'PPO%'      then 'PPO'
            when upper(plan_code) like 'MEDICARE%' then 'Medicare Advantage'
            else 'Other'
        end                                             as plan_type,
        trim(county)                                    as county,
        cast(coverage_start_date as date)               as coverage_start_date,
        cast(coverage_end_date as date)                 as coverage_end_date,
        coverage_end_date is null                       as is_active,
        cast(updated_at as timestamp)                   as updated_at

    from source

)

select * from renamed
