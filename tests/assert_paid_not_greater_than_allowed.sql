-- A plan should never pay more than the allowed amount on a claim.
-- Returns offending rows; the test passes when zero rows come back.

select
    claim_id,
    allowed_amount,
    paid_amount
from {{ ref('fct_claims') }}
where paid_amount > allowed_amount
