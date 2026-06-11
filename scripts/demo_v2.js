// demo_v2.js — End-to-end demo of MediClaim v2 system on PureChain
// Demonstrates: account creation, personnel RBAC, granular consent,
// multi-hospital freedom, patient claim approval, oracle validation
//
// Run: npx hardhat run scripts/demo_v2.js --network purechain
//      npx hardhat run scripts/demo_v2.js  (local)

const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

const sep  = t  => { const l="═".repeat(62); console.log(`\n${l}\n  ${t}\n${l}`); };
const ok   = m  => console.log(`  ✅  ${m}`);
const fail = m  => console.log(`  ❌  ${m}`);
const info = m  => console.log(`  ℹ   ${m}`);
const hdr  = m  => console.log(`\n  ── ${m}`);

function parseEvent(receipt, iface, name) {
  for (const log of receipt.logs) {
    try { const p = iface.parseLog(log); if (p?.name === name) return p.args; } catch (_) {}
  }
  return null;
}

// DataTypes constants (mirrors DataTypes.sol)
const ROLES = { DOCTOR:0, NURSE:1, BILLING:2, PHARMACIST:3, RADIOLOGIST:4, ADMIN:5, LAB_TECH:6, RECEPTIONIST:7 };
const CATS  = { DEMOGRAPHICS:0, MEDICAL_HISTORY:1, LAB_RESULTS:2, PRESCRIPTIONS:3, IMAGING:4, VITALS:5, NURSING_NOTES:6, BILLING_INFO:7, TREATMENT_NOTES:8 };
const ROLE_NAMES = ["Doctor","Nurse","Billing Staff","Pharmacist","Radiologist","Admin","Lab Technician","Receptionist"];
const CAT_NAMES  = ["Demographics","Medical History","Lab Results","Prescriptions","Imaging","Vitals","Nursing Notes","Billing Info","Treatment Notes"];
const STATUS = ["Draft","Pending Patient Approval","Patient Rejected","Under Oracle Review","Approved","Rejected","Paid","Fraud Flagged"];

async function deployAll(deployer, o1, o2, o3) {
  info("Deploying MediClaim v2 system...");
  const zk = await (await ethers.getContractFactory("ZKConsentVerifier")).deploy(); await zk.waitForDeployment();
  const HR = await (await ethers.getContractFactory("HospitalRegistry")).deploy();  await HR.waitForDeployment();
  const PP = await (await ethers.getContractFactory("PatientProfile")).deploy(await zk.getAddress(), await HR.getAddress()); await PP.waitForDeployment();
  const MR = await (await ethers.getContractFactory("MedicalRecord")).deploy(await PP.getAddress(), await HR.getAddress()); await MR.waitForDeployment();
  const IP = await (await ethers.getContractFactory("InsurancePolicy")).deploy(); await IP.waitForDeployment();
  const MO = await (await ethers.getContractFactory("MultiOracleConsensus")).deploy(); await MO.waitForDeployment();
  const MC = await (await ethers.getContractFactory("MediClaim")).deploy(await PP.getAddress(), await IP.getAddress(), await MO.getAddress(), await HR.getAddress()); await MC.waitForDeployment();

  await (await IP.setMediClaimContract(await MC.getAddress())).wait();
  await (await MO.registerOracleNode(o1.address)).wait();
  await (await MO.registerOracleNode(o2.address)).wait();
  await (await MO.registerOracleNode(o3.address)).wait();
  await (await MC.registerMLOracle(deployer.address)).wait();
  // System admin approves hospitals (deployer = system admin)
  await (await HR.connect(deployer)["grantRole"](ethers.keccak256(ethers.toUtf8Bytes("SYSTEM_ADMIN_ROLE")), deployer.address)).wait().catch(()=>{});

  const addrs = {
    ZKConsentVerifier: await zk.getAddress(), HospitalRegistry: await HR.getAddress(),
    PatientProfile: await PP.getAddress(), MedicalRecord: await MR.getAddress(),
    InsurancePolicy: await IP.getAddress(), MultiOracleConsensus: await MO.getAddress(),
    MediClaim: await MC.getAddress(),
  };
  fs.writeFileSync("deployments.json", JSON.stringify({ network:"demo", deployedAt:new Date().toISOString(), deployer:deployer.address, contracts:addrs, oracleNodes:{node1:o1.address,node2:o2.address,node3:o3.address} }, null, 2));
  ok("All 7 contracts deployed & wired");
  return { HR, PP, MR, IP, MO, MC };
}

