# MediClaim Chain

MediClaim Chain is a research prototype for claim-bound consent, confidential off-chain billing records, oracle review, conditional settlement, and duplicate-billing screening on PureChain. Live pilot outcomes, on-chain cryptographic verification, contract tests, and screening simulations represent **separate** evidence streams.

## Research evidence

- [Live PureChain pilots, local Hardhat settlement tests and frozen MC24 evaluation](docs/experiments/mediclaim/README.md)
- [Deployed Groth16 verifier equivalence (27 November 2026)](docs/experiments/mediclaim/verifier-equivalence.md) — four exact historical runtime-bytecode matches, three recovered approval transactions, and 18/18 expected functional outcomes (six distinct input vectors across three environments); see the evidence limitations and original ZIP checksum
- [Machine-readable verifier results](docs/experiments/mediclaim/verifier-equivalence-results.json)
- [Private billing-line screening](docs/experiments/mediclaim/billing.md)

## Existing archives

- [Workflow evidence and local integration reports — Zenodo v1.0.0](https://doi.org/10.5281/zenodo.24390657)
- [Frozen service-linked screening protocol and held-out results — Zenodo v1.1.0](https://doi.org/10.5281/zenodo.24519537)

The November 2026 verifier evidence has **not** been assigned a new Zenodo release number or DOI. The latest report establishes deployed equivalence with a **preserved local verifier artifact**; it does not authenticate the original test-run binary or establish patient-exclusive secret custody or production-grade trusted-setup security. See [scope and provenance](docs/experiments/mediclaim/verifier-equivalence.md) before citing these results.
