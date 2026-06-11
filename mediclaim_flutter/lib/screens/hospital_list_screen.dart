// COMPLETE FILE — do not truncate

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';

class HospitalListScreen extends StatefulWidget {
  final String patientAddress;
  const HospitalListScreen({super.key, required this.patientAddress});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  final _svc = MockDataService.instance;
  final _searchCtrl = TextEditingController();

  List<HospitalModel> _hospitals = [];
  List<HospitalModel> _filteredHospitals = [];
  List<ConsentModel> _patientConsents = [];
  bool _loading = true;

  // ── Role constants (matches PersonnelModel role ints) ─────────────────────
  static const List<Map<String, dynamic>> _roles = [
    {'label': 'Doctor',      'value': 0},
    {'label': 'Nurse',       'value': 1},
    {'label': 'Billing',     'value': 2},
    {'label': 'Pharmacist',  'value': 3},
    {'label': 'Radiologist', 'value': 4},
  ];

  static const List<Map<String, dynamic>> _durations = [
    {'label': '1 Hour',    'seconds': 3600},
    {'label': '1 Day',     'seconds': 86400},
    {'label': '1 Week',    'seconds': 604800},
    {'label': 'Permanent', 'seconds': 0},
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _onSearch(_searchCtrl.text));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _loading = true);
    final hospitals = _svc.getApprovedHospitals();
    final consents  = _svc.getPatientConsents(widget.patientAddress);
    setState(() {
      _hospitals         = hospitals;
      _filteredHospitals = hospitals;
      _patientConsents   = consents;
      _loading           = false;
    });
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredHospitals = _hospitals;
      } else {
        _filteredHospitals = _hospitals.where((h) {
          return h.name.toLowerCase().contains(query) ||
              h.location.toLowerCase().contains(query) ||
              h.specialties.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  bool _hasConsent(String hospitalAddress) =>
      _patientConsents.any((c) => c.hospitalAddress == hospitalAddress);

  List<ConsentModel> _getConsentsForHospital(String hospitalAddress) =>
      _patientConsents.where((c) => c.hospitalAddress == hospitalAddress).toList();

  /// Returns the highest-tier PolicyModel that covers this hospital, or null.
  PolicyModel? _coveringPolicy(String hospitalAddress) {
    final policies = _svc.getPatientPolicies(widget.patientAddress);
    // Sort premium → medium → basic and return first match
    final sorted = [...policies]
      ..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    try {
      return sorted.firstWhere(
        (p) => p.coveredHospitalAddresses.contains(hospitalAddress),
      );
    } catch (_) {
      return null;
    }
  }

  String _roleLabel(int role) {
    const labels = ['Doctor', 'Nurse', 'Billing', 'Pharmacist', 'Radiologist'];
    if (role >= 0 && role < labels.length) return labels[role];
    return 'Role $role';
  }

  // ── Grant Access bottom sheet ─────────────────────────────────────────────
  void _grantAccess(HospitalModel hospital) {
    int selectedRole     = 0; // Doctor
    int selectedDuration = 1; // index into _durations → 1 Day
    bool readAccess      = true;
    bool writeAccess     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final currentRole = _roles[selectedRole];
          final isDoctor    = currentRole['value'] == 0;

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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grant Access',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hospital.name,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Role selector
                  _sheetLabel('Staff Role'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_roles.length, (i) {
                      final selected = selectedRole == i;
                      return GestureDetector(
                        onTap: () => setSheet(() {
                          selectedRole = i;
                          // Write access only for Doctor
                          if (_roles[i]['value'] != 0) writeAccess = false;
                        }),
                        child: _pillChip(
                          label: _roles[i]['label'] as String,
                          selected: selected,
                          selectedColor: AppTheme.primary,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Duration selector
                  _sheetLabel('Access Duration'),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(_durations.length, (i) {
                      final selected = selectedDuration == i;
                      // ignore: deprecated_member_use
                      return RadioListTile<int>(
                        value: i,
                        // ignore: deprecated_member_use
                        groupValue: selectedDuration,
                        // ignore: deprecated_member_use
                        onChanged: (v) => setSheet(() => selectedDuration = v!),
                        // ignore: deprecated_member_use
                        activeColor: AppTheme.success,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          _durations[i]['label'] as String,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Access toggles
                  _sheetLabel('Permissions'),
                  const SizedBox(height: 8),
                  _accessToggleRow(
                    label: 'Read Access',
                    subtitle: 'View patient records',
                    value: readAccess,
                    onChanged: (v) => setSheet(() => readAccess = v),
                    activeColor: AppTheme.success,
                  ),
                  if (isDoctor)
                    _accessToggleRow(
                      label: 'Write Access',
                      subtitle: 'Create / update records',
                      value: writeAccess,
                      onChanged: (v) => setSheet(() => writeAccess = v),
                      activeColor: AppTheme.warning,
                    ),
                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final durationSecs =
                            _durations[selectedDuration]['seconds'] as int;
                        final Duration? dur = durationSecs == 0
                            ? null
                            : Duration(seconds: durationSecs);
                        final roleValue =
                            _roles[selectedRole]['value'] as int;
                        final roleLabel =
                            _roles[selectedRole]['label'] as String;
                        final durationLabel =
                            _durations[selectedDuration]['label'] as String;

                        _svc.grantAccess(
                          patientAddress: widget.patientAddress,
                          hospitalAddress: hospital.address,
                          role: roleValue,
                          readAccess: readAccess,
                          writeAccess: writeAccess,
                          duration: dur,
                        );
                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Access granted to ${hospital.name} for $roleLabel — $durationLabel',
                            ),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      },
                      icon: const Icon(Icons.key_rounded, size: 17),
                      label: const Text('Grant Access'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Revoke All confirmation dialog ────────────────────────────────────────
  void _revokeAll(HospitalModel hospital) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Revoke All Access?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'All active access grants to ${hospital.name} will be revoked immediately.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc.revokeAllFromHospital(
                  widget.patientAddress, hospital.address);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All access revoked from ${hospital.name}'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Find Hospitals',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textSecondary),
            onPressed: () {},
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextFormField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by name, location, specialty…',
                prefixIcon:
                    Icon(Icons.search, color: AppTheme.textMuted, size: 20),
              ),
            ),
          ),
          // Count row
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_filteredHospitals.length} hospital${_filteredHospitals.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Body
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_filteredHospitals.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_hospital_outlined,
                        color: AppTheme.textMuted, size: 52),
                    const SizedBox(height: 14),
                    Text(
                      _searchCtrl.text.isEmpty
                          ? 'No approved hospitals on PureChain'
                          : 'No hospitals match "${_searchCtrl.text}"',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _load(),
                color: AppTheme.primary,
                backgroundColor: AppTheme.card,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredHospitals.length,
                  itemBuilder: (ctx, i) =>
                      _buildHospitalCard(_filteredHospitals[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hospital card ─────────────────────────────────────────────────────────
  Widget _buildHospitalCard(HospitalModel hospital) {
    final hasConsent  = _hasConsent(hospital.address);
    final consents    = _getConsentsForHospital(hospital.address);
    final policy      = _coveringPolicy(hospital.address);
    final isCovered   = policy != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasConsent
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.border,
          width: hasConsent ? 1.5 : 1,
        ),
        boxShadow: hasConsent
            ? [
                BoxShadow(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar — teal for all approved hospitals
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Name + Approved badge ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hospital icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF0F766E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Color(0xFF0F766E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospital.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined,
                                  color: AppTheme.textMuted, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'License: ${hospital.licenseNumber}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Approved badge
                    _statusBadge(
                      icon: Icons.verified_rounded,
                      label: 'Approved',
                      color: AppTheme.success,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Location ───────────────────────────────────────────────
                _infoRow(
                  icon: Icons.location_on_rounded,
                  iconColor: AppTheme.error.withValues(alpha: 0.8),
                  text: hospital.location,
                  textColor: AppTheme.textSecondary,
                ),
                const SizedBox(height: 6),

                // ── Specialties ────────────────────────────────────────────
                _infoRow(
                  icon: Icons.medical_services_rounded,
                  iconColor: AppTheme.warning,
                  text: hospital.specialties,
                  textColor: AppTheme.warning,
                ),
                const SizedBox(height: 12),

                // ── Coverage band ──────────────────────────────────────────
                _buildCoverageBand(hospital.address, isCovered, policy),
                const SizedBox(height: 12),

                // ── Consent section ────────────────────────────────────────
                if (hasConsent) ...[
                  _buildConsentSection(consents),
                  const SizedBox(height: 12),
                ],

                // ── Divider ────────────────────────────────────────────────
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),

                // ── Action buttons ─────────────────────────────────────────
                _buildActionButtons(hospital, hasConsent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Coverage band widget ──────────────────────────────────────────────────
  Widget _buildCoverageBand(
    String hospitalAddress,
    bool isCovered,
    PolicyModel? policy,
  ) {
    if (!isCovered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: const [
            Icon(Icons.shield_outlined, color: AppTheme.error, size: 15),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not covered by your current insurance policies',
                style: TextStyle(
                  color: AppTheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tier      = policy!.tier;
    final tierColor = Color(tier.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tierColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: tierColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${tier.emoji}  ${tier.label} Plan',
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'COVERED',
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Up to ${policy.coverageLimitEth.toStringAsFixed(1)} ETH  •  '
                  '${policy.remainingEth.toStringAsFixed(2)} ETH remaining',
                  style: TextStyle(
                    color: tierColor.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Consent section widget ────────────────────────────────────────────────
  Widget _buildConsentSection(List<ConsentModel> consents) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_open_rounded,
                  color: AppTheme.success, size: 14),
              SizedBox(width: 6),
              Text(
                'Access Granted',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...consents.map((c) => _buildConsentRow(c)),
        ],
      ),
    );
  }

  Widget _buildConsentRow(ConsentModel c) {
    final perms = <String>[];
    if (c.readAccess) perms.add('Read');
    if (c.writeAccess) perms.add('Write');
    final permStr = perms.join(' + ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_roleLabel(c.role)}${permStr.isNotEmpty ? '  ·  $permStr' : ''}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: c.expiresAt == null
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : AppTheme.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              c.expiryText,
              style: TextStyle(
                color: c.expiresAt == null
                    ? AppTheme.primary
                    : AppTheme.warning,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons(HospitalModel hospital, bool hasConsent) {
    if (!hasConsent) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _grantAccess(hospital),
          icon: const Icon(Icons.key_rounded, size: 16),
          label: const Text('Grant Access'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _grantAccess(hospital),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Grant More'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _revokeAll(hospital),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Revoke All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Small helper widgets ──────────────────────────────────────────────────

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );

  Widget _pillChip({
    required String label,
    required bool selected,
    required Color selectedColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? selectedColor.withValues(alpha: 0.14)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? selectedColor : AppTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? selectedColor : AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _accessToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          // ignore: deprecated_member_use
          activeColor: activeColor,
          inactiveThumbColor: AppTheme.textMuted,
          inactiveTrackColor: AppTheme.border,
        ),
      ],
    );
  }

  Widget _statusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
