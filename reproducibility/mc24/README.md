# MediClaim Chain reproducibility artifacts

MC24 compares an issuer-linked screening worker with the MC08 Candidate screening rules. Extract MC24-final-freeze.zip into a new directory. With Node 24, run `node run.cjs --verify` for development checks and `node run.cjs --evaluate` for the 40 held-out cohort seeds. PROTOCOL.md in the archive specifies the endpoints and paired intervals. Compare records and summary to evaluation-1795487451376.json from Windows Node 24.15.0. The three link profiles reuse the same underlying bills.

mc23 contains the tested worker entry point, its local imports and locked dependency files. payment contains the archived contract, reviewer control and original 28-test log. The authorized second score is rejected in the test named "settles once when a passing score arrives before a quorum".