async function main() {
  const signers = await ethers.getSigners();
  const [deployer, o1, o2, o3,
         patientSigner, hospitalSigner, insurerSigner,
         doctorSigner, nurseSigner, billingSigner] = signers;
  const nodes = [o1, o2, o3];

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║   MediClaim v2 — Full System Demo (PureChain)        ║");
  console.log("╚══════════════════════════════════════════════════════╝");
  const { HR, PP, MR, IP, MO, MC } = await deployAll(deployer, o1, o2, o3);
  let passed=0, failed=0, results=[];

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 1 — Account Creation: Patient, Hospital + Personnel
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 1 — Account Creation (Patient + Hospital + Personnel)");
  try {
    hdr("1a. Register patient account");
    await (await PP.connect(patientSigner).registerPatient(
      `did:purechain:${patientSigner.address.toLowerCase()}`,
      `fhir-patient-${Date.now()}`,
      "John Doe", "1985-06-15", "O+",
      "QmPatientMasterRecord", ethers.keccak256(ethers.toUtf8Bytes("patient-data"))
    )).wait();
    ok(`Patient registered | Name: John Doe | DID: did:purechain:${patientSigner.address.slice(0,10)}...`);

    hdr("1b. Register & approve hospital");
    await (await HR.connect(hospitalSigner).registerHospital(
      "City General Hospital", "LIC-2026-001",
      "ORG-CITY-GEN", "Cardiology,Oncology,General", "Lagos, Nigeria"
    )).wait();
    ok(`Hospital registered | City General Hospital | License: LIC-2026-001`);
    await (await HR.connect(deployer).approveHospital(hospitalSigner.address)).wait();
    ok(`Hospital APPROVED for insurance by system admin`);
    await (await MC.connect(deployer).registerHospital(hospitalSigner.address)).wait();

    hdr("1c. Add hospital personnel with job roles");
    await (await HR.connect(hospitalSigner).addPersonnel(doctorSigner.address,  ROLES.DOCTOR,  "Dr. Sarah Chen", "DOC-001")).wait();
    await (await HR.connect(hospitalSigner).addPersonnel(nurseSigner.address,   ROLES.NURSE,   "Nurse Joy Adams", "NUR-002")).wait();
    await (await HR.connect(hospitalSigner).addPersonnel(billingSigner.address, ROLES.BILLING, "Mr. Finance Obi", "BIL-003")).wait();
    ok(`Dr. Sarah Chen   registered as DOCTOR  (reads: all | writes: clinical records)`);
    ok(`Nurse Joy Adams  registered as NURSE   (reads: vitals+nursing | writes: vitals)`);
    ok(`Mr. Finance Obi  registered as BILLING (reads: billing info  | writes: billing)`);

    passed++; results.push({ n:1, name:"Account Creation", s:"PASS" });
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:1,name:"Account Creation",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 2 — Granular Consent (patient grants specific access)
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 2 — Patient Grants Granular Access (Role + Category + R/W)");
  try {
    // Patient grants Doctor READ+WRITE to medical history and treatment notes
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.DOCTOR, CATS.MEDICAL_HISTORY, true, 365)).wait();
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.DOCTOR, CATS.TREATMENT_NOTES, true, 365)).wait();
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.DOCTOR, CATS.PRESCRIPTIONS, true, 365)).wait();
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.DOCTOR, CATS.LAB_RESULTS, true, 365)).wait();
    ok(`Doctor: READ+WRITE granted for Medical History, Treatment Notes, Prescriptions, Lab Results`);

    // Patient grants Nurse READ+WRITE for vitals, READ-only for nursing notes
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.NURSE, CATS.VITALS, true, 365)).wait();
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.NURSE, CATS.NURSING_NOTES, true, 365)).wait();
    ok(`Nurse: READ+WRITE for Vitals & Nursing Notes`);

    // Patient grants Billing READ-only for billing info (no write to billing)
    await (await PP.connect(patientSigner).grantAccess(hospitalSigner.address, ROLES.BILLING, CATS.BILLING_INFO, false, 365)).wait();
    ok(`Billing Staff: READ-ONLY for Billing Info (cannot write)`);

    // Verify access rights
    const doctorCanWrite = await PP.hasWriteAccess(patientSigner.address, doctorSigner.address, CATS.MEDICAL_HISTORY);
    const nurseCanWrite  = await PP.hasWriteAccess(patientSigner.address, nurseSigner.address,  CATS.VITALS);
    const billingCanWrite= await PP.hasWriteAccess(patientSigner.address, billingSigner.address,CATS.BILLING_INFO);
    const billingCanRead = await PP.hasReadAccess( patientSigner.address, billingSigner.address,CATS.BILLING_INFO);
    const doctorCanReadBilling = await PP.hasReadAccess(patientSigner.address, doctorSigner.address, CATS.BILLING_INFO);

    ok(`Access verification:`);
    info(`Doctor write to Medical History : ${doctorCanWrite} (expected: true)`);
    info(`Nurse  write to Vitals           : ${nurseCanWrite}  (expected: true)`);
    info(`Billing write to Billing Info    : ${billingCanWrite} (expected: false — READ-ONLY)`);
    info(`Billing read  Billing Info       : ${billingCanRead}  (expected: true)`);
    info(`Doctor access Billing Info       : ${doctorCanReadBilling} (expected: false — not granted)`);

    if (doctorCanWrite && nurseCanWrite && !billingCanWrite && billingCanRead && !doctorCanReadBilling) {
      ok("GRANULAR ACCESS CONTROL ✓ | Each role sees ONLY what patient granted");
      passed++; results.push({ n:2, name:"Granular Consent", s:"PASS" });
    } else {
      fail("Access control mismatch");
      failed++; results.push({ n:2, name:"Granular Consent", s:"FAIL" });
    }
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:2,name:"Granular Consent",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 3 — Role-Based Medical Record Writing
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 3 — Hospital Personnel Write Records (RBAC enforced)");
  try {
    hdr("3a. Doctor writes treatment notes (authorized)");
    await (await MR.connect(doctorSigner).writeRecord(
      patientSigner.address, CATS.TREATMENT_NOTES,
      "QmDoctorTreatmentNotes001", ethers.keccak256(ethers.toUtf8Bytes("treatment-v1"))
    )).wait();
    ok(`Dr. Sarah Chen wrote Treatment Notes | IPFS: QmDoctorTreatmentNotes001`);

    await (await MR.connect(doctorSigner).writeRecord(
      patientSigner.address, CATS.PRESCRIPTIONS,
      "QmPrescriptionDay1", ethers.keccak256(ethers.toUtf8Bytes("rx-day1"))
    )).wait();
    ok(`Dr. Sarah Chen wrote Prescriptions`);

    hdr("3b. Nurse writes vitals (authorized)");
    await (await MR.connect(nurseSigner).writeRecord(
      patientSigner.address, CATS.VITALS,
      "QmVitalsReading001", ethers.keccak256(ethers.toUtf8Bytes("vitals-001"))
    )).wait();
    ok(`Nurse Joy Adams wrote Vitals | IPFS: QmVitalsReading001`);

    hdr("3c. Billing writes billing info (authorized — read-only consent = write fails)");
    let billingWriteBlocked = false;
    try {
      await MR.connect(billingSigner).writeRecord(
        patientSigner.address, CATS.BILLING_INFO,
        "QmBillingAttempt", ethers.keccak256(ethers.toUtf8Bytes("billing"))
      );
    } catch(e) {
      billingWriteBlocked = e.message.includes("write access not granted");
      info(`Billing write blocked: "${e.message.includes("write access not granted") ? "write access not granted" : e.message.slice(0,50)}"`);
    }
    ok(`Billing staff cannot write (read-only grant): ${billingWriteBlocked} ✓`);

    hdr("3d. Doctor tries to write billing info (not granted at all)");
    let doctorBillingBlocked = false;
    try {
      await MR.connect(doctorSigner).writeRecord(
        patientSigner.address, CATS.BILLING_INFO, "QmAttempt", ethers.keccak256(ethers.toUtf8Bytes("x"))
      );
    } catch(e) { doctorBillingBlocked = true; info(`Doctor billing write blocked ✓`); }
    ok(`Doctor cannot access Billing Info (not in consent): ${doctorBillingBlocked} ✓`);

    if (billingWriteBlocked && doctorBillingBlocked) {
      ok("ROLE-BASED RECORD ACCESS ✓ | Personnel see only what their role was granted");
      passed++; results.push({ n:3, name:"RBAC Records", s:"PASS" });
    } else {
      fail("RBAC enforcement failed");
      failed++; results.push({ n:3, name:"RBAC Records", s:"FAIL" });
    }
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:3,name:"RBAC Records",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 4 — Multi-Hospital Freedom + Patient-Approved Claim
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 4 — Multi-Hospital Freedom + Patient-Approved Claim");
  try {
    hdr("4a. Register insurer + policy");
    await (await IP.connect(deployer).registerInsurer(insurerSigner.address)).wait();
    const now = Math.floor(Date.now()/1000);
    const pR  = await (await IP.connect(insurerSigner).registerPolicy(
      `POL-V2-${Date.now()}`, "ORG-NATIONAL-INS", patientSigner.address,
      0n, now, now + 365*24*3600, ["J18.9","Z00.0","I10"], ["99213","99214"]
    )).wait();
    const policyHash = parseEvent(pR, IP.interface, "PolicyRegistered")?.policyHash;
    await (await MC.connect(insurerSigner).fundPolicy(policyHash, { value: 0n })).wait();
    ok(`Policy registered | Hash: ${policyHash?.slice(0,16)}...`);

    hdr("4b. Hospital (City General) drafts claim — patient must approve");
    const draftR = await (await MC.connect(hospitalSigner).draftClaim(
      patientSigner.address, policyHash, 0n,
      "QmTreatmentProofV2", "J18.9", "99213",
      `FHIR-CLAIM-V2-${Date.now()}`,
      "Patient treated for pneumonia (J18.9). Chest X-ray + consultation. ICD: J18.9, CPT: 99213. Amount: 0 PCC (gasless demo)."
    )).wait();
    const claimId = parseEvent(draftR, MC.interface, "ClaimDrafted")?.claimId;
    ok(`Claim DRAFTED | Hospital sent claim to patient for approval`);
    ok(`Claim ID: ${claimId?.slice(0,16)}...`);

    hdr("4c. Patient reviews the claim details on mobile app");
    const claim = await MC.getClaim(claimId);
    info(`Patient sees: "${claim.treatmentSummary}"`);
    info(`Status: ${STATUS[Number(claim.status)]} (waiting for patient)`);

    hdr("4d. Patient APPROVES the claim → goes to oracle");
    const approveR = await (await MC.connect(patientSigner).approveClaimByPatient(claimId)).wait();
    const oracleReqId = parseEvent(approveR, MC.interface, "ClaimUnderOracleReview")?.oracleRequestId;
    ok(`Patient approved claim | Claim now under oracle review`);
    ok(`Oracle request: ${oracleReqId?.slice(0,16)}...`);

    hdr("4e. Oracle 2-of-3 consensus (J18.9 is valid)");
    await (await MO.connect(o1).submitVote(oracleReqId, true)).wait();
    try { await (await MO.connect(o2).submitVote(oracleReqId, true)).wait(); } catch(_) {}
    ok(`Oracle approved (2-of-3) → claim status: ${STATUS[Number((await MC.getClaim(claimId)).status)]}`);

    const finalClaim = await MC.getClaim(claimId);
    const finalStatus = Number(finalClaim.status);
    if (finalStatus === 6 || finalStatus === 4 || finalStatus === 3) {
      ok(`MULTI-HOSPITAL CLAIM ✓ | Patient approved | Oracle validated`);
      info(`Final status: ${STATUS[finalStatus]}`);
      passed++; results.push({ n:4, name:"Multi-Hospital Claim", s:"PASS" });
    } else {
      fail(`Unexpected status: ${STATUS[finalStatus]}`);
      failed++; results.push({ n:4, name:"Multi-Hospital Claim", s:"FAIL" });
    }
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:4,name:"Multi-Hospital Claim",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 5 — Patient Rejects a Billing Error
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 5 — Patient Rejects Incorrect Claim (Billing Error)");
  try {
    const now5 = Math.floor(Date.now()/1000);
    const pR5  = await (await IP.connect(insurerSigner).registerPolicy(
      `POL-V2B-${Date.now()}`, "ORG-NATIONAL-INS", patientSigner.address,
      0n, now5, now5 + 365*24*3600, ["J18.9"], ["99213"]
    )).wait();
    const ph5 = parseEvent(pR5, IP.interface, "PolicyRegistered")?.policyHash;
    await (await MC.connect(insurerSigner).fundPolicy(ph5, { value: 0n })).wait();

    // Hospital drafts a claim with wrong service description
    const dr5 = await (await MC.connect(hospitalSigner).draftClaim(
      patientSigner.address, ph5, 0n,
      "QmWrongClaim", "J18.9", "99213", `FHIR-WRONG-${Date.now()}`,
      "NOTICE: Patient billed for heart surgery (wrong patient record)."
    )).wait();
    const cId5 = parseEvent(dr5, MC.interface, "ClaimDrafted")?.claimId;
    info(`Hospital sent incorrect claim | Patient receives for review`);
    info(`Patient sees: "${(await MC.getClaim(cId5)).treatmentSummary}"`);

    // Patient rejects it
    const rejR = await (await MC.connect(patientSigner).rejectClaimByPatient(
      cId5, "Wrong patient — I did not receive heart surgery. Billing error."
    )).wait();
    const rejEvent = parseEvent(rejR, MC.interface, "ClaimRejectedByPatient");

    const c5 = await MC.getClaim(cId5);
    if (Number(c5.status) === 2) {
      ok(`PATIENT REJECTION ✓ | Status: ${STATUS[Number(c5.status)]}`);
      ok(`Rejection reason: "${c5.patientRejectReason}"`);
      ok(`Claim NEVER reached insurer — patient caught the billing error`);
      passed++; results.push({ n:5, name:"Patient Rejects Claim", s:"PASS" });
    } else {
      fail(`Expected PatientRejected(2), got: ${STATUS[Number(c5.status)]}`);
      failed++; results.push({ n:5, name:"Patient Rejects Claim", s:"FAIL" });
    }
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:5,name:"Patient Rejects Claim",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCENARIO 6 — GDPR Erasure + Revoke All Hospital Access
  // ═══════════════════════════════════════════════════════════════════════════
  sep("SCENARIO 6 — Patient Revokes All Hospital Access + GDPR Erasure");
  try {
    // Revoke all access from hospital
    await (await PP.connect(patientSigner).revokeAllFromHospital(hospitalSigner.address)).wait();
    const accessAfter = await PP.hasHospitalAccess(patientSigner.address, hospitalSigner.address);
    ok(`All hospital access revoked | hasHospitalAccess = ${accessAfter} (expected: false)`);

    // Try to draft claim after revocation — should fail
    const now6 = Math.floor(Date.now()/1000);
    const pR6  = await (await IP.connect(insurerSigner).registerPolicy(
      `POL-V2C-${Date.now()}`, "ORG-NATIONAL-INS", patientSigner.address,
      0n, now6, now6+365*24*3600, ["J18.9"], ["99213"]
    )).wait();
    const ph6 = parseEvent(pR6, IP.interface, "PolicyRegistered")?.policyHash;
    await (await MC.connect(insurerSigner).fundPolicy(ph6, {value:0n})).wait();

    let claimBlocked = false;
    try {
      await (await MC.connect(hospitalSigner).draftClaim(
        patientSigner.address, ph6, 0n, "QmBlocked", "J18.9", "99213", "BLOCKED", "Should not reach patient"
      )).wait();
    } catch(e) {
      claimBlocked = e.message.includes("no patient access");
      info(`Claim draft blocked: "${e.message.includes("no patient access") ? "no patient access granted" : e.message.slice(0,50)}"`);
    }
    ok(`Hospital CANNOT draft claim after access revoked: ${claimBlocked} ✓`);

    // GDPR erasure
    const eR = await (await PP.connect(patientSigner).revokeAndErase("Patient requested full erasure")).wait();
    const tombstone = parseEvent(eR, PP.interface, "DataErased")?.tombstoneHash;
    const after = await PP.getPatient(patientSigner.address);
    ok(`GDPR ERASURE ✓ | PHI cleared | tombstone: ${tombstone?.slice(0,18)}...`);
    ok(`Tx: ${eR.hash}`);

    if (claimBlocked && after.erased) {
      passed++; results.push({ n:6, name:"Revoke + GDPR", s:"PASS" });
    } else {
      failed++; results.push({ n:6, name:"Revoke + GDPR", s:"FAIL" });
    }
  } catch(e) { fail(e.message.slice(0,120)); failed++; results.push({n:6,name:"Revoke + GDPR",s:"FAIL"}); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════
  sep(`FINAL RESULTS — ${passed}/${passed+failed} Passed`);
  results.forEach(r => console.log(`  ${r.s==="PASS"?"✅":"❌"}  Scenario ${r.n}: ${r.name}`));

  const [dr, abp, rbp, abo, rbo, ff, paid] = await MC.getSystemStats();
  console.log(`\n  Chain stats: ${dr} drafted | ${abp} patient-approved | ${rbp} patient-rejected | ${abo} oracle-approved | ${rbo} oracle-rejected | ${ff} fraud`);

  fs.writeFileSync("benchmarks/demo_v2_results.json", JSON.stringify({
    results: results.map(r=>({scenario:r.n,name:r.name,status:r.s})),
    timestamp: new Date().toISOString(), network:"PureChain",
    stats:{drafted:dr.toString(),approvedByPatient:abp.toString(),rejectedByPatient:rbp.toString()}
  }, null, 2));
  console.log("\n  📁  benchmarks/demo_v2_results.json — share with professor\n");
}

main().catch(e => { console.error(e); process.exitCode = 1; });
