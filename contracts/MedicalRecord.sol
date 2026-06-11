// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// MedicalRecord — role-based read/write for all 9 data categories per patient
//
// Key design:
//   • Any hospital personnel with write access can add/update a category record
//   • Any hospital personnel with read access can retrieve the IPFS CID
//   • Patients can view all their own records
//   • Every write is timestamped and attributed on-chain (full audit trail)
//   • PHI stays off-chain (IPFS) — only CID + hash on-chain
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./DataTypes.sol";

interface IPatientProfileV2 {
    function hasReadAccess(address patient, address personnel, uint8 category) external view returns (bool);
    function hasWriteAccess(address patient, address personnel, uint8 category) external view returns (bool);
    function isRegistered(address patient) external view returns (bool);
    function getPatient(address patient) external view returns (
        string memory did, string memory fhirId, string memory name,
        string memory dateOfBirth, string memory bloodType,
        string memory emergencyContact, string memory ipfsCid,
        bytes32 dataHash, uint256 registeredAt, uint256 lastUpdated,
        bool active, bool erased
    );
}

interface IHospitalRegistryV2 {
    function getPersonnelHospital(address personnel) external view returns (address);
    function getPersonnelRole(address hospital, address personnel) external view returns (uint8);
    function isActivePersonnel(address hospital, address personnel) external view returns (bool);
}

