const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

const amount = 100n;

async function fixture() {
  const [admin, node1, node2, node3, patient, hospital, insurer, scorer, outsider] =
    await ethers.getSigners();
  async function deploy(name, ...args) {
    return (await ethers.deployContract(name, args)).waitForDeployment();
  }
  const zk = await deploy("ZKConsentVerifier");
  const registry = await deploy("HospitalRegistry");
  const profiles = await deploy("PatientProfile", zk, registry);
  const policies = await deploy("InsurancePolicy");
  const oracle = await deploy("MultiOracleConsensus");
  const claims = await deploy("MediClaim", profiles, policies, oracle, registry);
  await policies.setMediClaimContract(claims);
  await oracle.setClaimContract(claims);
  for (const node of [node1, node2, node3]) await oracle.registerOracleNode(node.address);
  await claims.registerMLOracle(scorer.address);
  await claims.registerHospital(hospital.address);
  await registry.connect(hospital).registerHospital("Synthetic hospital", "LICENSE", "ORG", "General", "Test");
  await registry.approveHospital(hospital.address);
  await profiles.connect(patient).registerPatient(
    "did:test:patient", "fhir-test", "Synthetic Patient", "2000-01-01", "O+", "test-cid", ethers.ZeroHash,
  );
  await profiles.connect(patient).grantAccess(hospital.address, 0, 0, true, 1);
  await policies.registerInsurer(insurer.address);
  const now = await time.latest();
  const policyReceipt = await (await policies.connect(insurer).registerPolicy(
    "TEST-POLICY", "TEST-ORG", patient.address, 1000n, now, now + 86400, ["J18.9"], ["99213"],
  )).wait();
  function event(contract, receipt, name) {
    return receipt.logs.map(log => {
      try { return contract.interface.parseLog(log); } catch { return null; }
    }).find(log => log?.name === name).args;
  }
  const { policyHash } = event(policies, policyReceipt, "PolicyRegistered");
  await claims.connect(insurer).fundPolicy(policyHash, { value: amount });
  const draftReceipt = await (await claims.connect(hospital).draftClaim(
    patient.address, policyHash, amount, "synthetic-cid", "J18.9", "99213", "test-claim", "Synthetic fixture",
  )).wait();
  const { claimId } = event(claims, draftReceipt, "ClaimDrafted");
  const approval = await (await claims.connect(patient).approveClaimByPatient(claimId)).wait();
  const { oracleRequestId: requestId } = event(claims, approval, "ClaimUnderOracleReview");
  return { admin, node1, node2, node3, patient, hospital, scorer, outsider,
    zk, profiles, oracle, claims, policyHash, claimId, requestId };
}

