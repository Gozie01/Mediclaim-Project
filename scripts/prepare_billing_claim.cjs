"use strict";

const fs = require("node:fs");
const { storePrivateClaim } = require("../oracle/private_claim_payload");

try {
  const input = process.argv[2];
  if (!input) throw Error("Usage: node scripts/prepare_billing_claim.cjs <private-claim.json>");
  const payload = JSON.parse(fs.readFileSync(input, "utf8").replace(/^\uFEFF/, ""));
  if (!payload.billingLine) throw Error("A billingLine object is required");
  const commitment = storePrivateClaim(payload, process.env.MEDICLAIM_PRIVATE_PAYLOAD_DIR,
    process.env.MEDICLAIM_PRIVATE_PAYLOAD_KEY);
  console.log(commitment);
} catch (error) {
  console.error("STOP:", error.message);
  process.exitCode = 1;
}
