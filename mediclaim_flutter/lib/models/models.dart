// COMPLETE FILE — do not truncate

class PatientModel {
  final String address;
  final String name;
  final String dateOfBirth;
  final String bloodType;
  final String did;
  final String fhirId;
  final bool registered;
  final DateTime registeredAt;

  PatientModel({
    required this.address,
    required this.name,
    required this.dateOfBirth,
    required this.bloodType,
    required this.did,
    required this.fhirId,
    required this.registered,
    required this.registeredAt,
  });

  PatientModel copyWith({
    String? name,
    String? dateOfBirth,
    String? bloodType,
    String? did,
    String? fhirId,
    bool? registered,
  }) {
    return PatientModel(
      address: address,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodType: bloodType ?? this.bloodType,
      did: did ?? this.did,
      fhirId: fhirId ?? this.fhirId,
      registered: registered ?? this.registered,
      registeredAt: registeredAt,
    );
  }
}

class HospitalModel {
  final String address;
  final String name;
  final String licenseNumber;
  final String location;
  final String specialties;
  final bool approved;
  final bool active;
  final DateTime registeredAt;

  HospitalModel({
    required this.address,
    required this.name,
    required this.licenseNumber,
    required this.location,
    required this.specialties,
    required this.approved,
    required this.active,
    required this.registeredAt,
  });
}

class PersonnelModel {
  final String address;
  final String hospitalAddress;
  final String name;
  final String staffId;
  final int role; // 0=Doctor 1=Nurse 2=Billing 3=Pharmacist 4=Radiologist 5=Admin 6=LabTech 7=Receptionist

  PersonnelModel({
    required this.address,
    required this.hospitalAddress,
    required this.name,
    required this.staffId,
    required this.role,
  });
}

class ConsentModel {
  final String id;
  final String patientAddress;
  final String hospitalAddress;
  final String hospitalName;
  final int role;
  final bool readAccess;
  final bool writeAccess;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  bool active;

  ConsentModel({
    required this.id,
    required this.patientAddress,
    required this.hospitalAddress,
    required this.hospitalName,
    required this.role,
    required this.readAccess,
    required this.writeAccess,
    required this.grantedAt,
    this.expiresAt,
    this.active = true,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get expiryText {
    if (expiresAt == null) return 'Permanent';
    if (isExpired) return 'Expired';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m remaining';
    if (diff.inHours < 24) return '${diff.inHours}h remaining';
    return '${diff.inDays}d remaining';
  }
}

enum ClaimStatus {
  draft,
  pendingPatient,
  patientRejected,
  underReview,
  approved,
  rejected,
  paid,
  fraudFlagged,
  paymentConfirmed,
}

extension ClaimStatusExt on ClaimStatus {
  String get label {
    switch (this) {
      case ClaimStatus.draft: return 'Draft';
      case ClaimStatus.pendingPatient: return 'Pending Your Approval';
      case ClaimStatus.patientRejected: return 'Rejected by Patient';
      case ClaimStatus.underReview: return 'Under Review';
      case ClaimStatus.approved: return 'Approved';
      case ClaimStatus.rejected: return 'Rejected';
      case ClaimStatus.paid: return 'Paid';
      case ClaimStatus.fraudFlagged: return 'Fraud Flagged';
      case ClaimStatus.paymentConfirmed: return 'Payment Confirmed';
    }
  }

  int get color {
    switch (this) {
      case ClaimStatus.draft: return 0xFF94A3B8;
      case ClaimStatus.pendingPatient: return 0xFFF59E0B;
      case ClaimStatus.patientRejected: return 0xFFEF4444;
      case ClaimStatus.underReview: return 0xFF3B82F6;
      case ClaimStatus.approved: return 0xFF10B981;
      case ClaimStatus.rejected: return 0xFFEF4444;
      case ClaimStatus.paid: return 0xFF6366F1;
      case ClaimStatus.fraudFlagged: return 0xFFDC2626;
      case ClaimStatus.paymentConfirmed: return 0xFF059669;
    }
  }
}

class ClaimModel {
  final String id;
  final String patientAddress;
  final String patientName;
  final String hospitalAddress;
  final String hospitalName;
  final double amountEth;
  final String icdCode;
  final String cptCode;
  final String treatmentSummary;
  ClaimStatus status;
  final DateTime draftedAt;
  DateTime? patientActionAt;
  DateTime? oracleActionAt;
  DateTime? paidAt;
  DateTime? confirmedAt;
  String? patientRejectReason;
  String? oracleRejectReason;

  ClaimModel({
    required this.id,
    required this.patientAddress,
    required this.patientName,
    required this.hospitalAddress,
    required this.hospitalName,
    required this.amountEth,
    required this.icdCode,
    required this.cptCode,
    required this.treatmentSummary,
    required this.status,
    required this.draftedAt,
    this.patientActionAt,
    this.oracleActionAt,
    this.paidAt,
    this.confirmedAt,
    this.patientRejectReason,
    this.oracleRejectReason,
  });
}

enum InsuranceTier { basic, medium, premium }

extension InsuranceTierExt on InsuranceTier {
  String get label {
    switch (this) {
      case InsuranceTier.basic: return 'Basic';
      case InsuranceTier.medium: return 'Medium';
      case InsuranceTier.premium: return 'Premium';
    }
  }
  int get color {
    switch (this) {
      case InsuranceTier.basic: return 0xFF64748B;
      case InsuranceTier.medium: return 0xFF3B82F6;
      case InsuranceTier.premium: return 0xFFF59E0B;
    }
  }
  String get emoji {
    switch (this) {
      case InsuranceTier.basic: return '🩺';
      case InsuranceTier.medium: return '🏥';
      case InsuranceTier.premium: return '👑';
    }
  }
}

class PolicyModel {
  final String hash;
  final String patientAddress;
  final String insurerAddress;
  final InsuranceTier tier;
  final double coverageLimitEth;
  final List<String> coveredHospitalAddresses;
  final List<String> coveredServices;
  final DateTime validFrom;
  final DateTime validUntil;
  double usedAmountEth;

  PolicyModel({
    required this.hash,
    required this.patientAddress,
    required this.insurerAddress,
    required this.tier,
    required this.coverageLimitEth,
    required this.coveredHospitalAddresses,
    required this.coveredServices,
    required this.validFrom,
    required this.validUntil,
    this.usedAmountEth = 0,
  });

  double get remainingEth => coverageLimitEth - usedAmountEth;
  double get usagePercent => usedAmountEth / coverageLimitEth;
}