describe("MediClaim reviewer controls", function () {
  it("holds funds after one positive vote and expires into a non-paying state", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, scorer } = await loadFixture(fixture);
    await claims.connect(scorer).updateFraudScore(claimId, 10);
    await oracle.connect(node1).submitVote(requestId, true);
    await expect(oracle.resolveTimedOut(requestId)).to.be.revertedWith("MultiOracleConsensus: timeout not reached");
    const request = await oracle.requests(requestId);
    await time.setNextBlockTimestamp(request.requestedAt + await oracle.REQUEST_TIMEOUT());
    await expect(oracle.connect(node2).submitVote(requestId, true)).to.be.revertedWith("MultiOracleConsensus: request expired");
    await expect(oracle.resolveTimedOut(requestId)).to.emit(claims, "ClaimOracleTimedOut").withArgs(claimId, requestId);
    expect((await claims.getClaim(claimId)).status).to.equal(8);
    expect(await claims.policyFunds(policyHash)).to.equal(amount);
    await expect(claims.adminReleasePayment(claimId)).to.be.revertedWith("MediClaim: not approved");
  });

  it("keeps funds locked after the oracle deadline when screening never arrives", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2 } =
      await loadFixture(fixture);

    const fundsBefore = await claims.policyFunds(policyHash);
    await oracle.connect(node1).submitVote(requestId, true);
    await oracle.connect(node2).submitVote(requestId, true);
    expect((await claims.getClaim(claimId)).status).to.equal(4);

    const request = await oracle.requests(requestId);
    await time.increaseTo(request.requestedAt + await oracle.REQUEST_TIMEOUT());

    await expect(claims.adminReleasePayment(claimId))
      .to.be.revertedWith("MediClaim: screening missing");
    expect((await claims.getClaim(claimId)).status).to.equal(4);
    expect(await claims.policyFunds(policyHash)).to.equal(fundsBefore);
  });

  it("rejects a score at the screening deadline and finalizes without payment", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, scorer } =
      await loadFixture(fixture);

    const fundsBefore = await claims.policyFunds(policyHash);
    await oracle.connect(node1).submitVote(requestId, true);
    await oracle.connect(node2).submitVote(requestId, true);

    await expect(claims.resolveScreeningTimeout(claimId))
      .to.be.revertedWith("MediClaim: screening deadline not reached");

    await time.increaseTo(await claims.screeningDeadline(claimId));
    await expect(claims.connect(scorer).updateFraudScore.staticCall(claimId, 10))
      .to.be.revertedWith("MediClaim: screening deadline passed");

    await expect(claims.connect(node1).resolveScreeningTimeout(claimId))
      .to.emit(claims, "ClaimScreeningTimedOut").withArgs(claimId);
    expect((await claims.getClaim(claimId)).status).to.equal(9);
    await expect(claims.adminReleasePayment(claimId))
      .to.be.revertedWith("MediClaim: not approved");
    expect(await claims.policyFunds(policyHash)).to.equal(fundsBefore);
  });

  it("holds funds after a quorum until a passing score arrives", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, scorer } = await loadFixture(fixture);
    await oracle.connect(node1).submitVote(requestId, true);
    await oracle.connect(node2).submitVote(requestId, true);
    expect((await claims.getClaim(claimId)).status).to.equal(4);
    expect(await claims.policyFunds(policyHash)).to.equal(amount);
    await expect(claims.adminReleasePayment(claimId)).to.be.revertedWith("MediClaim: screening missing");
    await expect(claims.connect(scorer).updateFraudScore(claimId, 10)).to.emit(claims, "ClaimPaid");
    expect(await claims.policyFunds(policyHash)).to.equal(0);
    expect((await claims.getClaim(claimId)).status).to.equal(6);
  });

  it("settles once when a passing score arrives before a quorum", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, scorer } = await loadFixture(fixture);
    await claims.connect(scorer).updateFraudScore(claimId, 10);
    expect(await claims.policyFunds(policyHash)).to.equal(amount);
    await expect(claims.connect(scorer).updateFraudScore(claimId, 11))
      .to.be.revertedWith("MediClaim: score already submitted");
    await oracle.connect(node1).submitVote(requestId, true);
    await expect(oracle.connect(node2).submitVote(requestId, true)).to.emit(claims, "ClaimPaid");
    expect(await claims.policyFunds(policyHash)).to.equal(0);
    expect(await claims.totalPaid()).to.equal(amount);
  });

  it("does not pay a flagged claim even after an approval quorum", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, scorer } = await loadFixture(fixture);
    await claims.connect(scorer).updateFraudScore(claimId, 95);
    await oracle.connect(node1).submitVote(requestId, true);
    await expect(oracle.connect(node2).submitVote(requestId, true)).to.emit(claims, "FraudFlagged");
    expect(await claims.policyFunds(policyHash)).to.equal(amount);
    expect((await claims.getClaim(claimId)).status).to.equal(7);
  });

  it("rejects a claim on two negative votes despite a passing score and one positive vote", async function () {
    const { oracle, claims, claimId, requestId, policyHash, node1, node2, node3, scorer } = await loadFixture(fixture);
    await claims.connect(scorer).updateFraudScore(claimId, 10);
    await oracle.connect(node1).submitVote(requestId, true);
    await oracle.connect(node2).submitVote(requestId, false);
    expect((await claims.getClaim(claimId)).status).to.equal(3);
    await expect(oracle.connect(node3).submitVote(requestId, false)).to.emit(claims, "ClaimRejectedByOracle");
    expect((await claims.getClaim(claimId)).status).to.equal(5);
    expect(await claims.policyFunds(policyHash)).to.equal(amount);
  });

  it("rejects a duplicate, an unauthorized request, and an out-of-roster voter", async function () {
    const { oracle, claimId, requestId, node1, outsider } = await loadFixture(fixture);
    await expect(oracle.connect(outsider).requestValidation(claimId, "J18.9", "99213"))
      .to.be.revertedWith("MultiOracleConsensus: only claim contract");
    await oracle.grantRole(await oracle.ORACLE_NODE_ROLE(), outsider.address);
    await expect(oracle.connect(outsider).submitVote(requestId, true))
      .to.be.revertedWith("MultiOracleConsensus: outside roster");
    await oracle.connect(node1).submitVote(requestId, true);
    await expect(oracle.connect(node1).submitVote(requestId, false))
      .to.be.revertedWith("MultiOracleConsensus: already voted");
  });

  it("rejects dummy proofs at both the verifier and the consent entry point", async function () {
    const { zk, profiles, patient, hospital } = await loadFixture(fixture);
    const proof = [[0, 0], [[0, 0], [0, 0]], [0, 0], [0]];
    expect(await zk.verifyProof(...proof)).to.equal(false);
    await expect(profiles.connect(patient).grantAccessWithZKProof(hospital.address, 0, 1, true, 1, ...proof))
      .to.be.revertedWith("PatientProfile: invalid ZK proof");
    expect((await profiles.getConsent(patient.address, hospital.address, 0, 1)).active).to.equal(false);
  });
});
