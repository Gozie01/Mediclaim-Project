// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// DataTypes — shared constants for roles, data categories, and access bitmaps
// ─────────────────────────────────────────────────────────────────────────────

library DataTypes {

    // ── Hospital personnel job roles ──────────────────────────────────────────
    uint8 public constant ROLE_DOCTOR       = 0;
    uint8 public constant ROLE_NURSE        = 1;
    uint8 public constant ROLE_BILLING      = 2;
    uint8 public constant ROLE_PHARMACIST   = 3;
    uint8 public constant ROLE_RADIOLOGIST  = 4;
    uint8 public constant ROLE_ADMIN        = 5;
    uint8 public constant ROLE_LAB_TECH     = 6;
    uint8 public constant ROLE_RECEPTIONIST = 7;
    uint8 public constant TOTAL_ROLES       = 8;

    // ── Medical data categories ───────────────────────────────────────────────
    // bit 0 = DEMOGRAPHICS, bit 1 = MEDICAL_HISTORY, ..., bit 8 = TREATMENT_NOTES
    uint8 public constant CAT_DEMOGRAPHICS    = 0;
    uint8 public constant CAT_MEDICAL_HISTORY = 1;
    uint8 public constant CAT_LAB_RESULTS     = 2;
    uint8 public constant CAT_PRESCRIPTIONS   = 3;
    uint8 public constant CAT_IMAGING         = 4;
    uint8 public constant CAT_VITALS          = 5;
    uint8 public constant CAT_NURSING_NOTES   = 6;
    uint8 public constant CAT_BILLING_INFO    = 7;
    uint8 public constant CAT_TREATMENT_NOTES = 8;
    uint8 public constant TOTAL_CATEGORIES    = 9;

    // ── Default READ permissions per role (9-bit bitmap) ─────────────────────
    // Each bit corresponds to a data category above.
    function defaultReadBitmap(uint8 role) internal pure returns (uint16) {
        if (role == ROLE_DOCTOR)       return 0x1FF; // all 9 categories
        if (role == ROLE_NURSE)        return 0x061; // Demographics(0)+Vitals(5)+Nursing(6)
        if (role == ROLE_BILLING)      return 0x081; // Demographics(0)+Billing(7)
        if (role == ROLE_PHARMACIST)   return 0x009; // Demographics(0)+Prescriptions(3)
        if (role == ROLE_RADIOLOGIST)  return 0x013; // Demographics(0)+History(1)+Imaging(4)
        if (role == ROLE_ADMIN)        return 0x001; // Demographics(0) only
        if (role == ROLE_LAB_TECH)     return 0x007; // Demographics(0)+History(1)+Lab(2)
        if (role == ROLE_RECEPTIONIST) return 0x001; // Demographics(0) only
        return 0x000;
    }

    // ── Default WRITE permissions per role ────────────────────────────────────
    function defaultWriteBitmap(uint8 role) internal pure returns (uint16) {
        if (role == ROLE_DOCTOR)       return 0x11E; // History+Lab+Rx+Imaging+Treatment
        if (role == ROLE_NURSE)        return 0x060; // Vitals+Nursing Notes
        if (role == ROLE_BILLING)      return 0x080; // Billing Info
        if (role == ROLE_PHARMACIST)   return 0x008; // Prescriptions
        if (role == ROLE_RADIOLOGIST)  return 0x010; // Imaging
        if (role == ROLE_ADMIN)        return 0x001; // Demographics
        if (role == ROLE_LAB_TECH)     return 0x004; // Lab Results
        if (role == ROLE_RECEPTIONIST) return 0x001; // Demographics
        return 0x000;
    }

    // ── Human-readable names ──────────────────────────────────────────────────
    function roleName(uint8 role) internal pure returns (string memory) {
        if (role == ROLE_DOCTOR)       return "Doctor";
        if (role == ROLE_NURSE)        return "Nurse";
        if (role == ROLE_BILLING)      return "Billing Staff";
        if (role == ROLE_PHARMACIST)   return "Pharmacist";
        if (role == ROLE_RADIOLOGIST)  return "Radiologist";
        if (role == ROLE_ADMIN)        return "Admin";
        if (role == ROLE_LAB_TECH)     return "Lab Technician";
        if (role == ROLE_RECEPTIONIST) return "Receptionist";
        return "Unknown";
    }

    function categoryName(uint8 cat) internal pure returns (string memory) {
        if (cat == CAT_DEMOGRAPHICS)    return "Demographics";
        if (cat == CAT_MEDICAL_HISTORY) return "Medical History";
        if (cat == CAT_LAB_RESULTS)     return "Lab Results";
        if (cat == CAT_PRESCRIPTIONS)   return "Prescriptions";
        if (cat == CAT_IMAGING)         return "Imaging";
        if (cat == CAT_VITALS)          return "Vitals";
        if (cat == CAT_NURSING_NOTES)   return "Nursing Notes";
        if (cat == CAT_BILLING_INFO)    return "Billing Info";
        if (cat == CAT_TREATMENT_NOTES) return "Treatment Notes";
        return "Unknown";
    }

    // ── Bitmap helpers ────────────────────────────────────────────────────────
    function categoryInBitmap(uint16 bitmap, uint8 category) internal pure returns (bool) {
        return (bitmap >> category) & 1 == 1;
    }
}
