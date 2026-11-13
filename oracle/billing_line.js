"use strict";

function identifier(value) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > 128) {
    throw Error("Invalid billing identifier");
  }
  return value.trim();
}

function normalizeBillingLine(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw Error("Invalid billing line");
  const { serviceDate, action } = input;
  if (typeof serviceDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(serviceDate)) {
    throw Error("Service date must use YYYY-MM-DD");
  }
  const parsed = new Date(serviceDate + "T00:00:00Z");
  if (!Number.isFinite(+parsed) || parsed.toISOString().slice(0, 10) !== serviceDate) {
    throw Error("Invalid service date");
  }
  if (!["original", "correction", "void"].includes(action)) throw Error("Invalid billing action");
  const originalClaimId = input.originalClaimId ?? "";
  if (typeof originalClaimId !== "string" ||
      (action === "original" ? originalClaimId !== "" : !/^0x[0-9a-f]{64}$/i.test(originalClaimId))) {
    throw Error("Corrections and voids need the original MediClaim claim ID");
  }
  return {
    serviceDate, encounterId: identifier(input.encounterId),
    lineId: identifier(input.lineId), action, originalClaimId: originalClaimId.toLowerCase()
  };
}

function billingReview(db, line, id, token, patient, hospital, timestamp) {
  if (!line) return { reasons: [], evidence: "UNAVAILABLE" };
  const scope = token(["billing-scope", hospital, patient]);
  const key = token(["billing-line", scope, line.serviceDate, line.encounterId, line.lineId]);
  const reasons = [];
  if (line.action === "original") {
    if (db.prepare(`SELECT 1 FROM billing_lines
      WHERE line_key=? AND action='original' AND observed<=? LIMIT 1`).get(key, timestamp)) {
      reasons.push("REPEATED_BILLING_LINE");
    }
  } else {
    const original = db.prepare(`SELECT 1 FROM billing_lines
      WHERE id=? AND line_key=? AND action='original' AND observed<=?`)
      .get(line.originalClaimId, key, timestamp);
    // A submitted adjustment is not proof that a bill was corrected or voided.
    reasons.push(original ? "LINKED_BILLING_ADJUSTMENT" : "UNVERIFIED_BILLING_ADJUSTMENT");
  }
  db.prepare("INSERT INTO billing_lines VALUES (?,?,?,?)").run(id, key, line.action, timestamp);
  return { reasons, evidence: "SUBMITTED" };
}

module.exports = { normalizeBillingLine, billingReview };
