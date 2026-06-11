// ─────────────────────────────────────────────────────────────────────────────
// oracle_base.js — Shared base class for all 3 oracle nodes
//
// Each node independently listens to MultiOracleConsensus.ValidationRequested
// events, validates ICD/CPT codes against the reference database, and submits
// its vote via submitVote(). A 2-of-3 majority triggers oracleCallback() in
// MediClaim which releases payment. This directly addresses Gap 5.
// ─────────────────────────────────────────────────────────────────────────────

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const { validateClaim } = require("./icd_cpt_database");
require("dotenv").config({ path: path.join(__dirname, "../.env") });

// Load ABIs from compiled artifacts
function loadABI(contractName) {
  const artifactPath = path.join(__dirname, `../artifacts/contracts/${contractName}.sol/${contractName}.json`);
  if (!fs.existsSync(artifactPath)) throw new Error(`Artifact not found: ${artifactPath}. Run: npx hardhat compile`);
  return JSON.parse(fs.readFileSync(artifactPath, "utf8")).abi;
}

// Load deployment addresses
function loadDeployment() {
  const depPath = path.join(__dirname, "../deployments.json");
  if (!fs.existsSync(depPath)) throw new Error("deployments.json not found. Run deploy.js first.");
  return JSON.parse(fs.readFileSync(depPath, "utf8"));
}

class OracleNode {
  constructor(nodeIndex, privateKeyEnvVar) {
    this.nodeIndex   = nodeIndex;
    this.privateKey  = process.env[privateKeyEnvVar];
    this.nodeLabel   = `[Oracle Node ${nodeIndex}]`;
    this.processedRequests = new Set(); // idempotency guard
  }

  async start() {
    if (!this.privateKey) {
      console.error(`${this.nodeLabel} ❌  ${  }PRIVATE_KEY not set. Add it to .env`);
      process.exit(1);
    }

    const dep = loadDeployment();
    const rpcUrl = process.env.PURECHAIN_RPC || "https://purechainnode.com";

    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.signer   = new ethers.Wallet(this.privateKey, this.provider);
    this.address  = this.signer.address;

    const moABI = loadABI("MultiOracleConsensus");
    this.oracleContract = new ethers.Contract(
      dep.contracts.MultiOracleConsensus,
      moABI,
      this.signer
    );

    const network = await this.provider.getNetwork();
    console.log(`${this.nodeLabel} ✔ Connected to chain ${network.chainId}`);
    console.log(`${this.nodeLabel} ✔ Signer address: ${this.address}`);
    console.log(`${this.nodeLabel} ✔ Oracle contract: ${dep.contracts.MultiOracleConsensus}`);

    // Listen for ValidationRequested events
    this.oracleContract.on("ValidationRequested", async (requestId, claimId, icdCode, cptCode, timestamp, event) => {
      if (this.processedRequests.has(requestId)) return; // idempotency
      this.processedRequests.add(requestId);
      await this._processRequest(requestId, claimId, icdCode, cptCode);
    });

    // Also process any past unresolved events on startup (catch-up)
    await this._catchUp();

    console.log(`${this.nodeLabel} 👂 Listening for ValidationRequested events...\n`);
  }

  async _catchUp() {
    try {
      const filter  = this.oracleContract.filters.ValidationRequested();
      const block   = await this.provider.getBlockNumber();
      const from    = Math.max(0, block - 1000); // last 1000 blocks
      const events  = await this.oracleContract.queryFilter(filter, from, "latest");

      for (const e of events) {
        const { requestId, claimId, icdCode, cptCode } = e.args;
        const { resolved } = await this.oracleContract.getRequestStatus(requestId);
        const hasVoted = await this.oracleContract.hasVoted(requestId, this.address);
        if (!resolved && !hasVoted) {
          this.processedRequests.add(requestId);
          await this._processRequest(requestId, claimId, icdCode, cptCode);
        }
      }
    } catch (e) {
      console.warn(`${this.nodeLabel} ⚠ Catch-up failed: ${e.message}`);
    }
  }

  async _processRequest(requestId, claimId, icdCode, cptCode) {
    console.log(`${this.nodeLabel} 📥 Request: ${requestId.slice(0,14)}... | ICD: ${icdCode} | CPT: ${cptCode}`);

    try {
      // Validate codes
      const result = validateClaim(icdCode, cptCode);

      // Simulate per-node processing delay (0-500ms jitter for realism)
      await new Promise(r => setTimeout(r, Math.random() * 500));

      console.log(`${this.nodeLabel} 🔍 Validation: ${result.approved ? "✓ APPROVE" : "✗ REJECT"} | ${result.reasoning}`);

      // Submit vote on-chain
      const tx = await this.oracleContract.submitVote(requestId, result.approved);
      const receipt = await tx.wait();

      console.log(`${this.nodeLabel} ✅ Vote submitted | tx: ${receipt.hash.slice(0,14)}... | gas: ${receipt.gasUsed}`);
    } catch (e) {
      if (e.message.includes("already resolved") || e.message.includes("already voted")) {
        console.log(`${this.nodeLabel} ℹ  Request ${requestId.slice(0,14)}... already handled`);
      } else {
        console.error(`${this.nodeLabel} ❌ Error processing request: ${e.message}`);
      }
    }
  }
}

module.exports = { OracleNode };
