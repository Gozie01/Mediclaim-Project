# MediClaim duplicate billing screening

This package adds an optional billingLine object to the existing encrypted
private payload. Version 1 commitments and envelopes are still supported.
Update each local payload reader before introducing version 2 payloads.

## Intake

Use scripts/billing_claim_example.json as a synthetic example. Supply identifiers
from the billing source. encounterId and lineId must be stable across
resubmissions. serviceDate is YYYY-MM-DD. Actions are original, correction, and
void. Corrections and voids require originalClaimId, the original MediClaim
claim ID as a 32-byte hex string. This prototype accepts one billing line per
claim. It validates the schema and authenticates the encrypted contents.
It does not independently verify the submitting billing source.

With the existing MEDICLAIM_PRIVATE_PAYLOAD_DIR and MEDICLAIM_PRIVATE_PAYLOAD_KEY
set in the local environment, run:

    node .\scripts\prepare_billing_claim.cjs .\scripts\billing_claim_example.json

The output is the commitment for the existing draftPrivateClaim transaction.
The command writes a local encrypted payload and submits no transaction.

## Screening

The worker records a repeated original for the same hospital, patient, date,
encounter and line as REPEATED_BILLING_LINE. Correction and void requests are
referred for review, with a separate reason if the original cannot be matched.
The history contains observed screening events, not confirmed payments or
adjudicated fraud. Legacy claims supply no billing-line history. Reference
reuse and billing adjustment alerts do not prove duplicate billing. An
adjustment does not alter chain state or reverse a payment. Billing-enriched
claims remain review-only, including in local fixture mode.

Run both tests from the project root using the existing Node 24 and ethers:

    node .\scripts\test_screening_store.cjs
    node .\scripts\test_billing_lines.cjs
