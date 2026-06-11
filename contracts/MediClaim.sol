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
        string calldata cptCode, address mediClaimContract
    ) external returns (bytes32);
}

interface IHospitalRegistryV2b {
    function isApprovedHospital(address hospital) external view returns (bool);
}

contract MediClaim is AccessControl, ReentrancyGuard, Pausable {

    // ── Roles ─────────────────────────────────────────────────────────────────
    bytes32 public constant HOSPITAL_ROLE  = keccak256("HOSPITAL_ROLE");
    bytes32 public constant ML_ORACLE_ROLE = keccak256("ML_ORACLE_ROLE");

    // ── Claim state machine ───────────────────────────────────────────────────
    enum ClaimStatus {
        Draft,                  // 0  Hospital created, not yet sent to patient
        PendingPatientApproval, // 1  Awaiting patient sign-off
        PatientRejected,        // 2  Patient rejected (billing error, dispute)
        UnderOracleReview,      // 3  Patient approved, oracle validating ICD/CPT
        Approved,               // 4  Oracle approved
        Rejected,               // 5  Oracle rejected (invalid codes)
        Paid,                   // 6  Payment released to hospital
        FraudFlagged            // 7  ML oracle flagged anomaly
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

        // Gate: hospital must be approved
        require(hospitalRegistry.isApprovedHospital(msg.sender), "MediClaim: hospital not approved");
        // Gate: patient registered
        require(patientProfile.isRegistered(_patient), "MediClaim: patient not registered");
        // Gate: patient granted this hospital access (any access = can treat)
        require(patientProfile.hasHospitalAccess(_patient, msg.sender), "MediClaim: no patient access granted");
        // Gate: policy must be valid
        require(insurancePolicy.isActive(_policyHash), "MediClaim: policy not active");

        bytes32 claimId = keccak256(abi.encodePacked(_patient, msg.sender, _policyHash, block.timestamp));

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

    // ── Step 2a: Patient approves the claim ───────────────────────────────────
    function approveClaimByPatient(bytes32 _claimId) external nonReentrant {
        Claim storage c = claims[_claimId];
        require(c.patient == msg.sender,                               "MediClaim: not your claim");
        require(c.status == ClaimStatus.PendingPatientApproval,        "MediClaim: not pending approval");
        require(insurancePolicy.hasSufficientCoverage(c.policyHash, c.amount), "MediClaim: insufficient coverage");
        require(policyFunds[c.policyHash] >= c.amount,                 "MediClaim: policy not funded");

        c.patientActionAt = block.timestamp;
        totalApprovedByPatient++;
        emit ClaimApprovedByPatient(_claimId, msg.sender, block.timestamp);

        // Now submit to oracle (Gate C)
        bytes32 oracleReqId = oracleConsensus.requestValidation(
            _claimId, c.icdCode, c.cptCode, address(this)
        );
        c.status          = ClaimStatus.UnderOracleReview;
        c.oracleRequestId = oracleReqId;
        emit ClaimUnderOracleReview(_claimId, oracleReqId);
    }

    // ── Step 2b: Patient rejects the claim ────────────────────────────────────
    function rejectClaimByPatient(bytes32 _claimId, string calldata _reason) external {
        Claim storage c = claims[_claimId];
        require(c.patient == msg.sender,                               "MediClaim: not your claim");
        require(c.status == ClaimStatus.PendingPatientApproval,        "MediClaim: not pending approval");

        c.status              = ClaimStatus.PatientRejected;
        c.patientActionAt     = block.timestamp;
        c.patientRejectReason = _reason;
        c.resolvedAt          = block.timestamp;
        totalRejectedByPatient++;

        emit ClaimRejectedByPatient(_claimId, msg.sender, _reason, block.timestamp);
    }

    // ── Step 3: Oracle callback ───────────────────────────────────────────────
    function oracleCallback(bytes32 _claimId, bool _approved, uint8 _confidence) external {
        require(msg.sender == address(oracleConsensus), "MediClaim: only oracle");
        Claim storage c = claims[_claimId];
        require(c.status == ClaimStatus.UnderOracleReview, "MediClaim: invalid state");

        c.oracleConfidence = _confidence;

        if (_approved) {
            c.status     = ClaimStatus.Approved;
            c.resolvedAt = block.timestamp;
            totalApprovedByOracle++;
            emit ClaimApprovedByOracle(_claimId, c.amount, _confidence);
            if (!c.fraudFlag) _releasePayment(_claimId);
        } else {
            c.status             = ClaimStatus.Rejected;
            c.oracleRejectReason = "Oracle: ICD/CPT codes not covered by policy";
            c.resolvedAt         = block.timestamp;
            totalRejectedByOracle++;
            emit ClaimRejectedByOracle(_claimId, c.oracleRejectReason, block.timestamp);
        }
    }

    // ── ML fraud score (Gap 7) ────────────────────────────────────────────────
    function updateFraudScore(bytes32 _claimId, uint256 _score) external onlyRole(ML_ORACLE_ROLE) {
        Claim storage c = claims[_claimId];
        c.fraudScore = _score;
        bool flag = _score >= fraudScoreThreshold;
        if (flag && !c.fraudFlag) {
            c.fraudFlag = true;
            c.status    = ClaimStatus.FraudFlagged;
            totalFraudFlagged++;
            insurancePolicy.flagPolicyFraud(c.policyHash);
            emit FraudFlagged(_claimId, c.hospital, _score, block.timestamp);
        }
        emit MLScoreUpdated(_claimId, _score, flag);
    }

    // ── Payment release ───────────────────────────────────────────────────────
    function _releasePayment(bytes32 _claimId) internal nonReentrant {
        Claim storage c = claims[_claimId];
        require(c.status == ClaimStatus.Approved, "MediClaim: not approved");
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
        Claim storage c = claims[_claimId];
        c.fraudFlag = false;
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
