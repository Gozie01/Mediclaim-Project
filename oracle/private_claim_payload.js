"use strict";

// Local pilot file transport. Each reader needs a provisioned key and filesystem
// access; this module is not a production key distribution or storage service.
const { createCipheriv, createDecipheriv, randomBytes } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { AbiCoder, id, keccak256 } = require("ethers");

const { normalizeBillingLine } = require("./billing_line");

const fields = ["icdCode", "cptCode", "treatmentSummary", "fhirClaimId", "treatmentCid"];
const coder = AbiCoder.defaultAbiCoder();
const domain = id("MediClaim/private-claim-payload/v1");
const hex32 = /^0x[0-9a-f]{64}$/i;

function normalize(payload) {
  if (!payload || fields.some(field => typeof payload[field] !== "string" || !payload[field].trim())) {
    throw new Error("Private claim payload is missing a required field");
  }
  const result = Object.fromEntries(fields.map(field => [field, payload[field]]));
  if (Object.hasOwn(payload, "billingLine")) result.billingLine = normalizeBillingLine(payload.billingLine);
  return result;
}
function commitmentFor(payload, salt) {
  if (!hex32.test(salt)) throw new Error("Invalid payload salt");
  if (payload.billingLine) {
    return keccak256(coder.encode(
      ["bytes32", "bytes32", ...Array(6).fill("string")],
      [id("MediClaim/private-claim-payload/v2"), salt,
        ...fields.map(field => payload[field]), JSON.stringify(payload.billingLine)]
    ));
  }
  return keccak256(coder.encode(
    ["bytes32", "bytes32", ...fields.map(() => "string")],
    [domain, salt, ...fields.map(field => payload[field])],
  ));
}
function keyBytes(keyHex) {
  if (typeof keyHex !== "string" || !/^[0-9a-f]{64}$/i.test(keyHex)) {
    throw new Error("MEDICLAIM_PRIVATE_PAYLOAD_KEY must be a 32-byte hex key");
  }
  return Buffer.from(keyHex, "hex");
}
function associatedData(commitment) {
  if (!hex32.test(commitment)) throw new Error("Invalid private claim commitment");
  return Buffer.from(commitment.slice(2), "hex");
}

function sealPrivateClaim(input, keyHex) {
  const payload = normalize(input);
  const salt = "0x" + randomBytes(32).toString("hex");
  const commitment = commitmentFor(payload, salt);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", keyBytes(keyHex), iv);
  cipher.setAAD(associatedData(commitment));
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify({ salt, payload }), "utf8"), cipher.final()]);
  return {
    commitment,
    envelope: { version: payload.billingLine ? 2 : 1, iv: iv.toString("hex"), tag: cipher.getAuthTag().toString("hex"),
      ciphertext: ciphertext.toString("hex") },
  };
}

function openPrivateClaim(commitment, envelope, keyHex) {
  const aad = associatedData(commitment);
  if (!envelope || ![1, 2].includes(envelope.version) || !/^[0-9a-f]{24}$/i.test(envelope.iv) ||
      !/^[0-9a-f]{32}$/i.test(envelope.tag) || !/^(?:[0-9a-f]{2})+$/i.test(envelope.ciphertext)) {
    throw new Error("Invalid private claim envelope");
  }
  const decipher = createDecipheriv("aes-256-gcm", keyBytes(keyHex), Buffer.from(envelope.iv, "hex"));
  decipher.setAAD(aad);
  decipher.setAuthTag(Buffer.from(envelope.tag, "hex"));
  const plain = Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext, "hex")), decipher.final()]);
  const { payload, salt } = JSON.parse(plain.toString("utf8"));
  const result = normalize(payload);
  if (envelope.version !== (result.billingLine ? 2 : 1)) throw Error("Payload version mismatch");
  if (commitmentFor(result, salt) !== commitment.toLowerCase()) throw new Error("Payload commitment mismatch");
  return result;
}

function payloadPath(dir, commitment) {
  associatedData(commitment);
  if (!dir) throw new Error("MEDICLAIM_PRIVATE_PAYLOAD_DIR is required");
  return path.join(dir, commitment.toLowerCase() + ".json");
}

function storePrivateClaim(input, dir, keyHex) {
  const { commitment, envelope } = sealPrivateClaim(input, keyHex);
  fs.writeFileSync(payloadPath(dir, commitment), JSON.stringify(envelope), { flag: "wx", mode: 0o600 });
  return commitment;
}

function loadPrivateClaim(commitment, dir = process.env.MEDICLAIM_PRIVATE_PAYLOAD_DIR,
  keyHex = process.env.MEDICLAIM_PRIVATE_PAYLOAD_KEY) {
  return openPrivateClaim(commitment, JSON.parse(fs.readFileSync(payloadPath(dir, commitment), "utf8")), keyHex);
}

module.exports = { sealPrivateClaim, openPrivateClaim, storePrivateClaim, loadPrivateClaim };
