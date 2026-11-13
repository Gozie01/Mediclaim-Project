# MediClaim experiment evidence

## Live PureChain pilot

The [transaction manifest](transactions.json) indexes seven successful
receipts from PureChain (chain ID 900520900520). The receipt JSON files
were retrieved from the network and checked against the manifest.

| Evidence | Observed result |
| --- | --- |
| [Claim 003 settlement](receipts/claim003-settlement.json) | The private claim reached Paid. The receipt contains a payment event for 500 base units at block 1949639. The pilot record reported a screening score of 45/100 and 5,765 seconds from draft to payment, including manual steps. |
| [Policy registration](receipts/policy-registration.json) and [funding](receipts/policy-funding.json) | A separate synthetic policy received 1,000 base units for the duplicate-billing pilot. |
| [Draft A](receipts/draft-a.json) and [approval A](receipts/approval-a.json) | A 500-base-unit claim entered oracle review first. The shadow worker recorded `INSUFFICIENT_HISTORY` with zero prior observations. |
| [Draft B](receipts/draft-b.json) and [approval B](receipts/approval-b.json) | A distinct 500-base-unit claim with the same submitted billing line entered oracle review second. The shadow worker recorded `REVIEW` with `REPEATED_BILLING_LINE`, one prior observation, and zero claim or treatment reference matches. |

The [two shadow decisions](duplicate-billing-evidence.jsonl) were transcribed
from worker output. They are off-chain records. The two-claim pilot evaluated
detection of a known repeated line in synthetic claims. It provides no
estimate of detection accuracy or evidence of payment blocking on PureChain.

## Local Hardhat settlement checks

The original operator reported 23 passing tests with the consent fixture and
the four integration runs below. Each report records two approving oracle
votes. The three timeout runs recorded zero score events and zero payment
events, with policy funds unchanged at 500 base units. The review reports
identify their scenarios and record settlement outcomes. The worker reason
codes are documented separately in the pilot records.

| Local report ID | Reported outcome |
| --- | --- |
| [31Nmh8](hardhat-reports/31Nmh8.json) | A passing fixture score and two oracle votes led to payment. |
| [vw0rcu](hardhat-reports/vw0rcu.json) | The screening worker was offline. The claim timed out without payment. |
| [qQoy64](hardhat-reports/qQoy64.json) | The worker referred a reused claim reference for review and withheld its score. The claim timed out without payment. |
| [sKTfy4](hardhat-reports/sKTfy4.json) | The worker referred a repeated billing line with distinct references for review and withheld its score. The claim timed out without payment. |

## Run the screening checks

From the repository root, use Node.js 24 and run:

```sh
npm ci
node scripts/test_screening_store.cjs
node scripts/test_billing_lines.cjs
```

The shadow worker requires the private-claims deployment and its matching
Hardhat artifact. Point `MEDICLAIM_CONTRACT_ARTIFACT` at that artifact.
The original contract in this repository predates that deployment.
The end-to-end settlement runner additionally requires the revised oracle
and patient-profile contracts and the pilot consent-proof fixture.
