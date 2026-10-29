-- One row per plan per month: member months, cost and utilisation KPIs.
-- PMPM (per member per month) = total paid / member months - the core
-- cost metric every health plan finance team tracks.

with months as (

    select distinct service_month as month_start
    from {{ ref('fct_claims') }}

),

members as (

    select * from {{ ref('dim_member') }}

),

-- a member counts for a month if their coverage overlaps any day of it
member_months as (

    select
        m.plan_code,
        mo.month_start,
        count(distinct m.member_id) as member_months

    from months mo
    inner join members m
        on m.coverage_start_date < {{ dbt.dateadd('month', 1, 'mo.month_start') }}
       and coalesce(m.coverage_end_date, cast('9999-12-31' as date)) >= mo.month_start

    group by 1, 2

),

claims as (

    select
        plan_code,
        service_month                                           as month_start,
        count(*)                                                as claim_count,
        sum(case when is_denied then 1 else 0 end)              as denied_claim_count,
        sum(billed_amount)                                      as total_billed,
        sum(allowed_amount)                                     as total_allowed,
        sum(paid_amount)                                        as total_paid

    from {{ ref('fct_claims') }}
    group by 1, 2

)

select
    mm.plan_code,
    mm.month_start,
    mm.member_months,
    coalesce(c.claim_count, 0)                                  as claim_count,
    coalesce(c.denied_claim_count, 0)                           as denied_claim_count,
    coalesce(c.total_billed, 0)                                 as total_billed,
    coalesce(c.total_allowed, 0)                                as total_allowed,
    coalesce(c.total_paid, 0)                                   as total_paid,
    round(coalesce(c.total_paid, 0) / nullif(mm.member_months, 0), 2)              as paid_pmpm,
    round(1000.0 * coalesce(c.claim_count, 0) * 12 / nullif(mm.member_months, 0), 1) as claims_per_1000_annualized,
    round(1.0 * coalesce(c.denied_claim_count, 0) / nullif(c.claim_count, 0), 4)   as denial_rate

from member_months mm
left join claims c
    on mm.plan_code = c.plan_code
   and mm.month_start = c.month_start
