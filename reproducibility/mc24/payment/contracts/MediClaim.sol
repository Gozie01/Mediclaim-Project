// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// MediClaim v2 — Patient-approved claims + multi-hospital freedom
//
// New claim lifecycle vs v1:
//   Draft → PendingPatientApproval → PatientApproved → UnderOracleReview
//   → Approved/Rejected → Paid / FraudFlagged
//
// Key innovations:
//   • Patient explicitly approves every claim before it reaches the insurer
//   • Any approved hospital can draft a claim for any patient who granted access
//   • ML fraud score written by oracle (Gap 7)
//   • Multi-oracle 2-of-3 consensus (Gap 5)
//   • Patient can reject a claim (e.g. error in billing)
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./DataTypes.sol";

interface IClaimConsentVerifier {
    function verifyProof(
        uint256[2] calldata a, uint256[2][2] calldata b,
        uint256[2] calldata c, uint256[5] calldata signals
    ) external view returns (bool);
}

interface IPatientProfileV2b {
    function hasHospitalAccess(address patient, address hospital) external view returns (bool);
    function isRegistered(address patient) external view returns (bool);
}

interface IInsurancePolicyV2 {
    function isActive(bytes32 policyHash) external view returns (bool);
    function hasSufficientCoverage(bytes32 policyHash, uint256 amount) external view returns (bool);
    function deductCoverage(bytes32 policyHash, uint256 amount) external;
    function flagPolicyFraud(bytes32 policyHash) external;
}

interface IMultiOracleV2 {
    function requestValidation(
        bytes32 claimId, string calldata icdCode,
        string calldata cptCode
    ) external returns (bytes32);
    function requestPrivateValidation(bytes32 claimId, bytes32 commitment) external returns (bytes32);
}

interface IHospitalRegistryV2b {
    function isApprovedHospital(address hospital) external view returns (bool);
}

