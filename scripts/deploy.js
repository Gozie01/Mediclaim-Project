const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer, oracleNode1, oracleNode2, oracleNode3] = await ethers.getSigners();

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║        MediClaim Chain — PureChain Deployment        ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");

  console.log(`Deployer    : ${deployer.address}`);
  console.log(`Oracle Node1: ${oracleNode1.address}`);
  console.log(`Oracle Node2: ${oracleNode2.address}`);
  console.log(`Oracle Node3: ${oracleNode3.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`Deployer balance: ${ethers.formatEther(balance)} ETH\n`);

  // ── 1. ZKConsentVerifier ─────────────────────────────────────────────────────
  console.log("1/5  Deploying ZKConsentVerifier...");
  const ZKVerifier = await ethers.getContractFactory("ZKConsentVerifier");
  const zkVerifier = await ZKVerifier.deploy();
  await zkVerifier.waitForDeployment();
  const zkAddress = await zkVerifier.getAddress();
  console.log(`     ✔ ZKConsentVerifier    : ${zkAddress}`);

  // ── 2. PatientProfile ────────────────────────────────────────────────────────
  console.log("2/5  Deploying PatientProfile...");
  const PatientProfile = await ethers.getContractFactory("PatientProfile");
  const patientProfile = await PatientProfile.deploy(zkAddress);
  await patientProfile.waitForDeployment();
  const ppAddress = await patientProfile.getAddress();
  console.log(`     ✔ PatientProfile       : ${ppAddress}`);

  // ── 3. InsurancePolicy ───────────────────────────────────────────────────────
  console.log("3/5  Deploying InsurancePolicy...");
  const InsurancePolicy = await ethers.getContractFactory("InsurancePolicy");
  const insurancePolicy = await InsurancePolicy.deploy();
  await insurancePolicy.waitForDeployment();
  const ipAddress = await insurancePolicy.getAddress();
  console.log(`     ✔ InsurancePolicy      : ${ipAddress}`);

  // ── 4. MultiOracleConsensus ─────────────────────────────────────────────────
  console.log("4/5  Deploying MultiOracleConsensus...");
  const MultiOracle = await ethers.getContractFactory("MultiOracleConsensus");
  const multiOracle = await MultiOracle.deploy();
  await multiOracle.waitForDeployment();
  const moAddress = await multiOracle.getAddress();
  console.log(`     ✔ MultiOracleConsensus : ${moAddress}`);

  // ── 5. MediClaim ────────────────────────────────────────────────────────────
  console.log("5/5  Deploying MediClaim...");
  const MediClaim = await ethers.getContractFactory("MediClaim");
  const mediClaim = await MediClaim.deploy(ppAddress, ipAddress, moAddress);
  await mediClaim.waitForDeployment();
  const mcAddress = await mediClaim.getAddress();
  console.log(`     ✔ MediClaim            : ${mcAddress}`);

  // ── Post-deploy: wire roles ──────────────────────────────────────────────────
  console.log("\nWiring contract roles...");

  await (await insurancePolicy.setMediClaimContract(mcAddress)).wait();
  console.log("     ✔ InsurancePolicy ← MediClaim address set");

  await (await multiOracle.registerOracleNode(oracleNode1.address)).wait();
  await (await multiOracle.registerOracleNode(oracleNode2.address)).wait();
  await (await multiOracle.registerOracleNode(oracleNode3.address)).wait();
  console.log("     ✔ Oracle nodes 1-3 registered");

  // ── Save addresses ───────────────────────────────────────────────────────────
  const deployment = {
    network:    "purechain",
    chainId:    900520900520,
    deployedAt: new Date().toISOString(),
    deployer:   deployer.address,
    contracts: {
      ZKConsentVerifier:    zkAddress,
      PatientProfile:       ppAddress,
      InsurancePolicy:      ipAddress,
      MultiOracleConsensus: moAddress,
      MediClaim:            mcAddress,
    },
    oracleNodes: {
      node1: oracleNode1.address,
      node2: oracleNode2.address,
      node3: oracleNode3.address,
    },
  };

  fs.writeFileSync(
    path.join(__dirname, "../deployments.json"),
    JSON.stringify(deployment, null, 2)
  );
  console.log(`\n     ✔ Addresses saved to deployments.json`);

  const envAppend = `
# Auto-filled by deploy.js (${new Date().toISOString()})
ZK_VERIFIER_ADDRESS=${zkAddress}
PATIENT_PROFILE_ADDRESS=${ppAddress}
INSURANCE_POLICY_ADDRESS=${ipAddress}
MULTI_ORACLE_ADDRESS=${moAddress}
MEDI_CLAIM_ADDRESS=${mcAddress}
`;
  const envPath = path.join(__dirname, "../.env");
  if (fs.existsSync(envPath)) fs.appendFileSync(envPath, envAppend);
  console.log(`     ✔ Addresses appended to .env`);

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║                 Deployment Complete ✓                ║");
  console.log("╚══════════════════════════════════════════════════════╝");
  console.log("\nNext:");
  console.log("  node oracle/node1.js  &  node oracle/node2.js  &  node oracle/node3.js");
  console.log("  npx hardhat run scripts/demo_scenarios.js --network purechain\n");
}

main().catch(err => { console.error(err); process.exitCode = 1; });
