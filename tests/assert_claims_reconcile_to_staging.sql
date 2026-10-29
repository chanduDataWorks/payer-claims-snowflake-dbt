-- Reconciliation: total paid in the fact table must equal total paid in staging.
-- This is the same row-count / amount check run after every production load.

with staging as (
    select count(*) as row_count, sum(paid_amount) as total_paid
    from {{ ref('stg_claims') }}
),

fact as (
    select count(*) as row_count, sum(paid_amount) as total_paid
    from {{ ref('fct_claims') }}
)

select
    s.row_count  as staging_rows,
    f.row_count  as fact_rows,
    s.total_paid as staging_paid,
    f.total_paid as fact_paid
from staging s
cross join fact f
where s.row_count <> f.row_count
   or s.total_paid <> f.total_paid
