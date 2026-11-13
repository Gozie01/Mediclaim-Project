"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { setTimeout: sleep } = require("node:timers/promises");
const { ethers } = require("ethers");
const { loadPrivateClaim } = require("./private_claim_payload");
const { ScreeningStore } = require("./claim_screening");

async function main() {
  const mode = process.env.MEDICLAIM_SCREENING_MODE ?? "shadow";
  if (!["shadow", "local-fixture"].includes(mode)) throw Error("Unknown screening mode");
  const fixture = mode === "local-fixture";
  const url = new URL(process.env.PURECHAIN_RPC || "https://purechainnode.com");
  if (fixture && (url.protocol !== "http:" || url.hostname !== "127.0.0.1")) {
    throw Error("Settlement fixture requires loopback Hardhat RPC");
  }
  const deploymentFile = process.env.MEDICLAIM_DEPLOYMENT_FILE;
  const database = process.env.MEDICLAIM_SCREENING_DB;
  const first = process.env.MEDICLAIM_SCREENING_FROM_BLOCK;
  if (!deploymentFile || !database || !/^\d+$/.test(first ?? "") || !Number.isSafeInteger(Number(first))) {
    throw Error("Set deployment file, screening database path, and screening start block");
  }
  const provider = new ethers.JsonRpcProvider(url.href, undefined, { cacheTimeout: -1 });
  let store;
  try {
    const chain = (await provider.getNetwork()).chainId;
    if (fixture && chain !== 31337n) throw Error("Settlement fixture requires Hardhat chain ID 31337");
    const dep = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const target = ethers.getAddress(dep.contracts.MediClaim);
    const abiPath = process.env.MEDICLAIM_CONTRACT_ARTIFACT
      || path.join(__dirname, "../artifacts/contracts/MediClaim.sol/MediClaim.json");
    const { abi } = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    const claims = new ethers.Contract(target, abi, provider);
    if (await provider.getCode(target) === "0x") throw Error("MediClaim contract is missing");
    const genesis = await provider.getBlock(0);
    if (!genesis) throw Error("Chain genesis block is unavailable");
    store = new ScreeningStore(database, process.env.MEDICLAIM_SCREENING_HISTORY_KEY,
      String(chain) + "/" + genesis.hash + "/" + target, Number(first));

    let signer;
    if (fixture) {
      signer = new ethers.Wallet(process.env.PRIVATE_KEY_ML, provider);
      if (!await claims.hasRole(await claims.ML_ORACLE_ROLE(), signer.address)) {
        throw Error("Fixture wallet lacks screening role");
      }
    }

    async function processEvent(event) {
      const id = event.args.claimId;
      const at = { blockTag: event.blockNumber };
      const [claim, commitment, block] = await Promise.all([
        claims.getClaim(id, at), claims.privateClaimPayloadCommitment(id, at),
        provider.getBlock(event.blockNumber)
      ]);
      if (!block || block.hash !== event.blockHash) throw Error("Event block changed during processing");
      const payload = commitment === ethers.ZeroHash
        ? { cptCode: claim.cptCode, icdCode: claim.icdCode, fhirClaimId: claim.fhirClaimId,
          treatmentCid: claim.ipfsTreatmentHash }
        : loadPrivateClaim(commitment);
      const fields = [payload.cptCode, payload.icdCode, payload.fhirClaimId, payload.treatmentCid];
      if (fields.some(value => typeof value !== "string" || !value.trim())) {
        throw Error("Required screening inputs are missing");
      }
      const outcome = store.observe({
        id, timestamp: block.timestamp, patient: claim.patient.toLowerCase(), hospital: claim.hospital.toLowerCase(),
        amount: claim.amount, cpt: fields[0].trim().toUpperCase(), icd: fields[1].trim().toUpperCase(),
        claimReference: fields[2].trim(), treatmentReference: fields[3].trim(), billingLine: payload.billingLine
      });
      // The existing contract has no review state. Shadow decisions are persisted
      // off-chain. Only the synthetic settlement fixture writes a passing score.
      if (fixture && !payload.billingLine && outcome.decision !== "REVIEW") {
        const live = await claims.getClaim(id);
        if ([3n, 4n].includes(live.status) && !await claims.fraudScoreSubmitted(id)) {
          const latest = await provider.getBlock("latest");
          if (latest && BigInt(latest.timestamp) < await claims.screeningDeadline(id)) {
            const update = claims.connect(signer).updateFraudScore;
            await update.staticCall(id, 0);
            const receipt = await (await update(id, 0)).wait();
            if (receipt?.status !== 1) throw Error("Fixture score transaction failed");
          }
        }
      }
      console.log(JSON.stringify({ claimId: id, ...outcome }));
    }

    console.log("SCREENING_READY " + mode);
    const confirmations = fixture ? 0 : 12;
    let stopping = false;
    process.once("SIGINT", () => { stopping = true; });
    process.once("SIGTERM", () => { stopping = true; });
    while (!stopping) {
      const tip = await provider.getBlockNumber() - confirmations;
      let from = store.nextBlock;
      while (from <= tip && !stopping) {
        const to = Math.min(tip, from + 499);
        const events = await claims.queryFilter(claims.filters.ClaimUnderOracleReview(), from, to);
        events.sort((a, b) => a.blockNumber - b.blockNumber || a.index - b.index);
        for (const event of events) {
          try {
            await processEvent(event);
          } catch (error) {
            console.error("SCREENING_STOP", event.args.claimId, error.code ?? error.name);
            throw Error("Could not process screening event; checkpoint retained");
          }
        }
        store.advance(to + 1);
        from = to + 1;
      }
      if (!stopping) await sleep(fixture ? 250 : 5000);
    }
  } finally {
    store?.close();
    provider.destroy();
  }
}

main().catch(error => {
  console.error("STOP:", error.message);
  process.exitCode = 1;
});
