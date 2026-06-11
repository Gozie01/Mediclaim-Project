const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

async function deployMeasure(name, args, label) {
  const F = await ethers.getContractFactory(name);
  const c = await F.deploy(...args);
  const r = await c.deploymentTransaction().wait();
  const gas = r.gasUsed, price = r.gasPrice || 0n;
  return { label, gasUsed: gas.toString(), costETH: ethers.formatEther(gas * price), address: await c.getAddress(), contract: c };
}

async function txMeasure(txPromise, label) {
  const r = await (await txPromise).wait();
  const gas = r.gasUsed, price = r.gasPrice || 0n;
  return { label, gasUsed: gas.toString(), costETH: ethers.formatEther(gas * price) };
}

async function main() {
  const [deployer, o1, o2, o3, patient, hospital, insurer] = await ethers.getSigners();

  console.log("\n╔══════════════════════════════════════════════════════╗");
  console.log("║       MediClaim — Gas Cost Benchmark (Gap 1)         ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");

  const dRows = [], tRows = [];

  // ── Deployments ─────────────────────────────────────────────────────────────
  console.log("Deployment gas:\n");
  const zk = await deployMeasure("ZKConsentVerifier", [], "ZKConsentVerifier.deploy()");      dRows.push(zk);
  const pp = await deployMeasure("PatientProfile", [zk.address], "PatientProfile.deploy()"); dRows.push(pp);
  const ip = await deployMeasure("InsurancePolicy", [], "InsurancePolicy.deploy()");          dRows.push(ip);
  const mo = await deployMeasure("MultiOracleConsensus", [], "MultiOracleConsensus.deploy()"); dRows.push(mo);
  const mc = await deployMeasure("MediClaim", [pp.address, ip.address, mo.address], "MediClaim.deploy()"); dRows.push(mc);

  dRows.forEach(r => console.log(`  ${r.label.padEnd(42)} ${r.gasUsed.padStart(9)} gas`));
  const totalGas = dRows.reduce((s, r) => s + BigInt(r.gasUsed), 0n);
  console.log(`\n  Total deploy gas: ${totalGas}\n`);

  // Wire
  await ip.contract.setMediClaimContract(mc.address);
  await mo.contract.registerOracleNode(o1.address);
  await mo.contract.registerOracleNode(o2.address);
  await mo.contract.registerOracleNode(o3.address);
  await ip.contract.registerInsurer(insurer.address);
  await mc.contract.registerHospital(hospital.address);

  // ── Transactions ─────────────────────────────────────────────────────────────
  console.log("Transaction gas:\n");

  tRows.push(await txMeasure(
    pp.contract.connect(patient).registerPatient(`did:purechain:${patient.address}`, `fhir-${Date.now()}`, "QmBench", ethers.keccak256(ethers.toUtf8Bytes("b"))),
    "PatientProfile.registerPatient()"
  ));
  tRows.push(await txMeasure(
    pp.contract.connect(patient).grantConsent(hospital.address),
    "PatientProfile.grantConsent()"
  ));

  const now = Math.floor(Date.now() / 1000);
  const limit = ethers.parseEther("10");
  const pTx = await ip.contract.connect(insurer).registerPolicy(
    `POL-B-${Date.now()}`, "ORG-BENCH", patient.address, limit,
    now, now + 365*24*3600, ["J18.9","Z00.0"], ["99213"]
  );
  const pR = await pTx.wait();
  let policyHash;
  for (const log of pR.logs) {
    try { const p = ip.contract.interface.parseLog(log); if (p?.name === "PolicyRegistered") policyHash = p.args.policyHash; } catch (_) {}
  }
  tRows.push({ label: "InsurancePolicy.registerPolicy()", gasUsed: pR.gasUsed.toString(), costETH: ethers.formatEther(pR.gasUsed * (pR.gasPrice||0n)) });

  tRows.push(await txMeasure(
    mc.contract.connect(insurer).fundPolicy(policyHash, { value: limit }),
    "MediClaim.fundPolicy()"
  ));

  const subTx = await mc.contract.connect(hospital).submitClaim(
    patient.address, policyHash, ethers.parseEther("2"),
    "QmBenchProof", "J18.9", "99213", `FHIR-B-${Date.now()}`
  );
  const subR = await subTx.wait();
  tRows.push({ label: "MediClaim.submitClaim() [Gates A+B+C]", gasUsed: subR.gasUsed.toString(), costETH: ethers.formatEther(subR.gasUsed * (subR.gasPrice||0n)) });

  let oReqId = ethers.ZeroHash;
  for (const log of subR.logs) {
    try { const p = mc.contract.interface.parseLog(log); if (p?.name === "ClaimUnderOracleReview") oReqId = p.args.oracleRequestId; } catch (_) {}
  }

  for (let i = 0; i < 3; i++) {
    try {
      tRows.push(await txMeasure(
        mo.contract.connect([o1,o2,o3][i]).submitVote(oReqId, true),
        `MultiOracleConsensus.submitVote() [node ${i+1}]`
      ));
    } catch(e) {
      if (e.message.includes("already resolved")) {
        tRows.push({ label: `MultiOracleConsensus.submitVote() [node ${i+1}]`, gasUsed: "N/A (consensus reached)", costETH: "0" });
      } else { throw e; }
    }
  }

  tRows.forEach(r => console.log(`  ${r.label.padEnd(42)} ${r.gasUsed.padStart(9)} gas`));

  // ── Summary table ─────────────────────────────────────────────────────────────
  console.log("\n┌─────────────────────────────────────────────┬────────────┐");
  console.log("│ Operation                                   │  Gas Used  │");
  console.log("├─────────────────────────────────────────────┼────────────┤");
  [...dRows, ...tRows].forEach(r => {
    console.log(`│ ${r.label.padEnd(44).slice(0,44)} │ ${r.gasUsed.padStart(10)} │`);
  });
  console.log("└─────────────────────────────────────────────┴────────────┘");

  console.log("\n  Literature comparison (arxiv.org/abs/2407.17765):");
  console.log("  Ethereum L1 full deploy : ~$80.22 USD  | PureChain: permissioned, near-zero");
  console.log("  Ethereum L1 per-claim   : ~$20.60 USD  | PureChain: permissioned, near-zero");
  console.log("  Optimism L2 per-claim   : ~$0.089 USD  | PureChain: consortium, no market gas\n");

  fs.writeFileSync("benchmarks/gas_report.json", JSON.stringify({
    timestamp: new Date().toISOString(), network: "PureChain", chainId: 900520900520,
    totalDeployGas: totalGas.toString(),
    deploymentCosts: dRows.map(r => ({ op: r.label, gas: r.gasUsed })),
    transactionCosts: tRows.map(r => ({ op: r.label, gas: r.gasUsed })),
    literatureComparison: { source: "arxiv.org/abs/2407.17765", ethL1DeployUSD: 80.22, optL2DeployUSD: 0.35, ethL1PerClaimUSD: 20.60, optL2PerClaimUSD: 0.089 }
  }, null, 2));
  console.log("  ✔ Saved to benchmarks/gas_report.json\n");
}

main().catch(e => { console.error(e); process.exitCode = 1; });