contract MediClaim is AccessControl, ReentrancyGuard, Pausable {

    // ── Roles ─────────────────────────────────────────────────────────────────
    bytes32 public constant HOSPITAL_ROLE  = keccak256("HOSPITAL_ROLE");
    bytes32 public constant ML_ORACLE_ROLE = keccak256("ML_ORACLE_ROLE");

    bytes32 public constant CLAIM_CONSENT_DOMAIN = keccak256("MediClaim/claim-consent/pilot/v1");
    uint256 public constant CLAIM_APPROVAL_ACTION = 1;
    uint256 public constant CLAIM_BILLING_CATEGORY = DataTypes.CAT_BILLING_INFO;
    uint256 private constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IClaimConsentVerifier public claimConsentVerifier;
    mapping(address => uint256) public claimConsentCommitment;
    mapping(bytes32 => uint256) public claimConsentNonce;
    mapping(uint256 => bool) public consumedConsentNullifiers;

    event ClaimConsentVerifierConfigured(address indexed verifier);
    event ClaimConsentCommitmentRegistered(address indexed patient);
    event ClaimConsentRevoked(bytes32 indexed claimId, uint256 nextNonce);
    event ClaimConsentConsumed(bytes32 indexed claimId, address indexed requester, uint256 nullifier);

    // ── Claim state machine ───────────────────────────────────────────────────
    enum ClaimStatus {
        Draft,                  // 0  Hospital created, not yet sent to patient
        PendingPatientApproval, // 1  Awaiting patient sign-off
        PatientRejected,        // 2  Patient rejected (billing error, dispute)
        UnderOracleReview,      // 3  Patient approved, oracle validating ICD/CPT
        Approved,               // 4  Oracle approved
        Rejected,               // 5  Oracle rejected (invalid codes)
        Paid,                   // 6  Payment released to hospital
        FraudFlagged,           // 7  ML oracle flagged anomaly
        OracleTimedOut, // 8: no voting quorum
        ScreeningTimedOut // 9: quorum reached but no timely score
    }

    // ── FHIR R4 Claim resource-aligned struct ─────────────────────────────────
    struct Claim {
        bytes32     claimId;
        string      fhirClaimId;
        address     patient;
        address     hospital;
        bytes32     policyHash;
        uint256     amount;
        string      ipfsTreatmentHash;  // encrypted treatment proof CID
        string      icdCode;            // ICD-10 diagnosis
        string      cptCode;            // CPT procedure
        string      treatmentSummary;   // plain-text summary for patient review
        ClaimStatus status;
        bytes32     oracleRequestId;
        uint8       oracleConfidence;
        bool        fraudFlag;
        uint256     fraudScore;
        uint256     draftedAt;
        uint256     patientActionAt;    // when patient approved/rejected
        uint256     resolvedAt;
        string      patientRejectReason;
        string      oracleRejectReason;
    }

    // ── Storage ───────────────────────────────────────────────────────────────
    mapping(bytes32 => Claim)     public claims;
    mapping(address => bytes32[]) public hospitalClaims;
    mapping(address => bytes32[]) public patientClaims;   // includes pending approvals
    mapping(bytes32 => uint256)   public policyFunds;

    mapping(bytes32 => bool) public fraudScoreSubmitted;
    mapping(bytes32 => bytes32) public privateClaimPayloadCommitment;
    mapping(bytes32 => bool) public usedPrivatePayloadCommitments;
    event PrivateClaimRejected(bytes32 indexed claimId, address indexed patient, uint256 timestamp);

    IPatientProfileV2b  public patientProfile;
    IInsurancePolicyV2  public insurancePolicy;
    IMultiOracleV2      public oracleConsensus;
    IHospitalRegistryV2b public hospitalRegistry;

    uint256 public fraudScoreThreshold = 70;

    // System stats
    uint256 public totalDrafted;
    uint256 public totalApprovedByPatient;
    uint256 public totalRejectedByPatient;
    uint256 public totalApprovedByOracle;
    uint256 public totalRejectedByOracle;
    uint256 public totalFraudFlagged;
    uint256 public totalPaid;

    // ── Events ────────────────────────────────────────────────────────────────
    event ClaimDrafted(bytes32 indexed claimId, address indexed patient, address indexed hospital, uint256 amount, uint256 timestamp);
    event ClaimSentToPatient(bytes32 indexed claimId, uint256 timestamp);
    event ClaimApprovedByPatient(bytes32 indexed claimId, address indexed patient, uint256 timestamp);
    event ClaimRejectedByPatient(bytes32 indexed claimId, address indexed patient, string reason, uint256 timestamp);
    event ClaimUnderOracleReview(bytes32 indexed claimId, bytes32 oracleRequestId);
    event ClaimOracleTimedOut(bytes32 indexed claimId, bytes32 indexed requestId);
    event ClaimApprovedByOracle(bytes32 indexed claimId, uint256 amount, uint8 confidence);
    event ClaimRejectedByOracle(bytes32 indexed claimId, string reason, uint256 timestamp);
    event ClaimPaid(bytes32 indexed claimId, address indexed hospital, uint256 amount, uint256 latencySeconds);
    event FraudFlagged(bytes32 indexed claimId, address indexed hospital, uint256 fraudScore, uint256 timestamp);
    event MLScoreUpdated(bytes32 indexed claimId, uint256 score, bool flagged);
    event PolicyFunded(bytes32 indexed policyHash, address indexed funder, uint256 amount);

    constructor(
        address _patientProfile,
        address _insurancePolicy,
        address _oracleConsensus,
        address _hospitalRegistry
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE,  msg.sender);
        patientProfile   = IPatientProfileV2b(_patientProfile);
        insurancePolicy  = IInsurancePolicyV2(_insurancePolicy);
        oracleConsensus  = IMultiOracleV2(_oracleConsensus);
        hospitalRegistry = IHospitalRegistryV2b(_hospitalRegistry);
    }

    function registerHospital(address _h) external onlyRole(DEFAULT_ADMIN_ROLE) { _grantRole(HOSPITAL_ROLE, _h); }
    function registerMLOracle(address _o) external onlyRole(DEFAULT_ADMIN_ROLE) { _grantRole(ML_ORACLE_ROLE, _o); }
    function setFraudThreshold(uint256 _t) external onlyRole(DEFAULT_ADMIN_ROLE) { fraudScoreThreshold = _t; }

    // ── Insurer funds a policy ────────────────────────────────────────────────
    function fundPolicy(bytes32 _policyHash) external payable {
        policyFunds[_policyHash] += msg.value;
        emit PolicyFunded(_policyHash, msg.sender, msg.value);
    }

    // ── Step 1: Hospital drafts a claim ───────────────────────────────────────
    // The hospital creates a draft; NOT submitted to insurer yet.
    // Patient must review and approve first.
    function draftClaim(
        address         _patient,
        bytes32         _policyHash,
        uint256         _amount,
        string calldata _ipfsTreatmentHash,
        string calldata _icdCode,
        string calldata _cptCode,
        string calldata _fhirClaimId,
        string calldata _treatmentSummary   // plain-text for patient to read
    ) external onlyRole(HOSPITAL_ROLE) nonReentrant whenNotPaused returns (bytes32) {
        require(address(claimConsentVerifier) == address(0), "MediClaim: private draft required");
        return _draftClaim(_patient, _policyHash, _amount, _ipfsTreatmentHash, _icdCode,
            _cptCode, _fhirClaimId, _treatmentSummary);
    }

    function draftPrivateClaim(address patient, bytes32 policyHash, uint256 amount, bytes32 commitment)
        external onlyRole(HOSPITAL_ROLE) nonReentrant whenNotPaused returns (bytes32)
    {
        require(address(claimConsentVerifier) != address(0), "MediClaim: consent verifier not set");
        require(commitment != bytes32(0) && !usedPrivatePayloadCommitments[commitment],
            "MediClaim: invalid or reused payload commitment");
        bytes32 claimId = _draftClaim(patient, policyHash, amount, "", "", "", "", "");
        privateClaimPayloadCommitment[claimId] = commitment;
        usedPrivatePayloadCommitments[commitment] = true;
        return claimId;
    }

    function _draftClaim(
        address _patient, bytes32 _policyHash, uint256 _amount, string memory _ipfsTreatmentHash,
        string memory _icdCode, string memory _cptCode, string memory _fhirClaimId, string memory _treatmentSummary
    ) internal returns (bytes32) {

        // Gate: hospital must be approved
        require(hospitalRegistry.isApprovedHospital(msg.sender), "MediClaim: hospital not approved");
        // Gate: patient registered
        require(patientProfile.isRegistered(_patient), "MediClaim: patient not registered");
        // Gate: patient granted this hospital access (any access = can treat)
        require(patientProfile.hasHospitalAccess(_patient, msg.sender), "MediClaim: no patient access granted");
        // Gate: policy must be valid
        require(insurancePolicy.isActive(_policyHash), "MediClaim: policy not active");

        bytes32 claimId = keccak256(abi.encode(address(this), _patient, msg.sender, _policyHash, totalDrafted));

        claims[claimId] = Claim({
            claimId:            claimId,
            fhirClaimId:        _fhirClaimId,
            patient:            _patient,
            hospital:           msg.sender,
            policyHash:         _policyHash,
            amount:             _amount,
            ipfsTreatmentHash:  _ipfsTreatmentHash,
            icdCode:            _icdCode,
            cptCode:            _cptCode,
            treatmentSummary:   _treatmentSummary,
            status:             ClaimStatus.PendingPatientApproval,
            oracleRequestId:    bytes32(0),
            oracleConfidence:   0,
            fraudFlag:          false,
            fraudScore:         0,
            draftedAt:          block.timestamp,
            patientActionAt:    0,
            resolvedAt:         0,
            patientRejectReason: "",
            oracleRejectReason:  ""
        });

        hospitalClaims[msg.sender].push(claimId);
        patientClaims[_patient].push(claimId);
        totalDrafted++;

        emit ClaimDrafted(claimId, _patient, msg.sender, _amount, block.timestamp);
        emit ClaimSentToPatient(claimId, block.timestamp);
        return claimId;
    }

    // Opt-in for the proof-enforced deployment. Configuration cannot be undone
    // or replaced; prior claims are not retroactively proven.
    function configureClaimConsentVerifier(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(claimConsentVerifier) == address(0), "MediClaim: consent verifier already set");
        require(verifier.code.length != 0, "MediClaim: invalid consent verifier");
        claimConsentVerifier = IClaimConsentVerifier(verifier);
        emit ClaimConsentVerifierConfigured(verifier);
    }

    function registerClaimConsentCommitment(uint256 commitment) external {
        require(patientProfile.isRegistered(msg.sender), "MediClaim: patient not registered");
        require(claimConsentCommitment[msg.sender] == 0, "MediClaim: commitment already registered");
        require(commitment > 0 && commitment < SNARK_SCALAR_FIELD, "MediClaim: invalid commitment");
        claimConsentCommitment[msg.sender] = commitment;
        emit ClaimConsentCommitmentRegistered(msg.sender);
    }

    // Invalidate unspent authorizations for the pending claim. This cannot undo
    // an approval that has already executed or erase data already disclosed.
    function revokeClaimConsent(bytes32 claimId) external {
        Claim storage c = claims[claimId];
        require(c.patient == msg.sender, "MediClaim: not your claim");
        require(c.status == ClaimStatus.PendingPatientApproval, "MediClaim: not pending approval");
        uint256 nextNonce = ++claimConsentNonce[claimId];
        emit ClaimConsentRevoked(claimId, nextNonce);
    }

    function claimConsentPayload(bytes32 claimId) public view returns (bytes32) {
        Claim storage c = claims[claimId];
        require(c.claimId != bytes32(0), "MediClaim: unknown claim");
        return keccak256(abi.encode(c.policyHash, c.amount, privateClaimPayloadCommitment[claimId]));
    }

    function approveClaimWithConsentProof(
        bytes32 claimId, uint256 expiry, uint256 nonce, uint256 nullifier,
        uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata proofC
    ) external nonReentrant whenNotPaused {
        require(address(claimConsentVerifier) != address(0), "MediClaim: consent verifier not set");
        require(nullifier < SNARK_SCALAR_FIELD && !consumedConsentNullifiers[nullifier],
            "MediClaim: invalid or used nullifier");
        Claim storage c = claims[claimId];
        require(c.status == ClaimStatus.PendingPatientApproval, "MediClaim: not pending approval");
        require(msg.sender == c.hospital && hasRole(HOSPITAL_ROLE, msg.sender) &&
            hospitalRegistry.isApprovedHospital(msg.sender), "MediClaim: wrong requester");
        require(patientProfile.hasHospitalAccess(c.patient, msg.sender), "MediClaim: no patient access granted");
        require(block.timestamp < expiry, "MediClaim: consent expired");
        require(nonce == claimConsentNonce[claimId], "MediClaim: stale consent nonce");
        uint256 commitment = claimConsentCommitment[c.patient];
        require(commitment != 0, "MediClaim: missing consent commitment");

        require(privateClaimPayloadCommitment[claimId] != bytes32(0), "MediClaim: private draft required");
        uint256 digest = uint256(keccak256(abi.encode(
            CLAIM_CONSENT_DOMAIN, block.chainid, address(this), claimId, claimConsentPayload(claimId),
            c.patient, msg.sender, CLAIM_APPROVAL_ACTION, CLAIM_BILLING_CATEGORY, expiry, nonce
        )));
        uint256[5] memory signals = [nullifier, uint256(uint160(c.patient)), commitment,
            uint256(uint128(digest)), digest >> 128];
        require(claimConsentVerifier.verifyProof(a, b, proofC, signals), "MediClaim: invalid consent proof");

        consumedConsentNullifiers[nullifier] = true;
        emit ClaimConsentConsumed(claimId, msg.sender, nullifier);
        _approveClaim(claimId, c);
    }

    // Legacy mode remains available for the Revision 01 regression suite.
    function approveClaimByPatient(bytes32 _claimId) external nonReentrant whenNotPaused {
        require(address(claimConsentVerifier) == address(0), "MediClaim: claim consent proof required");
        Claim storage c = claims[_claimId];
        require(c.patient == msg.sender, "MediClaim: not your claim");
        _approveClaim(_claimId, c);
    }

    function _approveClaim(bytes32 _claimId, Claim storage c) internal {
        require(c.status == ClaimStatus.PendingPatientApproval,        "MediClaim: not pending approval");
        require(insurancePolicy.hasSufficientCoverage(c.policyHash, c.amount), "MediClaim: insufficient coverage");
        require(policyFunds[c.policyHash] >= c.amount,                 "MediClaim: policy not funded");

        c.patientActionAt = block.timestamp;
        totalApprovedByPatient++;
        emit ClaimApprovedByPatient(_claimId, c.patient, block.timestamp);

        // Now submit to oracle (Gate C)
        bytes32 commitment = privateClaimPayloadCommitment[_claimId];
        bytes32 oracleReqId = commitment == bytes32(0)
            ? oracleConsensus.requestValidation(_claimId, c.icdCode, c.cptCode)
            : oracleConsensus.requestPrivateValidation(_claimId, commitment);
        c.status          = ClaimStatus.UnderOracleReview;
        screeningDeadline[_claimId] = block.timestamp + SCREENING_TIMEOUT;
        c.oracleRequestId = oracleReqId;
        emit ClaimUnderOracleReview(_claimId, oracleReqId);
    }

    // ── Step 2b: Patient rejects the claim ────────────────────────────────────
    function rejectClaimByPatient(bytes32 _claimId, string calldata _reason) external {
        require(address(claimConsentVerifier) == address(0), "MediClaim: private rejection required");
        Claim storage c = _rejectPendingClaim(_claimId);
        c.patientRejectReason = _reason;
        emit ClaimRejectedByPatient(_claimId, msg.sender, _reason, block.timestamp);
    }

    function rejectPrivateClaim(bytes32 claimId) external {
        require(privateClaimPayloadCommitment[claimId] != bytes32(0), "MediClaim: private draft required");
        _rejectPendingClaim(claimId);
        emit PrivateClaimRejected(claimId, msg.sender, block.timestamp);
    }

    function _rejectPendingClaim(bytes32 _claimId) internal returns (Claim storage c) {
        c = claims[_claimId];
        require(c.patient == msg.sender,                               "MediClaim: not your claim");
        require(c.status == ClaimStatus.PendingPatientApproval,        "MediClaim: not pending approval");

        c.status              = ClaimStatus.PatientRejected;
        c.patientActionAt     = block.timestamp;
        c.resolvedAt          = block.timestamp;
        totalRejectedByPatient++;
    }

    // ── Step 3: Oracle callback ───────────────────────────────────────────────
    function oracleCallback(bytes32 _claimId, bytes32 _requestId, bool _approved, uint8 _confidence) external {
        Claim storage c = _requireOracleReview(_claimId, _requestId);
        c.oracleConfidence = _confidence;

        if (_approved) {
            c.status     = ClaimStatus.Approved;
            c.resolvedAt = block.timestamp;
            totalApprovedByOracle++;
            emit ClaimApprovedByOracle(_claimId, c.amount, _confidence);
            if (fraudScoreSubmitted[_claimId]) _applyScreeningResult(_claimId);
        } else {
            c.status             = ClaimStatus.Rejected;
            c.oracleRejectReason = "Oracle validation rejected";
            c.resolvedAt         = block.timestamp;
            totalRejectedByOracle++;
            emit ClaimRejectedByOracle(_claimId, c.oracleRejectReason, block.timestamp);
        }
    }

    function oracleTimeout(bytes32 _claimId, bytes32 _requestId) external {
        Claim storage c = _requireOracleReview(_claimId, _requestId);
        c.status = ClaimStatus.OracleTimedOut;
        c.resolvedAt = block.timestamp;
        emit ClaimOracleTimedOut(_claimId, _requestId);
    }

    function _requireOracleReview(bytes32 _claimId, bytes32 _requestId) internal view returns (Claim storage c) {
        require(msg.sender == address(oracleConsensus), "MediClaim: only oracle");
        c = claims[_claimId];
        require(c.status == ClaimStatus.UnderOracleReview, "MediClaim: invalid state");
        require(c.oracleRequestId == _requestId, "MediClaim: wrong request");
    }

    // ── ML fraud score (Gap 7) ────────────────────────────────────────────────
    uint256 public constant SCREENING_TIMEOUT = 30 minutes;
    mapping(bytes32 => uint256) public screeningDeadline;

    event ClaimScreeningTimedOut(bytes32 indexed claimId);

    function resolveScreeningTimeout(bytes32 claimId) external {
        Claim storage c = claims[claimId];
        require(c.status == ClaimStatus.Approved, "MediClaim: not approved");
        require(!fraudScoreSubmitted[claimId], "MediClaim: score already submitted");
        require(block.timestamp >= screeningDeadline[claimId], "MediClaim: screening deadline not reached");
        c.status = ClaimStatus.ScreeningTimedOut;
        c.resolvedAt = block.timestamp;
        emit ClaimScreeningTimedOut(claimId);
    }

    function updateFraudScore(bytes32 _claimId, uint256 _score) external onlyRole(ML_ORACLE_ROLE) {
        Claim storage c = claims[_claimId];
        require(c.status == ClaimStatus.UnderOracleReview || c.status == ClaimStatus.Approved,
            "MediClaim: not awaiting screening");
        require(!fraudScoreSubmitted[_claimId], "MediClaim: score already submitted");
        require(block.timestamp < screeningDeadline[_claimId], "MediClaim: screening deadline passed");
        require(_score <= 100, "MediClaim: invalid score");
        fraudScoreSubmitted[_claimId] = true;
        c.fraudScore = _score;
        c.fraudFlag = _score >= fraudScoreThreshold;
        emit MLScoreUpdated(_claimId, _score, c.fraudFlag);
        if (c.status == ClaimStatus.Approved) _applyScreeningResult(_claimId);
    }

    function _applyScreeningResult(bytes32 _claimId) internal {
        Claim storage c = claims[_claimId];
        if (c.fraudFlag) {
            c.status = ClaimStatus.FraudFlagged;
            totalFraudFlagged++;
            insurancePolicy.flagPolicyFraud(c.policyHash);
            emit FraudFlagged(_claimId, c.hospital, c.fraudScore, block.timestamp);
        } else {
            _releasePayment(_claimId);
        }
    }

    // ── Payment release ───────────────────────────────────────────────────────
    function _releasePayment(bytes32 _claimId) internal nonReentrant {
        Claim storage c = claims[_claimId];
        require(c.status == ClaimStatus.Approved, "MediClaim: not approved");
        require(fraudScoreSubmitted[_claimId],      "MediClaim: screening missing");
        require(!c.fraudFlag,                     "MediClaim: fraud flagged");
        require(policyFunds[c.policyHash] >= c.amount, "MediClaim: insufficient funds");

        policyFunds[c.policyHash] -= c.amount;
        c.status     = ClaimStatus.Paid;
        c.resolvedAt = block.timestamp;
        totalPaid   += c.amount;

        (bool ok,) = payable(c.hospital).call{value: c.amount}("");
        require(ok, "MediClaim: transfer failed");

        insurancePolicy.deductCoverage(c.policyHash, c.amount);
        emit ClaimPaid(_claimId, c.hospital, c.amount, c.resolvedAt - c.draftedAt);
    }

    function adminReleasePayment(bytes32 _claimId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _releasePayment(_claimId);
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function getClaim(bytes32 _claimId) external view returns (Claim memory) { return claims[_claimId]; }
    function getPatientClaims(address _p) external view returns (bytes32[] memory) { return patientClaims[_p]; }
    function getHospitalClaims(address _h) external view returns (bytes32[] memory) { return hospitalClaims[_h]; }
    function getPolicyBalance(bytes32 _ph) external view returns (uint256) { return policyFunds[_ph]; }

    function getSystemStats() external view returns (
        uint256 drafted, uint256 approvedByPatient, uint256 rejectedByPatient,
        uint256 approvedByOracle, uint256 rejectedByOracle, uint256 fraudFlagged, uint256 paid
    ) {
        return (totalDrafted, totalApprovedByPatient, totalRejectedByPatient,
                totalApprovedByOracle, totalRejectedByOracle, totalFraudFlagged, totalPaid);
    }

    // Pending approvals for a patient (claims they need to act on)
    function getPendingApprovals(address _patient) external view returns (bytes32[] memory) {
        bytes32[] storage all = patientClaims[_patient];
        uint count;
        for (uint i; i < all.length; i++) {
            if (claims[all[i]].status == ClaimStatus.PendingPatientApproval) count++;
        }
        bytes32[] memory pending = new bytes32[](count);
        uint idx;
        for (uint i; i < all.length; i++) {
            if (claims[all[i]].status == ClaimStatus.PendingPatientApproval) {
                pending[idx++] = all[i];
            }
        }
        return pending;
    }

    function pause()   external onlyRole(DEFAULT_ADMIN_ROLE) { _pause();   }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
    receive() external payable {}
}
