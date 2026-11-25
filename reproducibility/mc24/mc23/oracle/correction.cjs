'use strict';
const crypto = require('node:crypto');

async function deliver(packet, { claims, store, chain, target, issuer }) {
  const { id, digest, service, signature } = packet;
  if (typeof service !== 'string' || !service.trim() || service.trim() !== service || service.length > 128) {
    throw Error('Invalid service identifier');
  }
  if (!store.db.prepare('SELECT 1 FROM observations WHERE id=?').get(id)) return 'UNKNOWN_CLAIM';
  const claim = await claims.getClaim(id);
  const original = await claims.privateClaimPayloadCommitment(id);
  if (original !== digest) return 'COMMITMENT_MISMATCH';
  const hospital = claim.hospital.toLowerCase(), patient = claim.patient.toLowerCase();
  const statement = JSON.stringify(['MediClaim/MC23/service-link-correction/v1', String(chain),
    target.toLowerCase(), hospital, patient, id, digest, service]);
  if (issuer?.asymmetricKeyType !== 'ed25519' ||
      !crypto.verify(null, Buffer.from(statement), issuer, Buffer.from(signature, 'base64'))) return 'UNAUTHORIZED';
  const db = store.db;
  db.exec('BEGIN IMMEDIATE');
  try {
    const prior = db.prepare('SELECT statement FROM correction_audit WHERE claim=?').get(id);
    let status;
    if (prior) {
      status = prior.statement === statement ? 'ALREADY_APPLIED' : 'CONFLICT';
    } else {
      const scope = store.token(['billing-scope', hospital, patient]);
      const token = store.token(['issuer-service', scope, service]);
      const added = db.prepare('INSERT INTO source_services VALUES (?,?) ON CONFLICT(service) DO NOTHING').run(token,id);
      status = added.changes ? 'APPLIED' : 'SERVICE_ALREADY_INDEXED';
      if (added.changes) db.prepare('INSERT INTO correction_audit VALUES (?,?)').run(id,statement);
    }
    db.exec('COMMIT');
    return status;
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}
module.exports = { deliver };
