// ─────────────────────────────────────────────────────────────────────────────
// load_test.js — Gap 2 (Scalability) benchmark
//
// Submits N claims in parallel batches and measures:
//   • Total throughput (TPS)
//   • Per-claim latency (ms)
//   • Success rate
//   • Gas per claim
//
// Run: npx hardhat run scripts/load_test.js
// ─────────────────────────────────────────────────────────────────────────────

const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

const TOTAL_CLAIMS  = 100;  // Set to 1000 for full benchmark (takes longer)
const BATCH_SIZE    = 10;   // Concurrent claims per batch

async function deploySystem(deployer, o1, o2, o3, hospital, insurer, patient) {
  const ZKF = await ethers.getContractFactory("ZKConsentVerifier"); const zk = await ZKF.deploy(); await zk.waitForDeployment();
  const PPF = await ethers.getContractFactory("PatientProfile");    const PP = await PPF.deploy(await zk.getAddress()); await PP.waitForDeployment();
  const IPF = await ethers.getContractFactory("InsurancePolicy");   const IP = await IPF.deploy(); await IP.waitForDeployment();
  const MOF = await ethers.getContractFactory("MultiOracleConsensus"); const MO = await MOF.deploy(); await MO.waitForDeployment();
  const MCF = await ethers.getContractFactory("MediClaim");
  const MC  = await MCF.deploy(await PP.getAddress(), await IP.getAddress(), await MO.getAddress()); await MC.waitForDeployment();

  await IP.setMediClaimContract(await MC.getAddress());
  await MO.registerOracleNode(o1.address);
  await MO.registerOracleNode(o2.address);
  await MO.registerOracleNode(o3.address);
  await IP.registerInsurer(insurer.address);
  await MC.registerHospital(hospital.address);

  // Register patient + consent
  await (await PP.connect(patient).registerPatient(
    `did:purechain:${patient.address.toLowerCase()}`, `fhir-load-${Date.now()}`,
    "QmLoadTestRecord", ethers.keccak256(ethers.toUtf8Bytes("loadtest"))
  )).wait();
  await (await PP.connect(patient).grantConsent(hospital.address)).wait();

  // Register policy with large limit to handle all claims
  const limit = ethers.parseEther("500"); // 100 claims × 1 ETH each + buffer
  const now = Math.floor(Date.now()/1000);
  const pR = await (await IP.connect(insurer).registerPolicy(
    `POL-LOAD-${Date.now()}`, "ORG-LOADTEST", patient.address, limit,
    now, now + 365*24*3600, ["J18.9","Z00.0","I10","E11.9"], ["99213","99214","99215","71046"]
  )).wait();
  let policyHash;
  for (const log of pR.logs) {
    try { const p = IP.interface.parseLog(log); if (p?.name === "PolicyRegistered") policyHash = p.args.policyHash; } catch (_) {}
  }
  await (await MC.connect(insurer).fundPolicy(policyHash, { value: limit })).wait();

  return { PP, IP, MO, MC, policyHash };
}

async function submitBatch(MC, MO, hospital, patient, policyHash, nodes, batchIdx, batchSize) {
  const icdCodes = ["J18.9","Z00.0","I10","E11.9"];
  const cptCodes = ["99213","99214","99215","71046"];
  const results = [];

  const promises = Array.from({ length: batchSize }, async (_, i) => {
    const idx = batchIdx * batchSize + i;
    const t0  = Date.now();
    try {
      const amount = ethers.parseEther("1");
      const subTx  = await MC.connect(hospital).submitClaim(
        patient.address, policyHash, amount,
        `QmLoadTest${idx}`, icdCodes[idx % 4], cptCodes[idx % 4], `FHIR-LOAD-${idx}`
      );
      const subR = await subTx.wait();

      let claimId, oracleReqId;
      for (const log of subR.logs) {
        try {
          const p = MC.interface.parseLog(log);
          if (p?.name === "ClaimSubmitted")       claimId      = p.args.claimId;
          if (p?.name === "ClaimUnderOracleReview") oracleReqId = p.args.oracleRequestId;
        } catch (_) {}
      }

      // Oracle votes (2 of 3 sufficient)
      for (let n = 0; n < 2; n++) {
        try {
          await (await MO.connect(nodes[n]).submitVote(oracleReqId, true)).wait();
        } catch (_) {}
      }

      const latency = Date.now() - t0;
      const claim   = await MC.getClaim(claimId);
      return { idx, status: Number(claim.status), latencyMs: latency, gasUsed: subR.gasUsed.toString(), success: Number(claim.status) === 4 };
    } catch(e) {
      return { idx, status: -1, latencyMs: Date.now()-t0, gasUsed: "0", success: false, error: e.message.slice(0,60) };
    }
  });

  return Promise.all(promises);
}

