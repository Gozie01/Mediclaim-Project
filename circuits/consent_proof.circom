pragma circom 2.0.0;

// ─────────────────────────────────────────────────────────────────────────────
// consent_proof.circom — Gap 3: ZK-proof consent verification
//
// WHAT THIS PROVES (without revealing anything):
//   "I know a patientSecret such that
//    Poseidon(patientAddressInt, patientSecret) == commitment"
//
// This lets a patient prove they own an identity (commitment was stored at
// registration time in PatientProfile.registerPatient) and grant consent
// to a hospital — without revealing their secret or any PHI on-chain.
//
// COMPILE & SETUP (requires circom ≥ 2.0.0):
//   1. Install circom:
//        cargo install circom                       # via Rust (recommended)
//        # OR download binary from:
//        # https://github.com/iden3/circom/releases
//
//   2. Install circomlib:
//        npm install circomlib
//
//   3. Compile the circuit:
//        circom circuits/consent_proof.circom \
//               --r1cs --wasm --sym \
//               -o circuits/build \
//               -l node_modules/circomlib/circuits
//
//   4. Run the full ZK setup:
//        node circuits/zk_setup.js
//
// OUTPUTS (used in Phase 3 integration):
//   circuits/build/consent_proof.r1cs
//   circuits/build/consent_proof_js/consent_proof.wasm
//   circuits/build/consent_proof_final.zkey
//   contracts/ZKConsentVerifier_real.sol   ← replaces placeholder
// ─────────────────────────────────────────────────────────────────────────────

include "poseidon.circom";

/*
 * ConsentProof — proves patient identity via Poseidon hash commitment
 *
 * Private inputs (never go on-chain):
 *   patientSecret     — random 32-byte secret stored only by the patient
 *   patientAddressInt — patient's Ethereum address as a field element
 *
 * Public input (goes on-chain as pubSignals[0]):
 *   commitment        — Poseidon(patientAddressInt, patientSecret)
 *                       stored in PatientProfile at registerPatient() time
 */
template ConsentProof() {
    // ── Private inputs ───────────────────────────────────────────────────────
    signal input patientSecret;       // Patient's private random nonce
    signal input patientAddressInt;   // uint256(patientAddress)

    // ── Public input ─────────────────────────────────────────────────────────
    signal input commitment;          // Poseidon(patientAddressInt, patientSecret)

    // ── Compute Poseidon hash of [address, secret] ───────────────────────────
    component hasher = Poseidon(2);
    hasher.inputs[0] <== patientAddressInt;
    hasher.inputs[1] <== patientSecret;

    // ── Constraint: computed hash MUST equal the on-chain commitment ──────────
    // If this constraint is violated, the proof is invalid → grantConsent fails
    commitment === hasher.out;
}

// commitment is the only public signal (index 0 in pubSignals array)
component main { public [commitment] } = ConsentProof();
