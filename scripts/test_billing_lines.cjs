"use strict";
const assert = require("node:assert/strict");
const { sealPrivateClaim, openPrivateClaim } = require("../oracle/private_claim_payload");
const { ScreeningStore } = require("../oracle/claim_screening");

const key = "ab".repeat(32);
const base = { icdCode: "J18.9", cptCode: "99213", treatmentSummary: "Synthetic",
  fhirClaimId: "test", treatmentCid: "test-cid" };
const billingLine = { serviceDate: "2026-11-12", encounterId: "enc-1", lineId: "1", action: "original" };
for (const [version, payload] of [[1, base], [2, { ...base, billingLine }]]) {
  const sealed = sealPrivateClaim(payload, key);
  assert.equal(sealed.envelope.version, version);
  const opened = openPrivateClaim(sealed.commitment, sealed.envelope, key);
  assert.deepEqual(opened, version === 1 ? base : { ...payload, billingLine: { ...billingLine, originalClaimId: "" } });
  assert.throws(() => openPrivateClaim(sealed.commitment, { ...sealed.envelope, version: 3 - version }, key));
}
assert.throws(() => sealPrivateClaim({ ...base, billingLine: { ...billingLine, serviceDate: "2026-02-30" } }, key));
const db = new ScreeningStore(":memory:", key, "billing-test", 0);
try {
  const id = i => "0x" + i.toString(16).padStart(64, "0");
  const observe = (i, line, patient = "patient") => db.observe({
    id: id(i), patient, hospital: "hospital", timestamp: 1800000000 + i, amount: 100n,
    cpt: base.cptCode, icd: base.icdCode, claimReference: "claim-" + i, treatmentReference: "tx-" + i,
    billingLine: line
  });
  assert.deepEqual(observe(1, billingLine).reasons, []);
  assert.deepEqual(observe(2, billingLine).reasons, ["REPEATED_BILLING_LINE"]);
  assert.equal(observe(2, billingLine).replay, true);
  assert.deepEqual(observe(3, { ...billingLine, encounterId: "enc-2" }).reasons, []);
  assert.deepEqual(observe(4, billingLine, "another-patient").reasons, []);
  assert.deepEqual(observe(5, { ...billingLine, action: "correction", originalClaimId: id(1) }).reasons,
    ["LINKED_BILLING_ADJUSTMENT"]);
  assert.deepEqual(observe(6, { ...billingLine, action: "void", originalClaimId: id(3) }).reasons,
    ["UNVERIFIED_BILLING_ADJUSTMENT"]);
} finally {
  db.close();
}
console.log("PASS: legacy payload, encrypted billing line, repeat visit, duplicate line, correction and void checks");
