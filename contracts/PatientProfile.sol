// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// PatientProfile v2 — Granular consent + data sovereignty + GDPR
//
// What's new vs v1:
//   • Granular consent: patient grants access per (hospital, role, category)
//   • Access types: READ or READ+WRITE — hospitals with write access can update records
//   • Duration: optional expiry on every consent grant
//   • Multi-hospital freedom: patient can grant ANY approved hospital access
//   • Role-based: a hospital's Doctor gets different access than its Billing staff
//   • GDPR Art.17 tombstone erasure preserved
//   • FHIR R4 Patient resource-aligned data fields
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./DataTypes.sol";
import "./ZKConsentVerifier.sol";

interface IHospitalRegistry {
    function getPersonnelHospital(address personnel) external view returns (address);
    function getPersonnelRole(address hospital, address personnel) external view returns (uint8);
    function isActivePersonnel(address hospital, address personnel) external view returns (bool);
    function isApprovedHospital(address hospital) external view returns (bool);
}

contract PatientProfile is AccessControl, ReentrancyGuard {

    bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

    // ── FHIR R4 Patient resource-aligned struct ───────────────────────────────
    struct PatientData {
        string  did;          // Decentralized Identifier
        string  fhirId;       // FHIR Patient.id
        string  name;         // Patient full name
        string  dateOfBirth;  // YYYY-MM-DD
        string  bloodType;    // A+, B-, O+, etc.
        string  emergencyContact;
        string  ipfsCid;      // encrypted master health record CID
        bytes32 dataHash;     // integrity hash
        uint256 registeredAt;
        uint256 lastUpdated;
        bool    active;
        bool    erased;       // GDPR tombstone
    }

    // ── Consent record: patient → hospital → role → category ─────────────────
    struct ConsentGrant {
        bool    readAccess;
        bool    writeAccess;
        uint256 grantedAt;
        uint256 expiresAt;  // 0 = never expires
        bool    active;
    }

    IZKConsentVerifier  public zkVerifier;
    IHospitalRegistry   public hospitalRegistry;

    mapping(address => PatientData) public patients;

    // patient → hospital → role → category → ConsentGrant
    // Using flat key for gas efficiency
    mapping(bytes32 => ConsentGrant) private _consents;

    // patient → list of hospitals they granted any access to
    mapping(address => address[])   public patientHospitals;
    mapping(address => mapping(address => bool)) private _hasHospital;

    // ── Events ────────────────────────────────────────────────────────────────
    event PatientRegistered(address indexed patient, string did, string fhirId, uint256 timestamp);
    event PatientProfileUpdated(address indexed patient, uint256 timestamp);
    event AccessGranted(address indexed patient, address indexed hospital, uint8 role, uint8 category, bool writeAccess, uint256 expiresAt);
    event AccessRevoked(address indexed patient, address indexed hospital, uint8 role, uint8 category, uint256 timestamp);
    event AllHospitalAccessRevoked(address indexed patient, address indexed hospital, uint256 timestamp);
    event DataErased(address indexed patient, bytes32 tombstoneHash, uint256 timestamp);

    constructor(address _zkVerifier, address _hospitalRegistry) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        zkVerifier       = IZKConsentVerifier(_zkVerifier);
        hospitalRegistry = IHospitalRegistry(_hospitalRegistry);
    }

    // ── Patient registration ──────────────────────────────────────────────────
    function registerPatient(
        string calldata _did,
        string calldata _fhirId,
        string calldata _name,
        string calldata _dateOfBirth,
        string calldata _bloodType,
        string calldata _ipfsCid,
        bytes32         _dataHash
    ) external {
        require(!patients[msg.sender].active, "PatientProfile: already registered");
        require(bytes(_did).length > 0,  "PatientProfile: DID required");
        require(bytes(_name).length > 0, "PatientProfile: name required");

        patients[msg.sender] = PatientData({
            did:              _did,
            fhirId:           _fhirId,
            name:             _name,
            dateOfBirth:      _dateOfBirth,
            bloodType:        _bloodType,
            emergencyContact: "",
            ipfsCid:          _ipfsCid,
            dataHash:         _dataHash,
            registeredAt:     block.timestamp,
            lastUpdated:      block.timestamp,
            active:           true,
            erased:           false
        });

        _grantRole(PATIENT_ROLE, msg.sender);
        emit PatientRegistered(msg.sender, _did, _fhirId, block.timestamp);
    }

    // ── Update profile info ───────────────────────────────────────────────────
    function updateProfile(
        string calldata _name,
        string calldata _emergencyContact,
        string calldata _ipfsCid,
        bytes32         _dataHash
    ) external onlyRole(PATIENT_ROLE) {
        _requireActive(msg.sender);
        PatientData storage p = patients[msg.sender];
        p.name             = _name;
        p.emergencyContact = _emergencyContact;
        p.ipfsCid          = _ipfsCid;
        p.dataHash         = _dataHash;
        p.lastUpdated      = block.timestamp;
        emit PatientProfileUpdated(msg.sender, block.timestamp);
    }

    // ── Grant access: specific role + specific data category ──────────────────
    function grantAccess(
        address _hospital,
        uint8   _role,
        uint8   _category,
        bool    _writeAccess,
        uint256 _durationDays   // 0 = no expiry
    ) external onlyRole(PATIENT_ROLE) {
        _requireActive(msg.sender);
        require(hospitalRegistry.isApprovedHospital(_hospital), "PatientProfile: hospital not approved");
        require(_role     < DataTypes.TOTAL_ROLES,      "PatientProfile: invalid role");
        require(_category < DataTypes.TOTAL_CATEGORIES, "PatientProfile: invalid category");

        uint256 expiresAt = _durationDays > 0
            ? block.timestamp + (_durationDays * 1 days)
            : 0;

        bytes32 key = _key(msg.sender, _hospital, _role, _category);
        _consents[key] = ConsentGrant({
            readAccess:  true,
            writeAccess: _writeAccess,
            grantedAt:   block.timestamp,
            expiresAt:   expiresAt,
            active:      true
        });

        if (!_hasHospital[msg.sender][_hospital]) {
            patientHospitals[msg.sender].push(_hospital);
            _hasHospital[msg.sender][_hospital] = true;
        }

        emit AccessGranted(msg.sender, _hospital, _role, _category, _writeAccess, expiresAt);
    }

    // ── Grant access with ZK proof (Gap 3 — privacy-preserving) ──────────────
    function grantAccessWithZKProof(
        address          _hospital,
        uint8            _role,
        uint8            _category,
        bool             _writeAccess,
        uint256          _durationDays,
        uint256[2]    calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2]    calldata _pC,
        uint256[1]    calldata _pubSignals
    ) external onlyRole(PATIENT_ROLE) {
        require(zkVerifier.verifyProof(_pA, _pB, _pC, _pubSignals), "PatientProfile: invalid ZK proof");
        this.grantAccess(_hospital, _role, _category, _writeAccess, _durationDays);
    }

    // ── Revoke a specific access grant ────────────────────────────────────────
    function revokeAccess(
        address _hospital,
        uint8   _role,
        uint8   _category
    ) external onlyRole(PATIENT_ROLE) {
        bytes32 key = _key(msg.sender, _hospital, _role, _category);
        _consents[key].active = false;
        emit AccessRevoked(msg.sender, _hospital, _role, _category, block.timestamp);
    }

    // ── Revoke ALL access from a hospital ─────────────────────────────────────
    function revokeAllFromHospital(address _hospital) external onlyRole(PATIENT_ROLE) {
        for (uint8 role = 0; role < DataTypes.TOTAL_ROLES; role++) {
            for (uint8 cat = 0; cat < DataTypes.TOTAL_CATEGORIES; cat++) {
                bytes32 key = _key(msg.sender, _hospital, role, cat);
                if (_consents[key].active) {
                    _consents[key].active = false;
                }
            }
        }
        emit AllHospitalAccessRevoked(msg.sender, _hospital, block.timestamp);
    }

    // ── GDPR Art.17 Erasure ───────────────────────────────────────────────────
    function revokeAndErase(string calldata _reason) external onlyRole(PATIENT_ROLE) nonReentrant {
        PatientData storage p = patients[msg.sender];
        require(p.active,  "PatientProfile: not active");
        require(!p.erased, "PatientProfile: already erased");

        bytes32 tombstone = keccak256(abi.encodePacked(msg.sender, p.ipfsCid, _reason, block.timestamp));
        p.ipfsCid    = "";
        p.dataHash   = tombstone;
        p.erased     = true;
        p.lastUpdated = block.timestamp;

        emit DataErased(msg.sender, tombstone, block.timestamp);
    }

    // ── Access check: called by MedicalRecord / MediClaim ────────────────────
    // Resolves personnel → hospital + role automatically via HospitalRegistry

    function hasReadAccess(
        address _patient,
        address _personnel,
        uint8   _category
    ) external view returns (bool) {
        PatientData storage p = patients[_patient];
        if (!p.active || p.erased) return false;

        address hospital = hospitalRegistry.getPersonnelHospital(_personnel);
        if (hospital == address(0)) return false;
        if (!hospitalRegistry.isActivePersonnel(hospital, _personnel)) return false;

        uint8   role = hospitalRegistry.getPersonnelRole(hospital, _personnel);
        ConsentGrant storage g = _consents[_key(_patient, hospital, role, _category)];

        return g.active && g.readAccess && _notExpired(g.expiresAt);
    }

    function hasWriteAccess(
        address _patient,
        address _personnel,
        uint8   _category
    ) external view returns (bool) {
        PatientData storage p = patients[_patient];
        if (!p.active || p.erased) return false;

        address hospital = hospitalRegistry.getPersonnelHospital(_personnel);
        if (hospital == address(0)) return false;
        if (!hospitalRegistry.isActivePersonnel(hospital, _personnel)) return false;

        uint8   role = hospitalRegistry.getPersonnelRole(hospital, _personnel);
        ConsentGrant storage g = _consents[_key(_patient, hospital, role, _category)];

        return g.active && g.readAccess && g.writeAccess && _notExpired(g.expiresAt);
    }

    // ── Hospital-level consent check (used by MediClaim for claim submission) ─
    function hasHospitalAccess(address _patient, address _hospital) external view returns (bool) {
        PatientData storage p = patients[_patient];
        if (!p.active || p.erased) return false;
        // Patient has granted any active access to this hospital
        for (uint8 role = 0; role < DataTypes.TOTAL_ROLES; role++) {
            for (uint8 cat = 0; cat < DataTypes.TOTAL_CATEGORIES; cat++) {
                ConsentGrant storage g = _consents[_key(_patient, _hospital, role, cat)];
                if (g.active && _notExpired(g.expiresAt)) return true;
            }
        }
        return false;
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function getPatient(address _patient) external view returns (PatientData memory) {
        return patients[_patient];
    }

    function isRegistered(address _patient) external view returns (bool) {
        return patients[_patient].active;
    }

    function getConsent(
        address _patient, address _hospital, uint8 _role, uint8 _category
    ) external view returns (ConsentGrant memory) {
        return _consents[_key(_patient, _hospital, _role, _category)];
    }

    function getGrantedHospitals(address _patient) external view returns (address[] memory) {
        return patientHospitals[_patient];
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    function _key(address patient, address hospital, uint8 role, uint8 category)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(patient, hospital, role, category));
    }

    function _requireActive(address _patient) internal view {
        require(patients[_patient].active,  "PatientProfile: not active");
        require(!patients[_patient].erased, "PatientProfile: data erased");
    }

    function _notExpired(uint256 expiresAt) internal view returns (bool) {
        return expiresAt == 0 || block.timestamp <= expiresAt;
    }
}
