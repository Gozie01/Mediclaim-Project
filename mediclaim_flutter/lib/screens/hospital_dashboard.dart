// COMPLETE FILE — do not truncate
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';

class HospitalDashboard extends StatefulWidget {
  final String address;
  const HospitalDashboard({super.key, required this.address});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard>
    with SingleTickerProviderStateMixin {
  final MockDataService _svc = MockDataService.instance;

  HospitalModel? _hospital;
  List<ClaimModel> _claims = [];
  List<PatientModel> _patients = [];
  bool _loading = true;

  late TabController _tabController;

  // Registration form controllers
  final _regNameCtrl = TextEditingController();
  final _regLicenseCtrl = TextEditingController();
  final _regLocationCtrl = TextEditingController();
  final _regSpecialtiesCtrl = TextEditingController();
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameCtrl.dispose();
    _regLicenseCtrl.dispose();
    _regLocationCtrl.dispose();
    _regSpecialtiesCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ────────────────────────────────────────────────────────────

  void _load() {
    setState(() => _loading = true);

    HospitalModel? found = _svc.getHospital(widget.address);

    if (found == null) {
      // Check if address is the demo patient — map to Hospital A for demo
      if (widget.address == MockDataService.demoPatientAddress) {
        found = _svc.getHospital(MockDataService.hospitalAAddress);
      }
    }

    final hospitalAddress = found?.address ?? '';
    final claims =
        hospitalAddress.isNotEmpty ? _svc.getHospitalClaims(hospitalAddress) : <ClaimModel>[];

    final patients = hospitalAddress.isNotEmpty
        ? _svc.getPatientsWithAccessToHospital(hospitalAddress)
        : <PatientModel>[];

    setState(() {
      _hospital = found;
      _claims = claims;
      _patients = patients;
      _loading = false;
    });
  }

  // ── Draft Claim ─────────────────────────────────────────────────────────────

  void _draftClaim() {
    final patientCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0.15');
    final icdCtrl = TextEditingController(text: 'J18.9 — Pneumonia');
    final cptCtrl = TextEditingController(text: '99213 — Office Visit');
    final summaryCtrl = TextEditingController(
      text:
          'Patient presented with fever and cough. Diagnosed with community-acquired pneumonia.',
    );

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Draft New Claim',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              patientCtrl.dispose();
                              amountCtrl.dispose();
                              icdCtrl.dispose();
                              cptCtrl.dispose();
                              summaryCtrl.dispose();
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.close,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Submit a medical claim on behalf of a registered patient.',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Patient Address field + demo helper
                      _sheetLabel('Patient Address'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: patientCtrl,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontFamily: 'monospace'),
                              decoration: const InputDecoration(
                                hintText: '0x...',
                                fillColor: AppTheme.background,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Patient address required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                patientCtrl.text =
                                    MockDataService.demoPatientAddress;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 14),
                              side: const BorderSide(
                                  color: AppTheme.primary),
                            ),
                            child: const Text('Demo',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Amount
                      _sheetLabel('Amount (ETH)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '0.15',
                          prefixIcon:
                              Icon(Icons.toll_outlined, size: 18),
                          fillColor: AppTheme.background,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Amount required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ICD Code
                      _sheetLabel('ICD Code'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: icdCtrl,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'e.g. J18.9 — Pneumonia',
                          fillColor: AppTheme.background,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'ICD code required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      _icdSuggestions(icdCtrl, setSheetState),
                      const SizedBox(height: 12),

                      // CPT Code
                      _sheetLabel('CPT Code'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: cptCtrl,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 99213 — Office Visit',
                          fillColor: AppTheme.background,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'CPT code required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Treatment Summary
                      _sheetLabel('Treatment Summary'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: summaryCtrl,
                        maxLines: 3,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Brief description of treatment...',
                          fillColor: AppTheme.background,
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Treatment summary required'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;

                            final patientAddress = patientCtrl.text.trim();
                            final amount = double.tryParse(
                                    amountCtrl.text.trim()) ??
                                0.15;
                            final icd = icdCtrl.text.trim();
                            final cpt = cptCtrl.text.trim();
                            final summary = summaryCtrl.text.trim();
                            final hospitalAddress =
                                _hospital!.address;

                            // Check patient registration
                            if (!_svc.isPatientRegistered(patientAddress)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Patient address not registered. '
                                    'Register patient first.',
                                  ),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                              return;
                            }

                            final claimId = _svc.draftClaim(
                              patientAddress: patientAddress,
                              hospitalAddress: hospitalAddress,
                              amountEth: amount,
                              icdCode: icd,
                              cptCode: cpt,
                              treatmentSummary: summary,
                            );

                            patientCtrl.dispose();
                            amountCtrl.dispose();
                            icdCtrl.dispose();
                            cptCtrl.dispose();
                            summaryCtrl.dispose();

                            Navigator.pop(ctx);
                            _load();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Claim $claimId submitted. '
                                  'Patient will be notified.',
                                ),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          },
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Submit Claim'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _icdSuggestions(
      TextEditingController ctrl, StateSetter setSheetState) {
    const suggestions = [
      'J18.9 — Pneumonia',
      'I10 — Hypertension',
      'E11.9 — Type 2 Diabetes',
      'M54.5 — Low Back Pain',
      'J06.9 — Upper Respiratory Infection',
      'K21.0 — GERD',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: suggestions.map((s) {
        return ActionChip(
          label: Text(s, style: const TextStyle(fontSize: 10)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onPressed: () => setSheetState(() => ctrl.text = s),
          backgroundColor: AppTheme.background,
          side: const BorderSide(color: AppTheme.border),
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
        );
      }).toList(),
    );
  }

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500),
      );

  // ── Confirm Payment Receipt ─────────────────────────────────────────────────

  void _confirmPaymentReceipt(ClaimModel claim) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Confirm Payment Receipt',
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim: ${claim.id}',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Amount: ${claim.amountEth.toStringAsFixed(4)} ETH',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Confirm that payment has been received from the insurer for this claim?',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _svc.confirmPaymentReceipt(claim.id);
              Navigator.pop(ctx);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment receipt confirmed'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ── Registration ────────────────────────────────────────────────────────────

  void _registerHospital() async {
    if (_regNameCtrl.text.trim().isEmpty ||
        _regLicenseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and license number are required.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _registering = true);
    await Future.delayed(const Duration(milliseconds: 600));
    _svc.registerHospital(
      address: widget.address,
      name: _regNameCtrl.text.trim(),
      licenseNumber: _regLicenseCtrl.text.trim(),
      location: _regLocationCtrl.text.trim().isEmpty
          ? 'Not specified'
          : _regLocationCtrl.text.trim(),
      specialties: _regSpecialtiesCtrl.text.trim().isEmpty
          ? 'General Medicine'
          : _regSpecialtiesCtrl.text.trim(),
    );
    setState(() => _registering = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Hospital registered. Awaiting admin approval.'),
        backgroundColor: AppTheme.success,
      ),
    );
    _load();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _truncate(String s, {int start = 10, int end = 6}) {
    if (s.length <= start + end + 3) return s;
    return '${s.substring(0, start)}...${s.substring(s.length - end)}';
  }

  Color _statusColor(ClaimStatus status) =>
      Color(status.color);

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _roleLabel(int role) {
    const roles = [
      'Doctor',
      'Nurse',
      'Billing',
      'Pharmacist',
      'Radiologist',
      'Admin',
      'Lab Tech',
      'Receptionist',
    ];
    if (role >= 0 && role < roles.length) return roles[role];
    return 'Staff';
  }

  Color _roleColor(int role) {
    const colors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.warning,
      Color(0xFF06B6D4),
      Color(0xFF8B5CF6),
      AppTheme.teal,
      Color(0xFFF97316),
      AppTheme.textSecondary,
    ];
    if (role >= 0 && role < colors.length) return colors[role];
    return AppTheme.textMuted;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hospital Dashboard'),
        bottom: _hospital != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Claims'),
                  Tab(text: 'Patients'),
                  Tab(text: 'Staff'),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton:
          _hospital != null && _tabController.index == 1
              ? FloatingActionButton.extended(
                  onPressed: _draftClaim,
                  icon: const Icon(Icons.add),
                  label: const Text('Draft New Claim'),
                  backgroundColor: AppTheme.primary,
                )
              : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _hospital == null
              ? _buildNotRegistered()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildClaimsTab(),
                    _buildPatientsTab(),
                    _buildStaffTab(),
                  ],
                ),
    );
  }

  // ── Not Registered View ─────────────────────────────────────────────────────

  Widget _buildNotRegistered() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hospital Not Registered',
                        style: TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _truncate(widget.address),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Address copied')),
                    );
                  },
                  child: const Icon(Icons.copy,
                      color: AppTheme.textMuted, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Registration Form
          const Text(
            'Register Hospital',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fill in hospital details. The registration will be pending admin approval.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _formField(_regNameCtrl, 'Hospital Name *',
              'e.g. Seoul General Hospital'),
          const SizedBox(height: 14),
          _formField(_regLicenseCtrl, 'License Number *',
              'e.g. SGL-001'),
          const SizedBox(height: 14),
          _formField(_regLocationCtrl, 'Location',
              'City, Country'),
          const SizedBox(height: 14),
          _formField(_regSpecialtiesCtrl, 'Specialties',
              'e.g. Cardiology, Emergency'),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _registering ? null : _registerHospital,
              icon: _registering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.local_hospital_outlined, size: 18),
              label: Text(
                  _registering ? 'Registering...' : 'Register Hospital'),
            ),
          ),
          const SizedBox(height: 32),

          // Demo quick-fill hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo Tip',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use one of the 4 pre-registered hospital addresses from the role selector to see the full dashboard.',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                _demoHospitalChip('Hospital A (Seoul General)',
                    MockDataService.hospitalAAddress),
                const SizedBox(height: 6),
                _demoHospitalChip('Hospital B (Kumoh University)',
                    MockDataService.hospitalBAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoHospitalChip(String label, String address) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label address copied')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_hospital,
                color: AppTheme.primary, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _truncate(address),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, color: AppTheme.textMuted, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppTheme.background,
          ),
        ),
      ],
    );
  }

  // ── Overview Tab ────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final h = _hospital!;
    final total = _claims.length;
    final pending = _claims
        .where((c) =>
            c.status == ClaimStatus.pendingPatient ||
            c.status == ClaimStatus.underReview)
        .length;
    final paid = _claims
        .where((c) =>
            c.status == ClaimStatus.paid ||
            c.status == ClaimStatus.paymentConfirmed)
        .length;

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHospitalInfoCard(h),
            const SizedBox(height: 16),
            _buildStatsRow(total, pending, paid),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalInfoCard(HospitalModel h) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital,
                    color: AppTheme.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (h.approved)
                          _badge('Approved', AppTheme.success)
                        else
                          _badge('Pending Approval', AppTheme.warning),
                        if (h.active)
                          _badge('Active', AppTheme.primary)
                        else
                          _badge('Inactive', AppTheme.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _infoRow(Icons.badge_outlined, 'License', h.licenseNumber),
          const SizedBox(height: 8),
          _infoRow(Icons.location_on_outlined, 'Location', h.location),
          const SizedBox(height: 8),
          _infoRow(Icons.medical_services_outlined, 'Specialties',
              h.specialties),
          const SizedBox(height: 8),
          _infoRow(Icons.account_balance_wallet_outlined, 'Address',
              _truncate(h.address)),
          const SizedBox(height: 8),
          _infoRow(
            Icons.calendar_today_outlined,
            'Registered',
            '${h.registeredAt.day}/${h.registeredAt.month}/${h.registeredAt.year}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int pending, int paid) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Total',
            '$total',
            Icons.receipt_long_outlined,
            AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Pending',
            '$pending',
            Icons.pending_outlined,
            AppTheme.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Paid',
            '$paid',
            Icons.check_circle_outlined,
            AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionTile(
                icon: Icons.add_box_outlined,
                color: AppTheme.primary,
                label: 'Draft Claim',
                onTap: () {
                  _tabController.animateTo(1);
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    _draftClaim,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionTile(
                icon: Icons.people_outline,
                color: AppTheme.teal,
                label: 'View Staff',
                onTap: () => _tabController.animateTo(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Claims Tab ──────────────────────────────────────────────────────────────

  Widget _buildClaimsTab() {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: _claims.isEmpty
          ? _buildEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No claims yet',
              sub: 'Tap "Draft New Claim" to submit a claim',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _claims.length,
              itemBuilder: (_, i) => _buildClaimCard(_claims[i]),
            ),
    );
  }

  Widget _buildClaimCard(ClaimModel claim) {
    final color = _statusColor(claim.status);
    final isPaid = claim.status == ClaimStatus.paid;
    final isConfirmed = claim.status == ClaimStatus.paymentConfirmed;
    final isRejected = claim.status == ClaimStatus.patientRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: claim ID + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    claim.id,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              _badge(claim.status.label, color),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Patient
          _claimRow(
            Icons.person_outline,
            'Patient',
            '${claim.patientName}  (${_truncate(claim.patientAddress)})',
          ),
          const SizedBox(height: 6),

          // Amount + ICD
          Row(
            children: [
              Expanded(
                child: _claimRow(
                  Icons.toll_outlined,
                  'Amount',
                  '${claim.amountEth.toStringAsFixed(4)} ETH',
                ),
              ),
              Expanded(
                child: _claimRow(
                  Icons.medical_services_outlined,
                  'ICD',
                  claim.icdCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // CPT
          _claimRow(
              Icons.fact_check_outlined, 'CPT', claim.cptCode),
          const SizedBox(height: 6),

          // Treatment summary
          if (claim.treatmentSummary.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined,
                    color: AppTheme.textMuted, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    claim.treatmentSummary,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Rejection reason
          if (isRejected &&
              claim.patientRejectReason != null &&
              claim.patientRejectReason!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.block,
                      color: AppTheme.error, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${claim.patientRejectReason}',
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Footer: time + action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drafted ${_timeAgo(claim.draftedAt)}',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
              if (isPaid)
                ElevatedButton.icon(
                  onPressed: () =>
                      _confirmPaymentReceipt(claim),
                  icon: const Icon(Icons.verified_outlined,
                      size: 14),
                  label: const Text('Confirm Receipt',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else if (isConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: AppTheme.success, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Payment Confirmed',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _claimRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 13),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Patients Tab ────────────────────────────────────────────────────────────

  Widget _buildPatientsTab() {
    if (_patients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        message: 'No patients yet',
        sub: 'Patients who grant access to this hospital appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        itemBuilder: (_, i) => _buildPatientCard(_patients[i]),
      ),
    );
  }

  Widget _buildPatientCard(PatientModel p) {
    final consents = _svc
        .getActiveConsentsForHospital(_hospital!.address)
        .where((c) => c.patientAddress == p.address)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _truncate(p.address),
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              _badge('Registered', AppTheme.success),
            ],
          ),
          if (consents.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text('Granted Access',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: consents.map((c) {
                final rc = _roleColor(c.role);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rc.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_roleLabel(c.role),
                          style: TextStyle(
                              color: rc,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 5),
                      if (c.readAccess)
                        Text('R',
                            style: TextStyle(
                                color:
                                    AppTheme.success.withValues(alpha: 0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      if (c.writeAccess)
                        Text('W',
                            style: TextStyle(
                                color:
                                    AppTheme.warning.withValues(alpha: 0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Text(c.expiryText,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Staff Tab ───────────────────────────────────────────────────────────────

  Widget _buildStaffTab() {
    final staff = _svc.getHospitalStaff(_hospital!.address);
    if (staff.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        message: 'No staff registered',
        sub: 'Staff can be added by the hospital admin',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      itemBuilder: (_, i) => _buildStaffCard(staff[i]),
    );
  }

  Widget _buildStaffCard(PersonnelModel p) {
    final roleColor = _roleColor(p.role);
    final roleLabel = _roleLabel(p.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: roleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(roleLabel, roleColor),
                    const SizedBox(width: 6),
                    Text(
                      p.staffId,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _truncate(p.address),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: p.address));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${p.name} address copied')),
              );
            },
            child: const Icon(Icons.copy,
                color: AppTheme.textMuted, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? sub,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
