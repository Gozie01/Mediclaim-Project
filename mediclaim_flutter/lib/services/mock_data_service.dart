import '../models/models.dart';

// Shorthand hospital/personnel addresses
const String _hA = '0xAAAA0001AAAA0001AAAA0001AAAA0001AAAA0001';
const String _hB = '0xBBBB0002BBBB0002BBBB0002BBBB0002BBBB0002';
const String _hC = '0xCCCC0003CCCC0003CCCC0003CCCC0003CCCC0003';
const String _hD = '0xDDDD0004DDDD0004DDDD0004DDDD0004DDDD0004';
const String _p1 = '0x973B368ff10500168b81d744B4f35c6f42de91c2'; // demo patient/insurer
const String _drKim = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
const String _nurseP = '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC';
const String _billing = '0x90F79bf6EB2c4f870365E785982E1f101E93b906';
const String _insurer = '0xINSURER000000000000000000000000000000001';

class MockDataService {
  MockDataService._();
  static final MockDataService instance = MockDataService._().._seedData();

  final Map<String, PatientModel> _patients = {};
  final Map<String, HospitalModel> _hospitals = {};
  final Map<String, PersonnelModel> _personnel = {};
  final List<ConsentModel> _consents = [];
  final Map<String, ClaimModel> _claims = {};
  final Map<String, PolicyModel> _policies = {};
  int _claimCounter = 0;
  int _consentCounter = 0;

  void _seedData() {
    // ── Hospitals ──────────────────────────────────────────────────────────
    final now = DateTime.now();
    _hospitals[_hA] = HospitalModel(
      address: _hA,
      name: 'Seoul General Hospital',
      licenseNumber: 'SGL-001',
      location: 'Seoul, South Korea',
      specialties: 'Cardiology, Orthopedics, Emergency',
      approved: true, active: true,
      registeredAt: now.subtract(const Duration(days: 365)),
    );
    _hospitals[_hB] = HospitalModel(
      address: _hB,
      name: 'Kumoh University Hospital',
      licenseNumber: 'KUH-002',
      location: 'Gumi, North Gyeongsang',
      specialties: 'Internal Medicine, Neurology, Oncology',
      approved: true, active: true,
      registeredAt: now.subtract(const Duration(days: 300)),
    );
    _hospitals[_hC] = HospitalModel(
      address: _hC,
      name: 'Busan Medical Center',
      licenseNumber: 'BMC-003',
      location: 'Busan, South Korea',
      specialties: 'Pediatrics, Obstetrics, Dermatology',
      approved: true, active: true,
      registeredAt: now.subtract(const Duration(days: 200)),
    );
    _hospitals[_hD] = HospitalModel(
      address: _hD,
      name: 'Incheon International Clinic',
      licenseNumber: 'IIC-004',
      location: 'Incheon, South Korea',
      specialties: 'Emergency, Trauma, International Medicine',
      approved: true, active: true,
      registeredAt: now.subtract(const Duration(days: 100)),
    );

    // ── Personnel ──────────────────────────────────────────────────────────
    _personnel[_drKim] = PersonnelModel(address: _drKim, hospitalAddress: _hA, name: 'Dr. Kim Jun-seo', staffId: 'DOC-001', role: 0);
    _personnel[_nurseP] = PersonnelModel(address: _nurseP, hospitalAddress: _hA, name: 'Nurse Park Ji-yeon', staffId: 'NRS-001', role: 1);
    _personnel[_billing] = PersonnelModel(address: _billing, hospitalAddress: _hA, name: 'Mr. Lee Billing', staffId: 'BIL-001', role: 2);

    // ── Demo Patient (pre-registered so demo always works) ────────────────
    _patients[_p1] = PatientModel(
      address: _p1,
      name: 'Chigozie Nnadiekwe',
      dateOfBirth: '2000/10/14',
      bloodType: 'O+',
      did: 'did:purechain:973b368f',
      fhirId: 'FHIR-973B36',
      registered: true,
      registeredAt: now.subtract(const Duration(days: 30)),
    );

    // ── Insurance Policies (pre-linked to demo patient) ─────────────────
    _policies['0xBASIC001'] = PolicyModel(
      hash: '0xBASIC001',
      patientAddress: _p1,
      insurerAddress: _insurer,
      tier: InsuranceTier.basic,
      coverageLimitEth: 1.0,
      coveredHospitalAddresses: [_hA, _hB],
      coveredServices: [
        'Emergency Care',
        'Generic Medications',
        'Basic Lab Tests',
        'X-rays & Radiographs',
        'Outpatient Consultations',
        'Preventive Health Checks',
      ],
      validFrom: now.subtract(const Duration(days: 180)),
      validUntil: now.add(const Duration(days: 185)),
    );
    _policies['0xMEDIUM01'] = PolicyModel(
      hash: '0xMEDIUM01',
      patientAddress: _p1,
      insurerAddress: _insurer,
      tier: InsuranceTier.medium,
      coverageLimitEth: 5.0,
      coveredHospitalAddresses: [_hA, _hB, _hC],
      coveredServices: [
        'All Basic Plan Services',
        'Specialist Consultations',
        'Elective & Emergency Surgery',
        'MRI & CT Scans',
        'Prescription Drugs',
        'Physiotherapy (up to 20 sessions)',
        'Inpatient Care (up to 30 days/year)',
      ],
      validFrom: now.subtract(const Duration(days: 180)),
      validUntil: now.add(const Duration(days: 185)),
    );
    _policies['0xPREMIUM1'] = PolicyModel(
      hash: '0xPREMIUM1',
      patientAddress: _p1,
      insurerAddress: _insurer,
      tier: InsuranceTier.premium,
      coverageLimitEth: 20.0,
      coveredHospitalAddresses: [_hA, _hB, _hC, _hD],
      coveredServices: [
        'All Medium Plan Services',
        'International Treatment',
        'Dental Care (full coverage)',
        'Vision Care & Corrective Procedures',
        'Experimental / Clinical Trial Treatments',
        'Mental Health & Counseling',
        'Long-term / Chronic Care Management',
        'Ambulance Services',
        'Medical Evacuation',
      ],
      validFrom: now.subtract(const Duration(days: 180)),
      validUntil: now.add(const Duration(days: 185)),
    );
  }

