# Deployed Groth16 verifier equivalence — 27 November 2026

**Evidence status:** historical and local checks passed, with the limitations below. This report documents the *preserved local compiled verifier artifact* and the deployed PureChain verifier; it does **not** authenticate the exact binary loaded by the original Hardhat test process.

## Evidence and provenance

- Network: PureChain, chain ID `900520900520`, genesis block hash `0xafafa8c09261b056bcf4224d1b0eb87e38ec57f0f6ab36cfc0ca6548f31a576e`.
- Original local evidence bundle: `MediClaim_Verifier_Equivalence_20261127T111555807Z.zip` (22,039 bytes), SHA-256 `67475dda6c999cd5df55602d472a46ccdde5b9b14a30cdd374a3ce6d35d09902`. **The original ZIP is not yet committed to this repository.** Do not treat this report as a substitute for the full supporting archive.
- Preserved compiler artifact: `artifacts/contracts/ClaimConsentFixtureVerifier.generated.sol/Groth16Verifier.json`, SHA-256 `4445eac761539bf932d11bbc7809656c6ccd7198dafaa3e7d4d80ffce7f81e7a`.
- Runtime: 1,768 bytes; Keccak-256 `0x211e6d35a13624499914b81b540b169b686d25d09eabf159fb180a4d78c1b94e`.
- The original fixture and artifact were preserved: no new trusted setup, contract recompilation, redeployment on PureChain, or new PureChain transaction was performed.

## Verification matrix

| ID | Check | Result |
| --- | --- | --- |
| VE-01 | Network identity | PASS |
| VE-02–03 | Historical deployment receipts / derived and recorded addresses | 8/8 each |
| VE-04 | **Exact deployed-vs-preserved runtime bytecode** at blocks 1,948,559; 1,948,716; 1,949,639; 1,975,957 | **4/4** |
| VE-05 | Historical configured verifier at configuration, settlement and snapshot blocks | **3/3** |
| VE-06–09 | Archived synthetic proof, proving key/circuit consistency, re-exported verification key and Solidity verifier fingerprints | PASS |
| VE-10–12 | Functional verifier checks, local Hardhat and two historical PureChain states | **18/18** |
| VE-11 | Original archived synthetic proof accepted in three environments | **3/3** |
| VE-12 | Five independently modified public-input vectors rejected in three environments | **15/15** |
| VE-13 | Independent saved-report, script and linked-evidence hash validation | PASS |
| VE-14 | Recovered successful on-chain consent approvals | **3/3** |
| VE-15 | Runtime hash matches at additional approval blocks 1,949,281; 1,949,459; 1,949,579 | **3/3** |
| VE-16 | Configured verifier binding before and at each approval block | **6/6** |
| VE-17–18 | Claim 003 and Claim 002 archived claim-ID reconciliation | PASS |

**Interpretation:** four checks compare entire runtime bytes. The additional three approval-block checks compare runtime hashes, **not** additional entire-byte comparisons. The 18 functional checks are **six distinct input vectors across three execution environments**, not 18 independent proofs.

## Functional protocol

The archived *synthetic circuit-pilot* proof was evaluated unchanged alongside five separately altered public-input vectors. For each mutation, exactly one public input was incremented by one modulo the BN254 scalar field; proof coordinates and other public inputs were unchanged. The test ran against (1) locally deployed preserved artifact in ephemeral Hardhat, (2) PureChain historical block 1,949,639, and (3) PureChain snapshot 1,975,957. The valid proof was accepted in each environment and each altered-input vector rejected in all environments.

Script fingerprint: `revision_verify_groth16_equivalence.cjs`, SHA-256 `11eefb37b8589161fc7d35ca195de545a3c890da83048aa70491e1ab439f49c9`. Functional report SHA-256: `0fa778dcd9ac9ade0c03151965484bc48d574e21759bcb2c2fc74c81617c72f7`. These are **source-evidence fingerprints**, not hashes of files yet present in this repository.

## Historical approvals

| Block | Transaction | Identity / reconciliation |
| --- | --- | --- |
| 1,949,281 | `0x29c0ef7deaa6a84eb0cee74c5fc7664b98ba12b552bf01ab99c18a1035384b00` | Successful consent approval; not reconciled to a named pilot claim |
| 1,949,459 | `0x35450beac45cfc7463352e54fe922b0577b80af342be980aea83befa0e032956` | Claim 002; identifier matched the archived screening plan |
| 1,949,579 | `0xfdee140bad3ccfb0435bc476b372c0266b1a718e0836891a75e9cff6e828dd2d` | Claim 003; identifier matched archived approval plan and settlement receipt |

Each recovered transaction had a successful receipt, a decoded `approveClaimWithConsentProof` call, matching event/transaction claim identifiers, a matching verifier runtime hash, and matching configured-verifier getters before and at the block boundary. Block-boundary state is not an internal transaction trace.

## Test-process anomaly and scientific limitations

After producing the complete functional report, the Windows Node.js process terminated with `Assertion failed: !(handle->flags & UV_HANDLE_CLOSING), file src/win/async.c, line 76`. The cause was not established; a separate Node.js process subsequently validated the saved 18-row matrix, three runtime fingerprints, script fingerprint and four linked-evidence fingerprints. Do **not** describe the original process as having exited cleanly.

The synthetic proof is **not** the historical Claim 003 proof. The exact original Hardhat test-run binary was not independently authenticated. Patient-exclusive secret custody and production-grade trusted setup remain unverified. Direct verifier calls do not test claim-level replay, authorization, withdrawal or expiry enforcement (those are addressed by separate contract tests). Historical reads establish block-boundary state rather than transaction execution traces. The Claim 003 settlement transaction was not independently revalidated in this verification stage. Concurrent throughput, settlement latency and operational screening quality on adjudicated claims remain outside this evidence.

## Underlying records

The independently saved bundle contains deployment receipts; exact-bytecode, historical-binding, fixture-integrity, functional, independent-validation, recovered-approval and claim-reconciliation reports; exported verifier and verification key; the functional test script; and a SHA-256 evidence register. The bundle's original manifest and byte-level reports should be deposited unchanged in a permanent release. When the ZIP is uploaded, verify its exact SHA-256 above before referencing it in the manuscript or assigning any new version/DOI.

See also [the experiment index](README.md), [structured results](verifier-equivalence-results.json), and the previously archived [workflow and settlement evidence](https://doi.org/10.5281/zenodo.24390657) and [screening protocol](https://doi.org/10.5281/zenodo.24519537).
