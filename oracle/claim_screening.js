"use strict";

const { createHmac } = require("node:crypto");
const { DatabaseSync } = require("node:sqlite");

const { billingReview, normalizeBillingLine } = require("./billing_line");
const VERSION = "claim-screening-v1";
const MIN_HISTORY = 20;
const HISTORY_SECONDS = 90 * 86400;
const RECENT_SECONDS = 30 * 86400;

function median(values) {
  const sorted = [...values].sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2n;
}

function decide({ amount, history, sameClaimReference, sameTreatmentReference }) {
  const reasons = [];
  if (sameClaimReference) reasons.push("REUSED_CLAIM_REFERENCE");
  if (sameTreatmentReference) reasons.push("REUSED_TREATMENT_REFERENCE");

  if (history.length >= MIN_HISTORY) {
    const baseline = median(history);
    const deviation = median(history.map(value => value > baseline ? value - baseline : baseline - value));
    // Require both a large relative increase and a large absolute deviation.
    if (amount * 2n >= baseline * 3n && amount - baseline > 6n * deviation) {
      reasons.push("HIGH_AMOUNT_WITHIN_SERVICE");
    }
  }

  const decision = reasons.length ? "REVIEW" : history.length < MIN_HISTORY
    ? "INSUFFICIENT_HISTORY" : "NO_ALERT";
  return { decision, reasons, historyCount: history.length };
}

class ScreeningStore {
  constructor(filename, key, scope, firstBlock) {
    if (!/^[a-f0-9]{64}$/i.test(key ?? "")) throw Error("A 32-byte hex history key is required");
    this.key = Buffer.from(key, "hex");
    this.db = new DatabaseSync(filename);
    try {
      this.db.exec(`
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = FULL;
        CREATE TABLE IF NOT EXISTS meta (name TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS observations (
          id TEXT PRIMARY KEY, observed INTEGER NOT NULL, category TEXT NOT NULL,
          claim_ref TEXT NOT NULL, treatment_ref TEXT NOT NULL, amount TEXT NOT NULL,
          outcome TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS billing_lines (
          id TEXT PRIMARY KEY, line_key TEXT NOT NULL, action TEXT NOT NULL, observed INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS billing_line_lookup ON billing_lines(line_key, action, observed);
        CREATE INDEX IF NOT EXISTS category_time ON observations(category, observed);
        CREATE INDEX IF NOT EXISTS claim_ref_time ON observations(claim_ref, observed);
        CREATE INDEX IF NOT EXISTS treatment_ref_time ON observations(treatment_ref, observed);
      `);
      const identity = this.token([VERSION, scope, firstBlock]);
      this.db.prepare("INSERT OR IGNORE INTO meta VALUES ('identity', ?)").run(identity);
      if (this.db.prepare("SELECT value FROM meta WHERE name='identity'").get().value !== identity) {
        throw Error("History database belongs to another deployment, key, start block, or scoring version");
      }
      this.db.prepare("INSERT OR IGNORE INTO meta VALUES ('nextBlock', ?)").run(String(firstBlock));
    } catch (error) {
      this.db.close();
      throw error;
    }
  }

  token(parts) {
    return createHmac("sha256", this.key).update(JSON.stringify(parts)).digest("hex");
  }

  get nextBlock() {
    return Number(this.db.prepare("SELECT value FROM meta WHERE name='nextBlock'").get().value);
  }

  advance(nextBlock) {
    this.db.prepare("UPDATE meta SET value=? WHERE name='nextBlock'").run(String(nextBlock));
  }

  observe({ id, timestamp, patient, hospital, amount, cpt, icd, claimReference, treatmentReference, billingLine }) {
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const previous = this.db.prepare("SELECT outcome FROM observations WHERE id=?").get(id);
      if (previous) {
        this.db.exec("COMMIT");
        return { ...JSON.parse(previous.outcome), replay: true };
      }

      const category = this.token(["category", hospital, cpt, icd]);
      const claimRef = this.token(["claim", hospital, patient, claimReference]);
      const treatmentRef = this.token(["treatment", hospital, patient, cpt, treatmentReference]);
      const recent = timestamp - RECENT_SECONDS;
      const sameClaimReference = Boolean(this.db.prepare(
        "SELECT 1 FROM observations WHERE claim_ref=? AND observed>=? AND observed<=? LIMIT 1"
      ).get(claimRef, recent, timestamp));
      const sameTreatmentReference = Boolean(this.db.prepare(
        "SELECT 1 FROM observations WHERE treatment_ref=? AND observed>=? AND observed<=? LIMIT 1"
      ).get(treatmentRef, recent, timestamp));
      const history = this.db.prepare(`
        SELECT amount FROM observations
        WHERE category=? AND observed>=? AND observed<=?
          AND json_extract(outcome, '$.referenceMatch')=0
        ORDER BY observed DESC, rowid DESC LIMIT 200
      `).all(category, timestamp - HISTORY_SECONDS, timestamp).map(row => BigInt(row.amount));
      const billing = billingReview(this.db, billingLine === undefined ? undefined : normalizeBillingLine(billingLine),
        id, parts => this.token(parts), patient, hospital, timestamp);
      const result = {
        version: VERSION,
        ...decide({ amount, history, sameClaimReference, sameTreatmentReference }),
        referenceMatch: Number(sameClaimReference || sameTreatmentReference)
      };
      if (billingLine !== undefined) {
        result.billingEvidence = billing.evidence;
        result.reasons.push(...billing.reasons);
        if (billing.reasons.length) result.decision = "REVIEW";
      }
      this.db.prepare("INSERT INTO observations VALUES (?,?,?,?,?,?,?)").run(
        id, timestamp, category, claimRef, treatmentRef, String(amount), JSON.stringify(result)
      );
      this.db.exec("COMMIT");
      return { ...result, replay: false };
    } catch (error) {
      this.db.exec("ROLLBACK");
      throw error;
    }
  }

  close() {
    this.db.close();
  }
}

module.exports = { ScreeningStore, decide };