contract MedicalRecord is ReentrancyGuard {

    // ── Record for one patient + one data category ────────────────────────────
    struct Record {
        string  ipfsCid;         // IPFS CID of AES-256 encrypted data
        bytes32 dataHash;        // SHA-256 of the IPFS content
        address writtenBy;       // which personnel wrote this record
        address writtenByHospital; // which hospital they belong to
        uint8   writtenByRole;   // their job role at time of writing
        uint256 createdAt;
        uint256 updatedAt;
        uint256 version;         // incremented on every update
        bool    exists;
    }

    // ── Audit history entry ───────────────────────────────────────────────────
    struct AuditEntry {
        address actor;
        address hospital;
        uint8   action;     // 0=write, 1=read, 2=update
        uint256 timestamp;
        uint256 version;
    }

    IPatientProfileV2  public patientProfile;
    IHospitalRegistryV2 public hospitalRegistry;

    // patient → category → Record
    mapping(address => mapping(uint8 => Record))          public records;
    // patient → category → audit history
    mapping(address => mapping(uint8 => AuditEntry[]))    public auditTrail;

    // ── Events ────────────────────────────────────────────────────────────────
    event RecordWritten(
        address indexed patient, uint8 indexed category,
        address indexed writtenBy, string ipfsCid, uint256 version, uint256 timestamp
    );
    event RecordUpdated(
        address indexed patient, uint8 indexed category,
        address indexed updatedBy, string newIpfsCid, uint256 version, uint256 timestamp
    );
    event RecordRead(
        address indexed patient, uint8 indexed category,
        address indexed reader, uint256 timestamp
    );
    event UnauthorizedReadAttempt(
        address indexed patient, uint8 indexed category,
        address indexed caller, uint256 timestamp
    );

    constructor(address _patientProfile, address _hospitalRegistry) {
        patientProfile   = IPatientProfileV2(_patientProfile);
        hospitalRegistry = IHospitalRegistryV2(_hospitalRegistry);
    }

    // ── Write a record (requires write access from patient's consent) ─────────
    function writeRecord(
        address         _patient,
        uint8           _category,
        string calldata _ipfsCid,
        bytes32         _dataHash
    ) external nonReentrant {
        require(patientProfile.isRegistered(_patient),  "MedicalRecord: patient not registered");
        require(_category < DataTypes.TOTAL_CATEGORIES, "MedicalRecord: invalid category");
        require(
            patientProfile.hasWriteAccess(_patient, msg.sender, _category),
            "MedicalRecord: write access not granted"
        );

        address hospital = hospitalRegistry.getPersonnelHospital(msg.sender);
        uint8   role     = hospitalRegistry.getPersonnelRole(hospital, msg.sender);
        Record storage rec = records[_patient][_category];

        bool isUpdate = rec.exists;
        uint256 newVersion = rec.exists ? rec.version + 1 : 1;

        records[_patient][_category] = Record({
            ipfsCid:           _ipfsCid,
            dataHash:          _dataHash,
            writtenBy:         msg.sender,
            writtenByHospital: hospital,
            writtenByRole:     role,
            createdAt:         rec.exists ? rec.createdAt : block.timestamp,
            updatedAt:         block.timestamp,
            version:           newVersion,
            exists:            true
        });

        auditTrail[_patient][_category].push(AuditEntry({
            actor:     msg.sender,
            hospital:  hospital,
            action:    isUpdate ? 2 : 0,
            timestamp: block.timestamp,
            version:   newVersion
        }));

        if (isUpdate) {
            emit RecordUpdated(_patient, _category, msg.sender, _ipfsCid, newVersion, block.timestamp);
        } else {
            emit RecordWritten(_patient, _category, msg.sender, _ipfsCid, newVersion, block.timestamp);
        }
    }

    // ── Read a record CID (requires read access) ──────────────────────────────
    function getRecord(
        address _patient,
        uint8   _category
    ) external returns (string memory ipfsCid, bytes32 dataHash, uint256 version) {
        require(_category < DataTypes.TOTAL_CATEGORIES, "MedicalRecord: invalid category");

        bool canRead = patientProfile.hasReadAccess(_patient, msg.sender, _category)
                    || msg.sender == _patient; // patients always read own records

        if (!canRead) {
            emit UnauthorizedReadAttempt(_patient, _category, msg.sender, block.timestamp);
            revert("MedicalRecord: read access not granted");
        }

        Record storage rec = records[_patient][_category];

        // Log the read in audit trail
        if (msg.sender != _patient) {
            address hospital = hospitalRegistry.getPersonnelHospital(msg.sender);
            auditTrail[_patient][_category].push(AuditEntry({
                actor:     msg.sender,
                hospital:  hospital,
                action:    1,
                timestamp: block.timestamp,
                version:   rec.version
            }));
            emit RecordRead(_patient, _category, msg.sender, block.timestamp);
        }

        return (rec.ipfsCid, rec.dataHash, rec.version);
    }

    // ── Patient reads their own records (no consent needed) ───────────────────
    function getMyRecord(uint8 _category) external view returns (
        string memory ipfsCid, bytes32 dataHash, address writtenBy,
        string memory writtenByHospital_placeholder, uint256 version, uint256 updatedAt
    ) {
        Record storage rec = records[msg.sender][_category];
        return (
            rec.ipfsCid, rec.dataHash, rec.writtenBy,
            "", rec.version, rec.updatedAt
        );
    }

    // ── Verify integrity (anyone can check hash without seeing content) ────────
    function verifyIntegrity(
        address _patient,
        uint8   _category,
        bytes32 _expectedHash
    ) external view returns (bool intact) {
        return records[_patient][_category].dataHash == _expectedHash;
    }

    // ── Get audit trail (patient's own records only, or admin) ────────────────
    function getAuditTrail(
        address _patient,
        uint8   _category
    ) external view returns (AuditEntry[] memory) {
        require(msg.sender == _patient, "MedicalRecord: only patient can view audit trail");
        return auditTrail[_patient][_category];
    }

    // ── Check if record exists for a category ─────────────────────────────────
    function recordExists(address _patient, uint8 _category) external view returns (bool) {
        return records[_patient][_category].exists;
    }

    // ── Get which categories have records ─────────────────────────────────────
    function getCategoryStatus(address _patient) external view returns (bool[9] memory) {
        bool[9] memory status;
        for (uint8 i = 0; i < DataTypes.TOTAL_CATEGORIES; i++) {
            status[i] = records[_patient][i].exists;
        }
        return status;
    }
}
