// ─────────────────────────────────────────────────────────────────────────────
// uploader.js — IPFS upload helper via Pinata
//
// Stores encrypted treatment records off-chain (Gap 4 / hybrid storage model).
// Returns a CID that is stored on-chain in MediClaim.ipfsTreatmentHash.
// The AES-256 encrypted file is NEVER stored on-chain — only its CID.
//
// Usage:
//   const { uploadTreatmentRecord, unpinRecord } = require("./ipfs/uploader");
//   const { cid, dataHash } = await uploadTreatmentRecord(record, patientAddress);
//   await unpinRecord(cid);  // GDPR erasure — called from revokeAndErase()
// ─────────────────────────────────────────────────────────────────────────────

const axios  = require("axios");
const crypto = require("crypto");
const path   = require("path");
require("dotenv").config({ path: path.join(__dirname, "../.env") });

const PINATA_JWT = process.env.PINATA_JWT;
const PINATA_API = "https://api.pinata.cloud";

/**
 * AES-256-CBC encrypt a JSON object.
 * Key is derived from the patient's address (in production: use their public key).
 */
function encryptRecord(data, patientAddress) {
  const key = crypto.createHash("sha256").update(patientAddress).digest(); // 32 bytes
  const iv  = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(data), "utf8"), cipher.final()]);
  return { encrypted: encrypted.toString("base64"), iv: iv.toString("hex") };
}

/**
 * Upload an encrypted treatment record to IPFS via Pinata.
 * Returns { cid, dataHash } — store cid in MediClaim.submitClaim(),
 * dataHash in PatientProfile.updateMedicalRecord().
 */
async function uploadTreatmentRecord(record, patientAddress) {
  if (!PINATA_JWT) throw new Error("PINATA_JWT not set in .env — see .env.example");

  const { encrypted, iv } = encryptRecord(record, patientAddress);
  const payload = { encrypted, iv, uploadedAt: new Date().toISOString(), patient: patientAddress };

  const response = await axios.post(
    `${PINATA_API}/pinning/pinJSONToIPFS`,
    { pinataContent: payload, pinataMetadata: { name: `mediclaim-${patientAddress.slice(0,8)}-${Date.now()}` } },
    { headers: { Authorization: `Bearer ${PINATA_JWT}`, "Content-Type": "application/json" } }
  );

  const cid      = response.data.IpfsHash;
  const dataHash = "0x" + crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");

  console.log(`[IPFS] Uploaded | CID: ${cid} | dataHash: ${dataHash.slice(0,18)}...`);
  return { cid, dataHash };
}

/**
 * Unpin (delete) a record from IPFS via Pinata.
 * Called during GDPR Art.17 erasure — removes the actual file.
 * The on-chain tombstone in PatientProfile handles the audit trail.
 */
async function unpinRecord(cid) {
  if (!PINATA_JWT) throw new Error("PINATA_JWT not set in .env");

  await axios.delete(`${PINATA_API}/pinning/unpin/${cid}`, {
    headers: { Authorization: `Bearer ${PINATA_JWT}` }
  });

  console.log(`[IPFS] Unpinned | CID: ${cid} (GDPR erasure complete)`);
  return true;
}

/**
 * Retrieve and decrypt a treatment record.
 * In production: verify dataHash matches the on-chain hash before decrypting.
 */
async function retrieveRecord(cid, patientAddress, expectedDataHash) {
  const response = await axios.get(`https://gateway.pinata.cloud/ipfs/${cid}`);
  const payload  = response.data;

  // Integrity check — if hash mismatches, the file was tampered (fraud detection)
  const actualHash = "0x" + crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
  if (expectedDataHash && actualHash !== expectedDataHash) {
    throw new Error(`[IPFS] DATA INTEGRITY VIOLATION: hash mismatch for CID ${cid}`);
  }

  const key = crypto.createHash("sha256").update(patientAddress).digest();
  const iv  = Buffer.from(payload.iv, "hex");
  const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(payload.encrypted, "base64")),
    decipher.final()
  ]);

  return JSON.parse(decrypted.toString("utf8"));
}

module.exports = { uploadTreatmentRecord, unpinRecord, retrieveRecord, encryptRecord };