  // ── Patients ──────────────────────────────────────────────────────────────
  bool isPatientRegistered(String address) => _patients.containsKey(address.toLowerCase()) || _patients.containsKey(address);

  PatientModel? getPatient(String address) => _patients[address] ?? _patients[address.toLowerCase()];

  void registerPatient({required String address, required String name, required String dob, required String bloodType}) {
    final did = 'did:purechain:${address.substring(2, 10).toLowerCase()}';
    final fhirId = 'FHIR-${address.substring(2, 8).toUpperCase()}';
    _patients[address] = PatientModel(
      address: address, name: name, dateOfBirth: dob, bloodType: bloodType,
      did: did, fhirId: fhirId, registered: true, registeredAt: DateTime.now(),
    );
  }

  // ── Hospitals ─────────────────────────────────────────────────────────────
  List<HospitalModel> getApprovedHospitals() =>
    _hospitals.values.where((h) => h.approved && h.active).toList();

  HospitalModel? getHospital(String address) => _hospitals[address];

  void registerHospital({required String address, required String name, required String licenseNumber, required String location, required String specialties}) {
    _hospitals[address] = HospitalModel(
      address: address, name: name, licenseNumber: licenseNumber,
      location: location, specialties: specialties,
      approved: false, active: true, registeredAt: DateTime.now(),
    );
  }

  // ── Personnel ─────────────────────────────────────────────────────────────
  PersonnelModel? getPersonnel(String address) => _personnel[address];

  List<PersonnelModel> getHospitalStaff(String hospitalAddress) =>
    _personnel.values.where((p) => p.hospitalAddress == hospitalAddress).toList();

  // ── Consents ──────────────────────────────────────────────────────────────
  List<ConsentModel> getPatientConsents(String patientAddress) =>
    _consents.where((c) => c.patientAddress == patientAddress && c.active && !c.isExpired).toList();

