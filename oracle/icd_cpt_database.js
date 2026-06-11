// ─────────────────────────────────────────────────────────────────────────────
// icd_cpt_database.js — Reference ICD-10 / CPT code validation database
//
// In production this would query a live medical coding API (e.g. CMS NCD/LCD,
// WHO ICD-10 API, or AMA CPT API). For the research prototype we embed a
// representative subset that covers all demo scenarios.
// ─────────────────────────────────────────────────────────────────────────────

// ICD-10-CM codes: diagnosis codes (World Health Organization / CMS)
const VALID_ICD10_CODES = new Set([
  // Infectious & respiratory
  "J18.9",  // Pneumonia, unspecified organism
  "J06.9",  // Acute upper respiratory infection, unspecified
  "J45.901",// Unspecified asthma, uncomplicated
  "J96.00", // Acute respiratory failure, unspecified
  // Preventive / wellness
  "Z00.0",  // Encounter for general adult medical examination
  "Z00.00", // Encounter for general adult medical examination without abnormal findings
  "Z23",    // Encounter for immunization
  // Cardiovascular
  "I10",    // Essential (primary) hypertension
  "I25.10", // Atherosclerotic heart disease of native coronary artery
  "I50.9",  // Heart failure, unspecified
  // Metabolic
  "E11.9",  // Type 2 diabetes mellitus without complications
  "E78.5",  // Hyperlipidemia, unspecified
  // Injuries
  "S52.501A",// Unspecified fracture of the lower end of right radius, initial encounter
  "M54.5",  // Low back pain
  // Mental health
  "F32.9",  // Major depressive disorder, single episode, unspecified
  "F41.1",  // Generalized anxiety disorder
]);

// CPT codes: procedure codes (American Medical Association)
const VALID_CPT_CODES = new Set([
  // Office visits (Evaluation & Management)
  "99201", "99202", "99203", "99204", "99205",  // New patient office visits
  "99211", "99212", "99213", "99214", "99215",  // Established patient office visits
  // Radiology
  "71046",  // Radiologic examination, chest; 2 views
  "71048",  // Radiologic examination, chest; 4 or more views
  "70553",  // MRI brain with contrast
  // Pathology / Lab
  "80053",  // Comprehensive metabolic panel
  "85025",  // Complete blood count with differential
  "87804",  // Influenza test
  // Surgery
  "27447",  // Total knee arthroplasty
  "43239",  // Upper GI endoscopy
  // Emergency
  "99283",  // Emergency department visit, moderate severity
  "99285",  // Emergency department visit, high severity
]);

/**
 * Validate an ICD-10 code.
 * Returns { valid: bool, code, description }
 */
function validateIcd(code) {
  const clean = (code || "").trim().toUpperCase();
  const valid = VALID_ICD10_CODES.has(clean);
  return { valid, code: clean, type: "ICD-10", description: valid ? "Code found in reference database" : "Code not found or not billable" };
}

/**
 * Validate a CPT code.
 */
function validateCpt(code) {
  const clean = (code || "").trim();
  const valid = VALID_CPT_CODES.has(clean);
  return { valid, code: clean, type: "CPT", description: valid ? "Procedure code found in reference database" : "Procedure code not found or not billable" };
}

/**
 * Full claim validation: both ICD and CPT must be valid.
 * Returns { approved: bool, icd: {...}, cpt: {...}, reasoning: string }
 */
function validateClaim(icdCode, cptCode) {
  const icd = validateIcd(icdCode);
  const cpt = validateCpt(cptCode);
  const approved = icd.valid && cpt.valid;

  const reasoning = approved
    ? `ICD-10 ${icdCode} and CPT ${cptCode} are both valid billable codes`
    : `Rejection: ${!icd.valid ? `ICD-10 "${icdCode}" not in reference database` : ""} ${!cpt.valid ? `CPT "${cptCode}" not in reference database` : ""}`.trim();

  return { approved, icd, cpt, reasoning };
}

module.exports = { validateClaim, validateIcd, validateCpt, VALID_ICD10_CODES, VALID_CPT_CODES };
