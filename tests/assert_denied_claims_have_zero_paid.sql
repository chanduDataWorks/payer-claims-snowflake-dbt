-- Denied claims must carry a denial reason and zero paid amount.

select
    claim_id,
    claim_status,
    denial_reason,
    paid_amount
from {{ ref('fct_claims') }}
where claim_status = 'DENIED'
  and (paid_amount <> 0 or denial_reason is null)
