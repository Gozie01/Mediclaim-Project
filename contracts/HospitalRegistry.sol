// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// HospitalRegistry — approved hospitals + role-based personnel management
//
// Key innovations (Gap 8 extended):
//   • Any approved hospital can treat any patient who grants access
//   • Hospital personnel are assigned specific job roles
//   • Each role has defined default read/write permissions per data category
//   • Patients are NOT locked to a single hospital
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./DataTypes.sol";

contract HospitalRegistry is AccessControl {

    bytes32 public constant SYSTEM_ADMIN_ROLE = keccak256("SYSTEM_ADMIN_ROLE");
    bytes32 public constant HOSPITAL_ADMIN_ROLE = keccak256("HOSPITAL_ADMIN_ROLE");

    // ── Hospital data model ───────────────────────────────────────────────────
    struct Hospital {
        string  name;
        string  licenseNumber;
        string  fhirOrganizationId;  // FHIR Organization.id
        string  specialties;         // comma-separated e.g. "Cardiology,Oncology"
        string  location;
        address adminAddress;         // who manages this hospital's personnel
        bool    approved;             // approved by system admin for insurance
        bool    active;
        uint256 registeredAt;
        uint256 approvedAt;
    }

    // ── Personnel data model ──────────────────────────────────────────────────
    struct Personnel {
        string  name;
        uint8   role;               // DataTypes.ROLE_*
        string  staffId;            // hospital internal ID
        bool    active;
        uint256 addedAt;
    }

    // ── Storage ───────────────────────────────────────────────────────────────
    mapping(address => Hospital)                          public hospitals;
    // hospital → personnel address → Personnel
    mapping(address => mapping(address => Personnel))     public personnel;
    // personnel address → hospital address (reverse lookup)
    mapping(address => address)                           public personnelHospital;
    // hospital → list of personnel addresses
    mapping(address => address[])                         public hospitalStaff;

    address[] public allHospitals;
    address[] public approvedHospitals;

    // ── Events ────────────────────────────────────────────────────────────────
    event HospitalRegistered(address indexed hospital, string name, string licenseNumber);
    event HospitalApproved(address indexed hospital, uint256 timestamp);
    event HospitalDeactivated(address indexed hospital, uint256 timestamp);
    event PersonnelAdded(address indexed hospital, address indexed personnel, uint8 role, string name);
    event PersonnelRemoved(address indexed hospital, address indexed personnel, uint256 timestamp);
    event PersonnelRoleUpdated(address indexed hospital, address indexed personnel, uint8 oldRole, uint8 newRole);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE,  msg.sender);
        _grantRole(SYSTEM_ADMIN_ROLE,   msg.sender);
    }

    // ── Hospital registration (self-register, then admin approves) ────────────
    function registerHospital(
        string calldata _name,
        string calldata _licenseNumber,
        string calldata _fhirOrganizationId,
        string calldata _specialties,
        string calldata _location
    ) external {
        require(!hospitals[msg.sender].active, "HospitalRegistry: already registered");
        require(bytes(_name).length > 0,          "HospitalRegistry: name required");
        require(bytes(_licenseNumber).length > 0,  "HospitalRegistry: license required");

        hospitals[msg.sender] = Hospital({
            name:               _name,
            licenseNumber:      _licenseNumber,
            fhirOrganizationId: _fhirOrganizationId,
            specialties:        _specialties,
            location:           _location,
            adminAddress:       msg.sender,
            approved:           false,
            active:             true,
            registeredAt:       block.timestamp,
            approvedAt:         0
        });

        allHospitals.push(msg.sender);
        emit HospitalRegistered(msg.sender, _name, _licenseNumber);
    }

    // ── System admin approves hospital for insurance ──────────────────────────
    function approveHospital(address _hospital) external onlyRole(SYSTEM_ADMIN_ROLE) {
        require(hospitals[_hospital].active,    "HospitalRegistry: not registered");
        require(!hospitals[_hospital].approved, "HospitalRegistry: already approved");
        hospitals[_hospital].approved   = true;
        hospitals[_hospital].approvedAt = block.timestamp;
        approvedHospitals.push(_hospital);
        _grantRole(HOSPITAL_ADMIN_ROLE, _hospital);
        emit HospitalApproved(_hospital, block.timestamp);
    }

    function deactivateHospital(address _hospital) external onlyRole(SYSTEM_ADMIN_ROLE) {
        hospitals[_hospital].active   = false;
        hospitals[_hospital].approved = false;
        emit HospitalDeactivated(_hospital, block.timestamp);
    }

    // ── Hospital admin: manage personnel ──────────────────────────────────────
    function addPersonnel(
        address _personnelAddress,
        uint8   _role,
        string calldata _name,
        string calldata _staffId
    ) external {
        address hospital = msg.sender;
        require(hospitals[hospital].approved, "HospitalRegistry: hospital not approved");
        require(_role < DataTypes.TOTAL_ROLES, "HospitalRegistry: invalid role");
        require(personnelHospital[_personnelAddress] == address(0), "HospitalRegistry: already registered elsewhere");

        personnel[hospital][_personnelAddress] = Personnel({
            name:    _name,
            role:    _role,
            staffId: _staffId,
            active:  true,
            addedAt: block.timestamp
        });
        personnelHospital[_personnelAddress] = hospital;
        hospitalStaff[hospital].push(_personnelAddress);

        emit PersonnelAdded(hospital, _personnelAddress, _role, _name);
    }

    function removePersonnel(address _personnelAddress) external {
        address hospital = msg.sender;
        require(personnel[hospital][_personnelAddress].active, "HospitalRegistry: not found");
        personnel[hospital][_personnelAddress].active = false;
        delete personnelHospital[_personnelAddress];
        emit PersonnelRemoved(hospital, _personnelAddress, block.timestamp);
    }

    function updatePersonnelRole(address _personnelAddress, uint8 _newRole) external {
        address hospital = msg.sender;
        require(_newRole < DataTypes.TOTAL_ROLES, "HospitalRegistry: invalid role");
        uint8 oldRole = personnel[hospital][_personnelAddress].role;
        personnel[hospital][_personnelAddress].role = _newRole;
        emit PersonnelRoleUpdated(hospital, _personnelAddress, oldRole, _newRole);
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function isApprovedHospital(address _hospital) external view returns (bool) {
        return hospitals[_hospital].approved && hospitals[_hospital].active;
    }

    function getPersonnelRole(address _hospital, address _personnel) external view returns (uint8) {
        return personnel[_hospital][_personnel].role;
    }

    function getPersonnelHospital(address _personnel) external view returns (address) {
        return personnelHospital[_personnel];
    }

    function isActivePersonnel(address _hospital, address _personnel) external view returns (bool) {
        return personnel[_hospital][_personnel].active;
    }

    function getHospital(address _hospital) external view returns (Hospital memory) {
        return hospitals[_hospital];
    }

    function getApprovedHospitals() external view returns (address[] memory) {
        return approvedHospitals;
    }

    function getAllHospitals() external view returns (address[] memory) {
        return allHospitals;
    }

    function getHospitalStaff(address _hospital) external view returns (address[] memory) {
        return hospitalStaff[_hospital];
    }

    function getPersonnel(address _hospital, address _personnel) external view returns (Personnel memory) {
        return personnel[_hospital][_personnel];
    }

    // ── Self-registration check (personnel viewing their own info) ────────────
    function getMyHospital() external view returns (address hospital, Personnel memory me) {
        hospital = personnelHospital[msg.sender];
        if (hospital != address(0)) {
            me = personnel[hospital][msg.sender];
        }
    }
}