  List<ConsentModel> getAllPatientConsents(String patientAddress) =>
    _consents.where((c) => c.patientAddress == patientAddress).toList();

  void grantAccess({
    required String patientAddress,
    required String hospitalAddress,
    required int role,
    required bool readAccess,
    required bool writeAccess,
    required Duration? duration,
  }) {
    final hospital = _hospitals[hospitalAddress];
    final hospitalName = hospital?.name ?? hospitalAddress.substring(0, 14);
    // Remove existing consent for same patient+hospital+role
    _consents.removeWhere((c) =>
      c.patientAddress == patientAddress && c.hospitalAddress == hospitalAddress && c.role == role);
    _consentCounter++;
    _consents.add(ConsentModel(
      id: 'consent_$_consentCounter',
      patientAddress: patientAddress,
      hospitalAddress: hospitalAddress,
      hospitalName: hospitalName,
      role: role,
      readAccess: readAccess,
      writeAccess: writeAccess,
      grantedAt: DateTime.now(),
      expiresAt: duration != null ? DateTime.now().add(duration) : null,
    ));
  }

  void revokeConsent(String consentId) {
    final idx = _consents.indexWhere((c) => c.id == consentId);
    if (idx != -1) _consents[idx].active = false;
  }

  void revokeAllFromHospital(String patientAddress, String hospitalAddress) {
    for (final c in _consents) {
      if (c.patientAddress == patientAddress && c.hospitalAddress == hospitalAddress) {
        c.active = false;
      }
    }
  }

  // ── Claims ────────────────────────────────────────────────────────────────
  List<ClaimModel> getPatientClaims(String patientAddress) =>
    _claims.values.where((c) => c.patientAddress == patientAddress).toList()
      ..sort((a, b) => b.draftedAt.compareTo(a.draftedAt));

  List<ClaimModel> getPendingPatientApprovals(String patientAddress) =>
    _claims.values.where((c) => c.patientAddress == patientAddress && c.status == ClaimStatus.pendingPatient).toList();

  List<ClaimModel> getHospitalClaims(String hospitalAddress) =>
    _claims.values.where((c) => c.hospitalAddress == hospitalAddress).toList()
      ..sort((a, b) => b.draftedAt.compareTo(a.draftedAt));

  List<ClaimModel> getApprovedClaimsForInsurer() =>
    _claims.values.where((c) => c.status == ClaimStatus.approved || c.status == ClaimStatus.paid || c.status == ClaimStatus.paymentConfirmed).toList()
      ..sort((a, b) => b.draftedAt.compareTo(a.draftedAt));

  ClaimModel? getClaim(String id) => _claims[id];

  String draftClaim({
    required String patientAddress,
    required String hospitalAddress,
    required double amountEth,
    required String icdCode,
    required String cptCode,
    required String treatmentSummary,
  }) {
    _claimCounter++;
    final id = 'CLAIM-${_claimCounter.toString().padLeft(4, '0')}';
    final patient = _patients[patientAddress];
    final hospital = _hospitals[hospitalAddress];
    _claims[id] = ClaimModel(
      id: id,
      patientAddress: patientAddress,
      patientName: patient?.name ?? patientAddress.substring(0, 14),
      hospitalAddress: hospitalAddress,
      hospitalName: hospital?.name ?? 'Unknown Hospital',
      amountEth: amountEth,
      icdCode: icdCode,
      cptCode: cptCode,
      treatmentSummary: treatmentSummary,
      status: ClaimStatus.pendingPatient,
      draftedAt: DateTime.now(),
    );
    return id;
  }

  void approveClaimByPatient(String claimId) {
    final c = _claims[claimId];
    if (c == null) return;
    c.status = ClaimStatus.underReview;
    c.patientActionAt = DateTime.now();
    // Simulate oracle auto-approval after patient approves (for demo)
    Future.delayed(const Duration(seconds: 3), () {
      if (c.status == ClaimStatus.underReview) {
        c.status = ClaimStatus.approved;
        c.oracleActionAt = DateTime.now();
      }
    });
  }

