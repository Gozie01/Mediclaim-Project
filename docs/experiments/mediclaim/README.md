# MediClaim experiment evidence

## Live PureChain pilots

The [transaction manifest](transactions.json) indexes seven successful
receipts across two pilots involving three synthetic claims on PureChain (chain ID 900520900520). The receipt JSON files
were retrieved from the network and checked against the manifest.

| Evidence | Observed result |
| --- | --- |
| [Claim 003 settlement](receipts/claim003-settlement.json) | The private claim reached Paid. The settlement receipt records a score of 45/100 and a `ClaimPaid` event for 500 base units at block 1,949,639. The pilot took 5,765 seconds from draft to payment, including manual steps. |
| [Policy registration](receipts/policy-registration.json) and [funding](receipts/policy-funding.json) | A separate synthetic policy received 1,000 base units for the duplicate-billing pilot. |
| [Draft A](receipts/draft-a.json) and [approval A](receipts/approval-a.json) | A 500-base-unit claim entered oracle review first. The shadow worker recorded `INSUFFICIENT_HISTORY` with zero prior observations. |
| [Draft B](receipts/draft-b.json) and [approval B](receipts/approval-b.json) | A distinct 500-base-unit claim with the same submitted billing line entered oracle review second. The shadow worker recorded `REVIEW` with `REPEATED_BILLING_LINE`, one prior observation, and zero claim or treatment reference matches. |

The [two shadow decisions](duplicate-billing-evidence.jsonl) were transcribed
from worker output. The worker submitted no on-chain score for A or B. The live pilots establish passing-score settlement and off-chain detection of one repeated line. Withholding payment after an accepted adverse score was tested locally. Patient-exclusive custody of the consent secret and an independent match between the deployed verifier and the inspected fixture remain unverified.

## Local Hardhat settlement checks

A clean Hardhat run passed 28 tests, including eight consent tests with the matched verifier and five payment-boundary tests. At an acceptance threshold of 70, score 69 passed and scores 70 and 71 were flagged. An archived test also passed in isolation: the authorized scorer submitted 10, a second submission of 11 reverted, and the claim paid once after quorum approval.

The four integration reports below cover separate workflow runs. Each report records two approving oracle
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

## Frozen MC24 evaluation

The v1.1.0 release contains the revised worker, frozen protocol and runner, and saved evaluation across 40 held-out seeds and three link-quality profiles. Under stressed links, the revised worker lost true-rebill recall in the primary cohort and increased false alerts in both cohorts. The evaluation JSON has SHA-256 `cb39bd6b55a31cc85b052a9d8c485c6ff9828795030934d9206dcb3966e641ca`.

[Tagged artifacts at commit `a2781d1`](https://github.com/Gozie01/Mediclaim-Project/tree/a2781d171acded660338dca4b48983f9399537a0/reproducibility/mc24) · [Zenodo v1.1.0](https://doi.org/10.5281/zenodo.24519537)

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
