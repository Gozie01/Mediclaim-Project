// COMPLETE FILE — do not truncate

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';
import 'insurance_plans_screen.dart';

const List<String> _roleNames = [
  'Doctor',
  'Nurse',
  'Billing',
  'Pharmacist',
  'Radiologist',
  'Admin',
  'Lab Tech',
  'Receptionist',
];

class PatientDashboard extends StatefulWidget {
  final String address;
  const PatientDashboard({super.key, required this.address});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final MockDataService _svc = MockDataService.instance;

  PatientModel? _patient;
  List<ClaimModel> _claims = [];
  List<ConsentModel> _consents = [];
  List<PolicyModel> _policies = [];
  List<HospitalModel> _allHospitals = [];
  List<HospitalModel> _filteredHospitals = [];
  bool _loading = true;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _bloodTypeCtrl = TextEditingController();
  final TextEditingController _hospitalSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hospitalSearchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _bloodTypeCtrl.dispose();
    _hospitalSearchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _patient = _svc.getPatient(widget.address);
      _claims = _svc.getPatientClaims(widget.address);
      _consents = _svc.getPatientConsents(widget.address);
      _policies = _svc.getPatientPolicies(widget.address);
      _allHospitals = _svc.getAllHospitals();
      final q = _hospitalSearchCtrl.text.trim().toLowerCase();
      _filteredHospitals = q.isEmpty
          ? List.from(_allHospitals)
          : _allHospitals
              .where((h) =>
                  h.name.toLowerCase().contains(q) ||
                  h.location.toLowerCase().contains(q) ||
                  h.specialties.toLowerCase().contains(q))
              .toList();
      _loading = false;
    });
  }

  void _register() {
    if (_nameCtrl.text.trim().isEmpty || _dobCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and date of birth are required.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    _svc.registerPatient(
      address: widget.address,
      name: _nameCtrl.text.trim(),
      dob: _dobCtrl.text.trim(),
      bloodType: _bloodTypeCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _bloodTypeCtrl.text.trim(),
    );
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient registered on PureChain (demo)'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _approveClaim(ClaimModel claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Claim',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('Amount', '${claim.amountEth.toStringAsFixed(4)} ETH'),
            _dialogRow('Hospital', claim.hospitalName),
            _dialogRow('ICD Code', claim.icdCode),
            const SizedBox(height: 8),
            const Text('Summary',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(claim.treatmentSummary,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _svc.approveClaimByPatient(claim.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Claim approved. Under oracle review. Auto-approves in 3 seconds.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _rejectClaim(ClaimModel claim) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final reasons = [
          'Overbilled — Amount too high',
          'Underbilled — Incorrect low amount',
          'False Bill — Treatment not received',
          'Bill Without Treatment Completion',
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.cancel_outlined,
                      color: AppTheme.error, size: 22),
                  const SizedBox(width: 10),
                  const Text('Reject Claim',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Select a reason for rejection',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      _svc.rejectClaimByPatient(claim.id, reason);
                      Navigator.pop(ctx);
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Claim rejected: $reason'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    },
                    child: Text(reason,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _revokeConsent(ConsentModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke Access',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
            'Revoke ${_roleName(c.role)} access from ${c.hospitalName}?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _svc.revokeConsent(c.id);
      _load();
    }
  }

  Future<void> _revokeAllFromHospital(
      String hospitalAddress, String hospitalName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke All Access',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Revoke ALL access from $hospitalName?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _svc.revokeAllFromHospital(widget.address, hospitalAddress);
      _load();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _roleName(int role) {
    if (role < 0 || role >= _roleNames.length) return 'Role $role';
    return _roleNames[role];
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                if (copyable)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.copy,
                          size: 14, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ClaimStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color(status.color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(status.color).withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: Color(status.color),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Hospital search / grant access helpers ─────────────────────────────────

  void _onSearchChanged() {
    final q = _hospitalSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredHospitals = q.isEmpty
          ? List.from(_allHospitals)
          : _allHospitals
              .where((h) =>
                  h.name.toLowerCase().contains(q) ||
                  h.location.toLowerCase().contains(q) ||
                  h.specialties.toLowerCase().contains(q))
              .toList();
    });
  }

  (String, String) _hospitalCoverage(String hospitalAddress) {
    for (final p in _policies) {
      if (p.coveredHospitalAddresses.contains(hospitalAddress)) {
        return (p.tier.emoji, p.tier.label);
      }
    }
    return ('', '');
  }

  List<ConsentModel> _consentsForHospital(String hospitalAddress) {
    return _consents
        .where((c) => c.hospitalAddress == hospitalAddress && !c.isExpired)
        .toList();
  }

  void _openGrantAccessSheet(HospitalModel hospital) {
    int selectedRole = 0;
    String selectedDuration = 'Permanent';
    bool readAccess = true;
    bool writeAccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            const roles = [
              'Doctor', 'Nurse', 'Billing', 'Pharmacist',
              'Radiologist', 'Admin', 'Lab Tech', 'Receptionist',
            ];
            const durations = ['1 Hour', '1 Day', '1 Week', 'Permanent'];
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Grant Access — ${hospital.name}',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close,
                                color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Select Role',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(roles.length, (i) {
                        final sel = selectedRole == i;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedRole = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primary.withValues(alpha: 0.2)
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? AppTheme.primary
                                      : AppTheme.border),
                            ),
                            child: Text(roles[i],
                                style: TextStyle(
                                    color: sel
                                        ? AppTheme.primary
                                        : AppTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Duration',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: durations.map((d) {
                        final sel = selectedDuration == d;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedDuration = d),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                        .withValues(alpha: 0.15)
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: sel
                                        ? AppTheme.primary
                                        : AppTheme.border),
                              ),
                              child: Text(d,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: sel
                                          ? AppTheme.primary
                                          : AppTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Switch(
                                value: readAccess,
                                onChanged: (v) =>
                                    setSheetState(() => readAccess = v),
                                activeThumbColor: AppTheme.success,
                              ),
                              const Text('Read',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Switch(
                                value: writeAccess,
                                onChanged: (v) =>
                                    setSheetState(() => writeAccess = v),
                                activeThumbColor: AppTheme.warning,
                              ),
                              const Text('Write',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          const roleNames = [
                            'Doctor', 'Nurse', 'Billing', 'Pharmacist',
                            'Radiologist', 'Admin', 'Lab Tech', 'Receptionist',
                          ];
                          Duration? duration;
                          if (selectedDuration != 'Permanent') {
                            duration = selectedDuration == '1 Hour'
                                ? const Duration(hours: 1)
                                : selectedDuration == '1 Day'
                                    ? const Duration(days: 1)
                                    : const Duration(days: 7);
                          }
                          _svc.grantAccess(
                            patientAddress: widget.address,
                            hospitalAddress: hospital.address,
                            role: selectedRole,
                            duration: duration,
                            readAccess: readAccess,
                            writeAccess: writeAccess,
                          );
                          Navigator.pop(ctx);
                          _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Access granted to ${hospital.name}'
                                ' (${roleNames[selectedRole]}, $selectedDuration)',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_open_outlined, size: 18),
                        label: const Text('Grant Access'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 2: Hospitals ────────────────────────────────────────────────────────

  Widget _buildHospitalsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _hospitalSearchCtrl,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search hospitals...',
              prefixIcon: const Icon(Icons.search,
                  color: AppTheme.textMuted, size: 20),
              suffixIcon: _hospitalSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.textMuted, size: 18),
                      onPressed: () {
                        setState(() => _hospitalSearchCtrl.clear());
                      },
                    )
                  : null,
              fillColor: AppTheme.background,
            ),
          ),
        ),
        Expanded(
          child: _filteredHospitals.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          color: AppTheme.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('No hospitals found',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _filteredHospitals.length,
                  itemBuilder: (_, i) =>
                      _buildHospitalCard(_filteredHospitals[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildHospitalCard(HospitalModel h) {
    final coverage = _hospitalCoverage(h.address);
    final consents = _consentsForHospital(h.address);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_hospital,
                    color: AppTheme.teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(h.location,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (coverage.$1.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${coverage.$1} ${coverage.$2}',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (h.specialties.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(h.specialties,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
          if (consents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: consents.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_roleName(c.role)} • ${c.expiryText}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGrantAccessSheet(h),
                  icon: const Icon(Icons.lock_open_outlined, size: 14),
                  label: const Text('Grant Access',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (consents.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _revokeAllFromHospital(h.address, h.name),
                  icon: const Icon(Icons.block, size: 14),
                  label: const Text('Revoke All',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Registration Form ──────────────────────────────────────────────────────

  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This wallet is not yet registered as a patient on PureChain.',
                    style: TextStyle(
                        color: AppTheme.warning.withValues(alpha: 0.9),
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Register as Patient',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Your data is stored securely on PureChain.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _dobCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth * (YYYY-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined,
                        color: AppTheme.textMuted),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bloodTypeCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Blood Type (e.g. A+)',
                    prefixIcon: Icon(Icons.bloodtype_outlined,
                        color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                  label: const Text('Register on PureChain'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.address,
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                  child: const Icon(Icons.copy,
                      size: 14, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Profile ─────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final p = _patient!;
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Address / identity card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  AppTheme.violet.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_circle_outlined,
                          color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Registered',
                                style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.address,
                        style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.address));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied')),
                        );
                      },
                      child: const Icon(Icons.copy,
                          size: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Profile details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Patient Profile',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 12),
                _infoRow('Full Name', p.name),
                _infoRow('DID', p.did, copyable: true),
                _infoRow('FHIR ID', p.fhirId, copyable: true),
                _infoRow('Blood Type', p.bloodType),
                _infoRow('Date of Birth', p.dateOfBirth),
                _infoRow(
                  'Registered',
                  '${p.registeredAt.year}-'
                  '${p.registeredAt.month.toString().padLeft(2, '0')}-'
                  '${p.registeredAt.day.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _statCard('Claims', _claims.length.toString(),
                  Icons.receipt_long_outlined, AppTheme.primary),
              const SizedBox(width: 10),
              _statCard('Consents', _consents.length.toString(),
                  Icons.lock_open_outlined, AppTheme.success),
              const SizedBox(width: 10),
              _statCard('Policies', _policies.length.toString(),
                  Icons.policy_outlined, AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Claims ──────────────────────────────────────────────────────────

  Widget _buildClaimsTab() {
    if (_claims.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppTheme.primary,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      color: AppTheme.textMuted.withValues(alpha: 0.4), size: 56),
                  const SizedBox(height: 14),
                  const Text('No claims yet',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                      'Claims submitted by hospitals will appear here.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length,
        itemBuilder: (ctx, i) => _buildClaimCard(_claims[i]),
      ),
    );
  }

  Widget _buildClaimCard(ClaimModel claim) {
    final isPendingPatient = claim.status == ClaimStatus.pendingPatient;
    final isPatientRejected = claim.status == ClaimStatus.patientRejected;
    final isUnderReview = claim.status == ClaimStatus.underReview;
    final isApproved = claim.status == ClaimStatus.approved;
    final isPaidOrConfirmed = claim.status == ClaimStatus.paid ||
        claim.status == ClaimStatus.paymentConfirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPendingPatient
              ? AppTheme.warning.withValues(alpha: 0.5)
              : AppTheme.border,
          width: isPendingPatient ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(claim.id,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                      const SizedBox(height: 2),
                      Text(claim.hospitalName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _statusChip(claim.status),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _claimDetailChip(
                        Icons.currency_exchange,
                        '${claim.amountEth.toStringAsFixed(4)} ETH',
                        AppTheme.success),
                    _claimDetailChip(
                        Icons.medical_information_outlined,
                        'ICD: ${claim.icdCode}',
                        AppTheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  claim.treatmentSummary,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action area
          if (isPendingPatient) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveClaim(claim),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectClaim(claim),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isPatientRejected &&
              claim.patientRejectReason != null) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 15),
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
          ] else if (isUnderReview) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3B82F6)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Under Oracle Review',
                            style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isApproved) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.success, size: 14),
                        SizedBox(width: 6),
                        Text('Approved — Awaiting Payment',
                            style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isPaidOrConfirmed) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.paid_outlined,
                            color: Color(0xFF6366F1), size: 14),
                        const SizedBox(width: 6),
                        Text(
                            'Paid — ${claim.amountEth.toStringAsFixed(4)} ETH',
                            style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _claimDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Tab 2: Access / Consents ───────────────────────────────────────────────

  Widget _buildAccessTab() {
    if (_consents.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppTheme.primary,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.lock_outlined,
                      color: AppTheme.textMuted.withValues(alpha: 0.4), size: 56),
                  const SizedBox(height: 14),
                  const Text('No active access grants',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                      'When hospitals are granted access, they appear here.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Group consents by hospital
    final Map<String, List<ConsentModel>> grouped = {};
    for (final c in _consents) {
      grouped.putIfAbsent(c.hospitalAddress, () => []).add(c);
    }

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: grouped.entries.map((entry) {
          final hospitalAddr = entry.key;
          final hospitalConsents = entry.value;
          final hospitalName = hospitalConsents.first.hospitalName;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_hospital_outlined,
                            color: AppTheme.teal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hospitalName,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${hospitalConsents.length} active role'
                              '${hospitalConsents.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _revokeAllFromHospital(
                            hospitalAddr, hospitalName),
                        icon: const Icon(Icons.block, size: 14),
                        label: const Text('Revoke All',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.border),
                // Consent rows
                ...hospitalConsents.map((c) => _buildConsentRow(c)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConsentRow(ConsentModel c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_roleName(c.role),
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (c.readAccess) _accessBadge('R', AppTheme.success),
                    if (c.readAccess && c.writeAccess)
                      const SizedBox(width: 4),
                    if (c.writeAccess) _accessBadge('W', AppTheme.warning),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  c.expiryText,
                  style: TextStyle(
                    color: c.isExpired
                        ? AppTheme.error
                        : c.expiresAt == null
                            ? AppTheme.textMuted
                            : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _revokeConsent(c),
            child: const Text('Revoke',
                style: TextStyle(color: AppTheme.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _accessBadge(String letter, Color color) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(letter,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    );
  }

  // ── Tab 3: Insurance ──────────────────────────────────────────────────────

  Widget _buildInsuranceTab() {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Explore plans button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InsurancePlansScreen(patientAddress: widget.address),
                ),
              );
            },
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Explore Insurance Plans'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          if (_policies.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.policy_outlined,
                      color: AppTheme.textMuted.withValues(alpha: 0.4), size: 56),
                  const SizedBox(height: 14),
                  const Text('No active policies',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                      'Your insurance policies will appear here.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ] else ...[
            const Text('Your Policies',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._policies.map((policy) => _buildPolicyCard(policy)),
          ],
        ],
      ),
    );
  }

  Widget _buildPolicyCard(PolicyModel policy) {
    final tierColor = Color(policy.tier.color);
    final usagePct = policy.usagePercent.clamp(0.0, 1.0);
    final isExpired = DateTime.now().isAfter(policy.validUntil);
    final daysLeft = policy.validUntil.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? AppTheme.error.withValues(alpha: 0.4)
              : tierColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Text(policy.tier.emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${policy.tier.label} Plan',
                          style: TextStyle(
                              color: tierColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text(policy.hash,
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? AppTheme.error.withValues(alpha: 0.15)
                        : AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'Expired' : 'Active',
                    style: TextStyle(
                        color: isExpired
                            ? AppTheme.error
                            : AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          // Coverage details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Usage bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Coverage Used',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Text(
                      '${policy.usedAmountEth.toStringAsFixed(3)} / '
                      '${policy.coverageLimitEth.toStringAsFixed(3)} ETH',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: usagePct,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usagePct > 0.8
                          ? AppTheme.error
                          : usagePct > 0.5
                              ? AppTheme.warning
                              : AppTheme.success,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    'Remaining: ${policy.remainingEth.toStringAsFixed(3)} ETH',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppTheme.textMuted, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      isExpired
                          ? 'Expired'
                          : 'Expires in $daysLeft day'
                              '${daysLeft == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: isExpired
                              ? AppTheme.error
                              : AppTheme.textSecondary,
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),
                const Text('Covered Services',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: policy.coveredServices
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: tierColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  color: tierColor.withValues(alpha: 0.9),
                                  fontSize: 11)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),
                const Text('Covered Hospitals',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '${policy.coveredHospitalAddresses.length} hospital'
                  '${policy.coveredHospitalAddresses.length == 1 ? '' : 's'} covered',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Patient Dashboard'),
          backgroundColor: AppTheme.card,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final isRegistered = _patient?.registered == true;

    if (!isRegistered) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Patient Dashboard'),
          backgroundColor: AppTheme.card,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildRegistrationForm(),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Patient Dashboard'),
          backgroundColor: AppTheme.card,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            tabs: [
              Tab(
                  icon: Icon(Icons.person_outline, size: 18),
                  text: 'Profile'),
              Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Claims'),
              Tab(
                  icon: Icon(Icons.local_hospital_outlined, size: 18),
                  text: 'Hospitals'),
              Tab(
                  icon: Icon(Icons.lock_open_outlined, size: 18),
                  text: 'Access'),
              Tab(
                  icon: Icon(Icons.policy_outlined, size: 18),
                  text: 'Insurance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildClaimsTab(),
            _buildHospitalsTab(),
            _buildAccessTab(),
            _buildInsuranceTab(),
          ],
        ),
      ),
    );
  }
}