  void rejectClaimByPatient(String claimId, String reason) {
    final c = _claims[claimId];
    if (c == null) return;
    c.status = ClaimStatus.patientRejected;
    c.patientActionAt = DateTime.now();
    c.patientRejectReason = reason;
  }

  void payClaim(String claimId) {
    final c = _claims[claimId];
    if (c == null) return;
    c.status = ClaimStatus.paid;
    c.paidAt = DateTime.now();
    // Update policy usage
    for (final p in _policies.values) {
      if (p.patientAddress == c.patientAddress) {
        p.usedAmountEth += c.amountEth;
        break;
      }
    }
  }

  void confirmPaymentReceipt(String claimId) {
    final c = _claims[claimId];
    if (c == null) return;
    c.status = ClaimStatus.paymentConfirmed;
    c.confirmedAt = DateTime.now();
  }

  // ── Consent queries for hospital & personnel views ───────────────────────

  /// All active consents at a hospital (used by Hospital Dashboard → Patients tab)
  List<ConsentModel> getActiveConsentsForHospital(String hospitalAddress) =>
    _consents.where((c) => c.hospitalAddress == hospitalAddress && c.active && !c.isExpired).toList();

  /// Unique patients who have granted ANY access to a hospital
  List<PatientModel> getPatientsWithAccessToHospital(String hospitalAddress) {
    final addresses = _consents
      .where((c) => c.hospitalAddress == hospitalAddress && c.active && !c.isExpired)
      .map((c) => c.patientAddress)
      .toSet();
    return addresses.map((a) => _patients[a]).whereType<PatientModel>().toList();
  }

  /// Active consents visible to a specific role at a hospital (used by Personnel → My Patients)
  List<ConsentModel> getConsentsForPersonnel(String hospitalAddress, int role) =>
    _consents.where((c) =>
      c.hospitalAddress == hospitalAddress && c.role == role && c.active && !c.isExpired
    ).toList();

  /// All registered patients (used by Insurer Dashboard)
  List<PatientModel> getAllRegisteredPatients() =>
    _patients.values.where((p) => p.registered).toList();

  /// All hospitals (approved or not — used by Insurer Dashboard)
  List<HospitalModel> getAllHospitals() => _hospitals.values.toList();

  // ── Policies ──────────────────────────────────────────────────────────────
  List<PolicyModel> getPatientPolicies(String patientAddress) =>
    _policies.values.where((p) => p.patientAddress == patientAddress).toList();

  bool isHospitalCoveredForPatient(String patientAddress, String hospitalAddress) {
    return _policies.values.any((p) =>
      p.patientAddress == patientAddress && p.coveredHospitalAddresses.contains(hospitalAddress));
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Map<String, int> getSystemStats() {
    final all = _claims.values.toList();
    return {
      'total': all.length,
      'pending': all.where((c) => c.status == ClaimStatus.pendingPatient).length,
      'underReview': all.where((c) => c.status == ClaimStatus.underReview).length,
      'approved': all.where((c) => c.status == ClaimStatus.approved).length,
      'paid': all.where((c) => c.status == ClaimStatus.paid || c.status == ClaimStatus.paymentConfirmed).length,
      'rejected': all.where((c) => c.status == ClaimStatus.patientRejected || c.status == ClaimStatus.rejected).length,
      'patients': _patients.length,
      'hospitals': _hospitals.length,
      'consents': _consents.where((c) => c.active).length,
    };
  }

  // ── Demo helpers ──────────────────────────────────────────────────────────
  static const String demoPatientAddress = _p1;
  static const String hospitalAAddress = _hA;
  static const String hospitalBAddress = _hB;
  static const String hospitalCAddress = _hC;
  static const String hospitalDAddress = _hD;
  static const String drKimAddress = _drKim;
  static const String nurseParkAddress = _nurseP;
  static const String billingAddress = _billing;
  static const String insurerAddress = _insurer;
}
