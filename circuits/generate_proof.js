// ─────────────────────────────────────────────────────────────────────────────
// generate_proof.js — Generate a ZK consent proof for a patient
//
// Called from the mobile app's PatientScreen before grantConsentWithZKProof().
// After Phase 3 setup (zk_setup.js), pass the proof fields to the contract.
//
// Usage:
//   const { generateConsentProof, computeCommitment } = require("./circuits/generate_proof");
//   const { proof, publicSignals } = await generateConsentProof(patientAddress, patientSecret);
// ─────────────────────────────────────────────────────────────────────────────

const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const fs   = require("fs");
const path = require("path");

const WASM  = path.join(__dirname, "build/consent_proof_js/consent_proof.wasm");
const ZKEY  = path.join(__dirname, "build/consent_proof_final.zkey");

/**
 * Compute the on-chain commitment (stored at patient registration).
 * commitment = Poseidon(uint256(patientAddress), patientSecret)
 */
async function computeCommitment(patientAddress, patientSecret) {
  const poseidon    = await buildPoseidon();
  const addrInt     = BigInt(patientAddress);
  const secretInt   = typeof patientSecret === "bigint" ? patientSecret : BigInt(patientSecret);
  const hash        = poseidon([addrInt, secretInt]);
  return "0x" + poseidon.F.toString(hash, 16).padStart(64, "0");
}

/**
 * Generate a Groth16 ZK proof.
 * Returns { pA, pB, pC, pubSignals } ready for PatientProfile.grantConsentWithZKProof()
 */
async function generateConsentProof(patientAddress, patientSecret) {
  if (!fs.existsSync(WASM) || !fs.existsSync(ZKEY)) {
    // Phase 1 bypass — return dummy proof (zkEnforced = false)
    console.warn("[ZK] Circuit not compiled yet (run zk_setup.js). Returning bypass proof.");
    return {
      pA:         [0n, 0n],
      pB:         [[0n, 0n], [0n, 0n]],
      pC:         [0n, 0n],
      pubSignals: [0n],
      bypassed:   true,
    };
  }

  const poseidon  = await buildPoseidon();
  const addrInt   = BigInt(patientAddress);
  const secretInt = typeof patientSecret === "bigint" ? patientSecret : BigInt(patientSecret);
  const commitment = poseidon.F.toString(poseidon([addrInt, secretInt]));

  const input = {
    patientSecret:     secretInt.toString(),
    patientAddressInt: addrInt.toString(),
    commitment,
  };

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(input, WASM, ZKEY);

  // Format for Solidity uint256[2], uint256[2][2], uint256[2], uint256[1]
  const pA = [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])];
  const pB = [
    [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])],
    [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])],
  ];
  const pC = [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])];
  const pub = [BigInt(publicSignals[0])];

  return { pA, pB, pC, pubSignals: pub, bypassed: false };
}

/**
 * Verify a proof locally (before sending to chain — saves gas on invalid proofs)
 */
async function verifyProofLocally(proof, publicSignals) {
  if (!fs.existsSync(path.join(__dirname, "build/verification_key.json"))) return true; // bypass
  const vKey = JSON.parse(fs.readFileSync(path.join(__dirname, "build/verification_key.json"), "utf8"));
  return snarkjs.groth16.verify(vKey, publicSignals, proof);
}

module.exports = { generateConsentProof, computeCommitment, verifyProofLocally };