async function main() {
  const signers = await ethers.getSigners();
  const [deployer, o1, o2, o3, patient, hospital, insurer] = signers;
  const nodes = [o1, o2, o3];

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log(`║   MediClaim — Load Test: ${TOTAL_CLAIMS} Claims (Gap 2)         ║`);
  console.log("╚══════════════════════════════════════════════════════╝\n");

  console.log("Deploying fresh system for load test...");
  const { PP, IP, MO, MC, policyHash } = await deploySystem(deployer, o1, o2, o3, hospital, insurer, patient);
  console.log("  ✔ System deployed\n");

  const allResults = [];
  const batches = Math.ceil(TOTAL_CLAIMS / BATCH_SIZE);
  const t_start = Date.now();

  for (let b = 0; b < batches; b++) {
    const size = Math.min(BATCH_SIZE, TOTAL_CLAIMS - b * BATCH_SIZE);
    process.stdout.write(`  Batch ${b+1}/${batches} (${size} claims)... `);
    const batchResults = await submitBatch(MC, MO, hospital, patient, policyHash, nodes, b, size);
    allResults.push(...batchResults);
    const batchPassed = batchResults.filter(r => r.success).length;
    process.stdout.write(`${batchPassed}/${size} paid ✔\n`);
  }

  const t_total  = (Date.now() - t_start) / 1000;
  const passed   = allResults.filter(r => r.success).length;
  const failed   = allResults.filter(r => !r.success).length;
  const latencies = allResults.filter(r => r.success).map(r => r.latencyMs);
  const avgLat   = latencies.length ? Math.round(latencies.reduce((a,b)=>a+b,0)/latencies.length) : 0;
  const minLat   = latencies.length ? Math.min(...latencies) : 0;
  const maxLat   = latencies.length ? Math.max(...latencies) : 0;
  const tps      = (passed / t_total).toFixed(2);
  const avgGas   = allResults.length
    ? Math.round(allResults.reduce((s,r) => s + Number(r.gasUsed||0), 0) / allResults.length)
    : 0;

  console.log("\n┌─────────────────────────────────────────────────────┐");
  console.log("│              LOAD TEST RESULTS (Gap 2)              │");
  console.log("├─────────────────────────────────────────────────────┤");
  console.log(`│  Total claims        : ${String(TOTAL_CLAIMS).padStart(6)}                         │`);
  console.log(`│  Successful (Paid)   : ${String(passed).padStart(6)}                         │`);
  console.log(`│  Failed              : ${String(failed).padStart(6)}                         │`);
  console.log(`│  Total time          : ${t_total.toFixed(2).padStart(6)}s                        │`);
  console.log(`│  Throughput (TPS)    : ${String(tps).padStart(6)}                         │`);
  console.log(`│  Avg latency/claim   : ${String(avgLat).padStart(6)}ms                       │`);
  console.log(`│  Min latency         : ${String(minLat).padStart(6)}ms                       │`);
  console.log(`│  Max latency         : ${String(maxLat).padStart(6)}ms                       │`);
  console.log(`│  Avg gas/submitClaim : ${String(avgGas).padStart(6)}                         │`);
  console.log("├─────────────────────────────────────────────────────┤");
  console.log("│  Literature baseline (PMC11111748):                 │");
  console.log("│    Without IPFS offload : ~12 TPS                   │");
  console.log("│    With ZK-Rollup+IPFS  : ~1500 tx / 22-25 wei gas  │");
  console.log("└─────────────────────────────────────────────────────┘");

  const report = {
    timestamp:   new Date().toISOString(),
    network:     "PureChain (simulated via Hardhat)",
    totalClaims: TOTAL_CLAIMS, batchSize: BATCH_SIZE,
    passed, failed, totalTimeSeconds: t_total,
    throughputTPS: parseFloat(tps),
    latencyMs: { avg: avgLat, min: minLat, max: maxLat },
    avgGasPerClaim: avgGas,
    literatureComparison: {
      source:                "PMC11111748 (ncbi.nlm.nih.gov)",
      withoutIPFS_TPS:       12,
      withZKRollupIPFS_TPS:  "~1500 tx per batch",
      purChain_TPS:          parseFloat(tps),
    },
    results: allResults,
  };

  fs.writeFileSync("benchmarks/load_test_results.json", JSON.stringify(report, null, 2));
  console.log("\n  ✔ Full results saved to benchmarks/load_test_results.json\n");
}

main().catch(e => { console.error(e); process.exitCode = 1; });
