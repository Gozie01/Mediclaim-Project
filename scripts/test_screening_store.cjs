"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { ScreeningStore, decide } = require("../oracle/claim_screening");

assert.equal(decide({ amount: 80n, history: [] }).decision, "INSUFFICIENT_HISTORY");
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "screening-test-"));
const database = path.join(directory, "history.sqlite");
const key = "ab".repeat(32);
let store;
function claim(index, overrides = {}) {
  return { id: "claim-" + index, timestamp: 10000 + index, amount: 100n,
    hospital: "synthetic-hospital", patient: "synthetic-patient", cpt: "99213",
    icd: "J18.9", claimReference: "claim-ref-" + index, treatmentReference: "treatment-" + index,
    ...overrides };
}
try {
  store = new ScreeningStore(database, key, "test-deployment", 12);
  for (let i = 0; i < 20; i++) {
    assert.equal(store.observe(claim(i)).decision, "INSUFFICIENT_HISTORY");
  }
  assert.equal(store.observe(claim(20)).decision, "NO_ALERT");
  assert.deepEqual(store.observe(claim(21, { amount: 170n })).reasons, ["HIGH_AMOUNT_WITHIN_SERVICE"]);
  assert.deepEqual(store.observe(claim(22, { claimReference: "claim-ref-4" })).reasons, ["REUSED_CLAIM_REFERENCE"]);
  assert.deepEqual(store.observe(claim(23, { treatmentReference: "treatment-5" })).reasons, ["REUSED_TREATMENT_REFERENCE"]);
  assert.equal(store.observe(claim(24, { patient: "other", treatmentReference: "treatment-5" })).decision, "NO_ALERT");
  assert.equal(store.observe(claim(25, { cpt: "99321" })).decision, "INSUFFICIENT_HISTORY");
  assert.equal(store.observe(claim(26, { timestamp: 0, amount: 9999n })).decision, "INSUFFICIENT_HISTORY");
  store.advance(18);
  store.close();
  store = new ScreeningStore(database, key, "test-deployment", 12);
  assert.equal(store.nextBlock, 18);
  assert.equal(store.observe(claim(21)).replay, true);
  assert.equal(store.observe(claim(21)).decision, "REVIEW");
  assert.equal(store.observe(claim(27)).historyCount, 24);
  assert.throws(() => new ScreeningStore(database, "cd".repeat(32), "test-deployment", 12), /another deployment/);
  console.log("PASS: decisions, temporal eligibility, cohort separation, restart, replay, and key binding");
} finally {
  store?.close();
  fs.rmSync(directory, { recursive: true, force: true });
}
