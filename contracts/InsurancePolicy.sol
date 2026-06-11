// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// InsurancePolicy — Gap 6 (FHIR interoperability)
//
// Data fields map to FHIR R4 Coverage resource:
//   policyId        → Coverage.id
//   patient         → Coverage.beneficiary (Reference → Patient)
//   insurer         → Coverage.payor       (Reference → Organization)
//   coveredIcdCodes → Coverage.class[].value (ICD-10 codes)
//   validFrom/Until → Coverage.period.start / .end
//   coverageLimit   → Coverage.costToBeneficiary[].value.value
//
// Funds are held in MediClaim contract; InsurancePolicy tracks limits only.
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/access/AccessControl.sol";

contract InsurancePolicy is AccessControl {

    bytes32 public constant INSURER_ROLE   = keccak256("INSURER_ROLE");
    bytes32 public constant MEDICHAIN_ROLE = keccak256("MEDICHAIN_ROLE"); // MediClaim contract

    // ── FHIR R4 Coverage resource–aligned struct (Gap 6) ─────────────────────
    struct Policy {
        string   policyId;          // FHIR Coverage.id
        string   fhirOrganizationId;// FHIR Organization.id of insurer
        address  patient;           // Coverage.beneficiary
        address  insurer;           // Coverage.payor
        uint256  coverageLimit;     // Max claimable (wei)
        uint256  remainingLimit;    // Decremented per approved claim
        uint256  validFrom;         // Coverage.period.start (unix)
        uint256  validUntil;        // Coverage.period.end   (unix)
        string[] coveredIcdCodes;   // ICD-10 diagnosis codes covered
        string[] coveredCptCodes;   // CPT procedure codes covered
        bool     active;
        bool     fraudFlagged;      // Set by MediClaim on fraud detection
        uint256  registeredAt;
    }

    mapping(bytes32 => Policy)       public policies;          // policyHash → Policy
    mapping(address => bytes32[])    public patientPolicies;   // patient → [policyHash]
    mapping(address => bytes32[])    public insurerPolicies;   // insurer → [policyHash]
    mapping(address => bool)         public registeredInsurers;

    // ── Events ────────────────────────────────────────────────────────────────
    event InsurerRegistered(address indexed insurer, uint256 timestamp);
    event PolicyRegistered(
        bytes32 indexed policyHash,
        address indexed patient,
        address indexed insurer,
        uint256 coverageLimit,
        string  policyId
    );
    event PolicyDeactivated(bytes32 indexed policyHash, uint256 timestamp);
    event CoverageDeducted(bytes32 indexed policyHash, uint256 amount, uint256 remaining);
    event PolicyFraudFlagged(bytes32 indexed policyHash, uint256 timestamp);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ── Admin: register insurer and MediClaim contract ────────────────────────
    function registerInsurer(address _insurer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(INSURER_ROLE, _insurer);
        registeredInsurers[_insurer] = true;
        emit InsurerRegistered(_insurer, block.timestamp);
    }

    function setMediClaimContract(address _mediClaim) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MEDICHAIN_ROLE, _mediClaim);
    }

    // ── Insurer: register a new policy ───────────────────────────────────────
    function registerPolicy(
        string   calldata _policyId,
        string   calldata _fhirOrganizationId,
        address           _patient,
        uint256           _coverageLimit,
        uint256           _validFrom,
        uint256           _validUntil,
        string[] calldata _coveredIcdCodes,
        string[] calldata _coveredCptCodes
    ) external onlyRole(INSURER_ROLE) returns (bytes32) {
        require(_validUntil > block.timestamp,  "InsurancePolicy: already expired");
        require(_validFrom  < _validUntil,      "InsurancePolicy: invalid period");
        require(bytes(_policyId).length > 0,    "InsurancePolicy: policyId required");

        bytes32 policyHash = keccak256(
            abi.encodePacked(_policyId, _patient, msg.sender, block.timestamp)
        );
        require(policies[policyHash].registeredAt == 0, "InsurancePolicy: duplicate");

        Policy storage p = policies[policyHash];
        p.policyId           = _policyId;
        p.fhirOrganizationId = _fhirOrganizationId;
        p.patient            = _patient;
        p.insurer            = msg.sender;
        p.coverageLimit      = _coverageLimit;
        p.remainingLimit     = _coverageLimit;
        p.validFrom          = _validFrom;
        p.validUntil         = _validUntil;
        p.active             = true;
        p.fraudFlagged       = false;
        p.registeredAt       = block.timestamp;

        for (uint i = 0; i < _coveredIcdCodes.length; i++) {
            p.coveredIcdCodes.push(_coveredIcdCodes[i]);
        }
        for (uint i = 0; i < _coveredCptCodes.length; i++) {
            p.coveredCptCodes.push(_coveredCptCodes[i]);
        }

        patientPolicies[_patient].push(policyHash);
        insurerPolicies[msg.sender].push(policyHash);

        emit PolicyRegistered(policyHash, _patient, msg.sender, _coverageLimit, _policyId);
        return policyHash;
    }

    // ── Called by MediClaim on approved claim ─────────────────────────────────
    function deductCoverage(
        bytes32 _policyHash,
        uint256 _amount
    ) external onlyRole(MEDICHAIN_ROLE) {
        Policy storage p = policies[_policyHash];
        require(p.active,                   "InsurancePolicy: not active");
        require(p.remainingLimit >= _amount, "InsurancePolicy: limit exceeded");
        p.remainingLimit -= _amount;
        emit CoverageDeducted(_policyHash, _amount, p.remainingLimit);
    }

    // ── Called by MediClaim on fraud detection ────────────────────────────────
    function flagPolicyFraud(bytes32 _policyHash) external onlyRole(MEDICHAIN_ROLE) {
        policies[_policyHash].fraudFlagged = true;
        emit PolicyFraudFlagged(_policyHash, block.timestamp);
    }

    // ── Insurer: deactivate a policy ──────────────────────────────────────────
    function deactivatePolicy(bytes32 _policyHash) external onlyRole(INSURER_ROLE) {
        require(policies[_policyHash].insurer == msg.sender, "InsurancePolicy: not your policy");
        policies[_policyHash].active = false;
        emit PolicyDeactivated(_policyHash, block.timestamp);
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function isActive(bytes32 _policyHash) public view returns (bool) {
        Policy storage p = policies[_policyHash];
        return  p.active &&
               !p.fraudFlagged &&
                block.timestamp >= p.validFrom &&
                block.timestamp <= p.validUntil;
    }

    function hasSufficientCoverage(
        bytes32 _policyHash,
        uint256 _amount
    ) external view returns (bool) {
        return isActive(_policyHash) && policies[_policyHash].remainingLimit >= _amount;
    }

    function icdCodeCovered(
        bytes32 _policyHash,
        string calldata _icdCode
    ) external view returns (bool) {
        string[] storage codes = policies[_policyHash].coveredIcdCodes;
        for (uint i = 0; i < codes.length; i++) {
            if (keccak256(bytes(codes[i])) == keccak256(bytes(_icdCode))) return true;
        }
        return false;
    }

    function cptCodeCovered(
        bytes32 _policyHash,
        string calldata _cptCode
    ) external view returns (bool) {
        string[] storage codes = policies[_policyHash].coveredCptCodes;
        for (uint i = 0; i < codes.length; i++) {
            if (keccak256(bytes(codes[i])) == keccak256(bytes(_cptCode))) return true;
        }
        return false;
    }

    function getPolicy(bytes32 _policyHash) external view returns (
        string memory policyId,
        address patient,
        address insurer,
        uint256 coverageLimit,
        uint256 remainingLimit,
        uint256 validFrom,
        uint256 validUntil,
        bool    active,
        bool    fraudFlagged
    ) {
        Policy storage p = policies[_policyHash];
        return (
            p.policyId, p.patient, p.insurer,
            p.coverageLimit, p.remainingLimit,
            p.validFrom, p.validUntil,
            p.active, p.fraudFlagged
        );
    }

    function getCoveredCodes(bytes32 _policyHash) external view returns (
        string[] memory icdCodes,
        string[] memory cptCodes
    ) {
        return (policies[_policyHash].coveredIcdCodes, policies[_policyHash].coveredCptCodes);
    }

    function getPatientPolicies(address _patient) external view returns (bytes32[] memory) {
        return patientPolicies[_patient];
    }
}
