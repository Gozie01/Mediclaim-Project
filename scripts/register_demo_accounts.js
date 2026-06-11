// register_demo_accounts.js — Register demo patient, hospital, personnel on PureChain
// Run: npx hardhat run scripts/register_demo_accounts.js --network purechain

const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

async function main() {
  const signers = await ethers.getSigners();
  const [deployer, o1, o2, o3, patientSigner, hospitalSigner, insurerSigner, doctorSigner] = signers;

  const dep = JSON.parse(fs.readFileSync("deployments.json", "utf8"));
  const PP = await ethers.getContractAt("PatientProfile",   dep.contracts.PatientProfile);
  const HR = await ethers.getContractAt("HospitalRegistry", dep.contracts.HospitalRegistry);
  const IP = await ethers.getContractAt("InsurancePolicy",  dep.contracts.InsurancePolicy);
  const MC = await ethers.getContractAt("MediClaim",        dep.contracts.MediClaim);

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║   Registering Demo Accounts on PureChain             ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");

  // ── 1. Register Patient (deployer account = 0x973B368ff...) ───────────────
  console.log("1. Registering demo PATIENT...");
  const patientAddr = deployer.address; // Use deployer as patient for demo
  const alreadyRegistered = await PP.isRegistered(patientAddr);

  if (!alreadyRegistered) {
    await (await PP.connect(deployer).registerPatient(
      `did:purechain:${patientAddr.toLowerCase()}`,
      `fhir-patient-${Date.now()}`,
      "John Demo",
      "1990-01-15",
      "O+",
      "QmPatientMasterRecordDemo",
      ethers.keccak256(ethers.toUtf8Bytes("demo-patient-record"))
    )).wait();
    console.log(`   ✔ Patient registered | Address: ${patientAddr}`);
    console.log(`   ✔ Name: John Demo | DOB: 1990-01-15 | Blood: O+`);
  } else {
    console.log(`   ℹ Patient already registered | ${patientAddr}`);
  }

  // ── 2. Register & Approve Hospital ────────────────────────────────────────
  console.log("\n2. Registering demo HOSPITAL (City General Hospital)...");
  const hospitalData = await HR.getHospital(deployer.address);

  if (!hospitalData.active) {
    await (await HR.connect(deployer).registerHospital(
      "City General Hospital",
      "LIC-DEMO-2026",
      "ORG-CITY-GENERAL",
      "Cardiology,Oncology,General Medicine,Emergency",
      "Lagos, Nigeria"
    )).wait();
    console.log(`   ✔ Hospital registered | City General Hospital`);

    await (await HR.connect(deployer).approveHospital(deployer.address)).wait();
    console.log(`   ✔ Hospital APPROVED for insurance`);

    await (await MC.connect(deployer).registerHospital(deployer.address)).wait();
    console.log(`   ✔ Hospital registered on MediClaim contract`);
  } else {
    console.log(`   ℹ Hospital already registered`);
  }

  // ── 3. Add Demo Personnel ─────────────────────────────────────────────────
  console.log("\n3. Adding demo PERSONNEL...");
  // Use oracle node addresses as demo personnel
  const staffToAdd = [
    { addr: o1.address, role: 0, name: "Dr. Sarah Chen",     staffId: "DOC-001" }, // DOCTOR
    { addr: o2.address, role: 1, name: "Nurse Joy Adams",    staffId: "NUR-002" }, // NURSE
    { addr: o3.address, role: 2, name: "Mr. Finance Obi",   staffId: "BIL-003" }, // BILLING
  ];

  for (const s of staffToAdd) {
    try {
      await (await HR.connect(deployer).addPersonnel(s.addr, s.role, s.name, s.staffId)).wait();
      const roleNames = ["Doctor","Nurse","Billing","Pharmacist","Radiologist","Admin","Lab Tech","Receptionist"];
      console.log(`   ✔ ${roleNames[s.role]}: ${s.name} | ${s.addr.slice(0,14)}...`);
    } catch(e) {
      console.log(`   ℹ ${s.name} already added`);
    }
  }

  // ── 4. Patient grants access to hospital (deployer as both) ───────────────
  console.log("\n4. Patient granting hospital access...");
  const CATS = { DEMOGRAPHICS:0, MEDICAL_HISTORY:1, LAB_RESULTS:2, PRESCRIPTIONS:3,
                 IMAGING:4, VITALS:5, NURSING_NOTES:6, BILLING_INFO:7, TREATMENT_NOTES:8 };
  const ROLES = { DOCTOR:0, NURSE:1, BILLING:2 };

  const grants = [
    { role: ROLES.DOCTOR,  cat: CATS.MEDICAL_HISTORY,  write: true },
    { role: ROLES.DOCTOR,  cat: CATS.TREATMENT_NOTES,  write: true },
    { role: ROLES.DOCTOR,  cat: CATS.PRESCRIPTIONS,    write: true },
    { role: ROLES.DOCTOR,  cat: CATS.LAB_RESULTS,      write: true },
    { role: ROLES.NURSE,   cat: CATS.VITALS,            write: true },
    { role: ROLES.NURSE,   cat: CATS.NURSING_NOTES,     write: true },
    { role: ROLES.BILLING, cat: CATS.BILLING_INFO,      write: false },
  ];

  for (const g of grants) {
    try {
      await (await PP.connect(deployer).grantAccess(
        deployer.address, g.role, g.cat, g.write, 365
      )).wait();
    } catch(e) {/* already granted */}
  }
  console.log(`   ✔ Doctor: R+W to Medical History, Treatment Notes, Prescriptions, Lab Results`);
  console.log(`   ✔ Nurse:  R+W to Vitals, Nursing Notes`);
  console.log(`   ✔ Billing: R-only to Billing Info`);

  // ── 5. Register Insurer + Policy ──────────────────────────────────────────
  console.log("\n5. Registering insurer and demo policy...");
  try {
    await (await IP.connect(deployer).registerInsurer(deployer.address)).wait();
    console.log(`   ✔ Insurer registered`);
  } catch(e) { console.log(`   ℹ Insurer already registered`); }

  const now = Math.floor(Date.now()/1000);
  try {
    const pTx = await IP.connect(deployer).registerPolicy(
      `POL-DEMO-2026`, "ORG-NATIONAL-INSURANCE", deployer.address,
      0n, now, now + 365*24*3600,
      ["J18.9","Z00.0","I10","E11.9","M54.5","F32.9"],
      ["99213","99214","99215","71046","85025","80053"]
    );
    const pR = await pTx.wait();
    let policyHash;
    for (const log of pR.logs) {
      try {
        const p = IP.interface.parseLog(log);
        if (p?.name === "PolicyRegistered") policyHash = p.args.policyHash;
      } catch(_) {}
    }
    await (await MC.connect(deployer).fundPolicy(policyHash, { value: 0n })).wait();
    console.log(`   ✔ Policy registered | Hash: ${policyHash?.slice(0,18)}...`);

    // Save policy hash for the app
    const info = {
      demoPatient:  deployer.address,
      demoHospital: deployer.address,
      demoInsurer:  deployer.address,
      demoDoctor:   o1.address,
      demoNurse:    o2.address,
      demoBilling:  o3.address,
      demoPolicyHash: policyHash,
      contracts: dep.contracts,
    };
    fs.writeFileSync("demo_accounts.json", JSON.stringify(info, null, 2));
    console.log(`\n   ✔ Demo info saved to demo_accounts.json`);
  } catch(e) { console.log(`   ℹ Policy: ${e.message.slice(0,60)}`); }

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║           Demo Accounts Ready on PureChain ✓        ║");
  console.log("╚══════════════════════════════════════════════════════╝");
  console.log(`\n  Patient/Hospital/Insurer address: ${deployer.address}`);
  console.log(`  Doctor address:  ${o1.address}`);
  console.log(`  Nurse address:   ${o2.address}`);
  console.log(`  Billing address: ${o3.address}`);
  console.log(`\n  In the app, enter: ${deployer.address}\n`);
}

main().catch(e => { console.error(e); process.exitCode = 1; });
