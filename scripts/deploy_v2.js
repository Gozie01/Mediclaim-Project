// deploy_v2.js — Deploy full MediClaim v2 system to PureChain
// Run: npx hardhat run scripts/deploy_v2.js --network purechain

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer, oracle1, oracle2, oracle3] = await ethers.getSigners();

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║     MediClaim Chain v2 — PureChain Deployment        ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");
  console.log(`Deployer : ${deployer.address}`);
  console.log(`Oracle 1 : ${oracle1.address}`);
  console.log(`Oracle 2 : ${oracle2.address}`);
  console.log(`Oracle 3 : ${oracle3.address}\n`);

  // 1. ZKConsentVerifier
  console.log("1/8  ZKConsentVerifier...");
  const ZK = await (await ethers.getContractFactory("ZKConsentVerifier")).deploy();
  await ZK.waitForDeployment();
  const zkAddr = await ZK.getAddress();
  console.log(`     ✔ ${zkAddr}`);

  // 2. HospitalRegistry
  console.log("2/8  HospitalRegistry...");
  const HR = await (await ethers.getContractFactory("HospitalRegistry")).deploy();
  await HR.waitForDeployment();
  const hrAddr = await HR.getAddress();
  console.log(`     ✔ ${hrAddr}`);

  // 3. PatientProfile
  console.log("3/8  PatientProfile...");
  const PP = await (await ethers.getContractFactory("PatientProfile")).deploy(zkAddr, hrAddr);
  await PP.waitForDeployment();
  const ppAddr = await PP.getAddress();
  console.log(`     ✔ ${ppAddr}`);

  // 4. MedicalRecord
  console.log("4/8  MedicalRecord...");
  const MR = await (await ethers.getContractFactory("MedicalRecord")).deploy(ppAddr, hrAddr);
  await MR.waitForDeployment();
  const mrAddr = await MR.getAddress();
  console.log(`     ✔ ${mrAddr}`);

  // 5. InsurancePolicy
  console.log("5/8  InsurancePolicy...");
  const IP = await (await ethers.getContractFactory("InsurancePolicy")).deploy();
  await IP.waitForDeployment();
  const ipAddr = await IP.getAddress();
  console.log(`     ✔ ${ipAddr}`);

  // 6. MultiOracleConsensus
  console.log("6/8  MultiOracleConsensus...");
  const MO = await (await ethers.getContractFactory("MultiOracleConsensus")).deploy();
  await MO.waitForDeployment();
  const moAddr = await MO.getAddress();
  console.log(`     ✔ ${moAddr}`);

  // 7. MediClaim v2
  console.log("7/8  MediClaim v2...");
  const MC = await (await ethers.getContractFactory("MediClaim")).deploy(ppAddr, ipAddr, moAddr, hrAddr);
  await MC.waitForDeployment();
  const mcAddr = await MC.getAddress();
  console.log(`     ✔ ${mcAddr}`);

  // 8. Wire roles
  console.log("8/8  Wiring roles...");
  await (await IP.setMediClaimContract(mcAddr)).wait();
  await (await MO.registerOracleNode(oracle1.address)).wait();
  await (await MO.registerOracleNode(oracle2.address)).wait();
  await (await MO.registerOracleNode(oracle3.address)).wait();
  await (await MC.registerMLOracle(deployer.address)).wait();
  console.log("     ✔ InsurancePolicy → MediClaim wired");
  console.log("     ✔ Oracle nodes registered");
  console.log("     ✔ ML oracle registered");

  const deployment = {
    network: "purechain", chainId: 900520900520,
    deployedAt: new Date().toISOString(), deployer: deployer.address,
    contracts: {
      ZKConsentVerifier:    zkAddr,
      HospitalRegistry:     hrAddr,
      PatientProfile:       ppAddr,
      MedicalRecord:        mrAddr,
      InsurancePolicy:      ipAddr,
      MultiOracleConsensus: moAddr,
      MediClaim:            mcAddr,
    },
    oracleNodes: { node1: oracle1.address, node2: oracle2.address, node3: oracle3.address },
  };

  fs.writeFileSync(path.join(__dirname, "../deployments.json"), JSON.stringify(deployment, null, 2));
  console.log("\n     ✔ deployments.json saved");

  const envLines = `\n# MediClaim v2 — ${new Date().toISOString()}\nZK_VERIFIER_ADDRESS=${zkAddr}\nHOSPITAL_REGISTRY_ADDRESS=${hrAddr}\nPATIENT_PROFILE_ADDRESS=${ppAddr}\nMEDICAL_RECORD_ADDRESS=${mrAddr}\nINSURANCE_POLICY_ADDRESS=${ipAddr}\nMULTI_ORACLE_ADDRESS=${moAddr}\nMEDI_CLAIM_ADDRESS=${mcAddr}\n`;
  const envPath = path.join(__dirname, "../.env");
  if (fs.existsSync(envPath)) fs.appendFileSync(envPath, envLines);

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║           MediClaim v2 Deployed ✓                   ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");
  Object.entries(deployment.contracts).forEach(([k,v]) => console.log(`  ${k}: ${v}`));
  console.log("\n  Next: npx hardhat run scripts/demo_v2.js --network purechain\n");
}

main().catch(e => { console.error(e); process.exitCode = 1; });
