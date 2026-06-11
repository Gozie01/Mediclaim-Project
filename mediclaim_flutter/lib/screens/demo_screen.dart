import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_theme.dart';
import '../constants/contracts.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';
import 'hospital_list_screen.dart';
import 'hospital_dashboard.dart';
import 'insurer_dashboard.dart';
import 'patient_dashboard.dart';

class DemoScreen extends StatefulWidget {
  final String patientAddress;
  const DemoScreen({super.key, required this.patientAddress});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _svc = MockDataService.instance;
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _stats = _svc.getSystemStats();
      _loading = false;
    });
  }

  String _truncate(String s, {int start = 10, int end = 6}) {
    if (s.length <= start + end + 3) return s;
    return '${s.substring(0, start)}...${s.substring(s.length - end)}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Demo & System Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Offline Demo Mode banner
            _buildOfflineBanner(),
            const SizedBox(height: 20),

            // 2. Stats grid
            _buildSectionHeader('System Statistics', Icons.bar_chart_outlined),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            else
              _buildStatsGrid(),
            const SizedBox(height: 24),

            // 3. Complete Demo Flow
            _buildSectionHeader(
                'Complete Demo Flow', Icons.play_circle_outlined),
            const SizedBox(height: 4),
            const Text(
              'Expand each step to walk through the full insurance claim lifecycle',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildDemoSteps(),
            const SizedBox(height: 24),

            // 4. Contract Addresses
            _buildSectionHeader(
                'Contract Addresses (PureChain)', Icons.code_outlined),
            const SizedBox(height: 12),
            _buildContractAddresses(),
            const SizedBox(height: 24),

            // 5. Pre-loaded Demo Data
            _buildSectionHeader(
                'Pre-loaded Demo Data', Icons.dataset_outlined),
            const SizedBox(height: 12),
            _buildPreloadedData(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Banner ───────────────────────────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Offline Demo Mode',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'No blockchain connection required. All data is simulated in-memory using MockDataService. '
                  'The full 5-step claim lifecycle runs locally so you can explore every screen without a PureChain node.',
                  style: TextStyle(
                    color: Color(0xFFFCD34D),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Stats grid ───────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final items = [
      _StatTile(
        label: 'Total Claims',
        value: '${_stats['total'] ?? 0}',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.primary,
      ),
      _StatTile(
        label: 'Pending',
        value: '${_stats['pending'] ?? 0}',
        icon: Icons.hourglass_empty_outlined,
        color: Colors.orange,
      ),
      _StatTile(
        label: 'Under Review',
        value: '${_stats['underReview'] ?? 0}',
        icon: Icons.search_outlined,
        color: Colors.blueAccent,
      ),
      _StatTile(
        label: 'Approved',
        value: '${_stats['approved'] ?? 0}',
        icon: Icons.check_circle_outlined,
        color: AppTheme.success,
      ),
      _StatTile(
        label: 'Paid',
        value: '${_stats['paid'] ?? 0}',
        icon: Icons.payments_outlined,
        color: const Color(0xFF34D399),
      ),
      _StatTile(
        label: 'Patients',
        value: '${_stats['patients'] ?? 0}',
        icon: Icons.person_outlined,
        color: const Color(0xFF818CF8),
      ),
      _StatTile(
        label: 'Hospitals',
        value: '${_stats['hospitals'] ?? 0}',
        icon: Icons.local_hospital_outlined,
        color: AppTheme.teal,
      ),
      _StatTile(
        label: 'Consents',
        value: '${_stats['consents'] ?? 0}',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFFA78BFA),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: items.map(_buildStatCard).toList(),
    );
  }

  Widget _buildStatCard(_StatTile item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Demo steps ───────────────────────────────────────────────────────────

  Widget _buildDemoSteps() {
    return Column(
      children: [
        _StepCard(
          stepNumber: 1,
          title: 'Register Patient',
          icon: Icons.person_add,
          color: AppTheme.indigo,
          description:
              'Patient enters name, DOB, blood type. Creates DID and FHIR profile on PureChain.',
          actionLabel: 'Go to Patient Dashboard',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientDashboard(
                  address: widget.patientAddress,
                ),
              ),
            );
          },
        ),
        _StepCard(
          stepNumber: 2,
          title: 'Grant Hospital Access',
          icon: Icons.lock_open,
          color: AppTheme.teal,
          description:
              'Patient selects hospital and role (Doctor/Nurse/etc), sets duration '
              '(1 hr / 1 day / permanent). Consent stored on-chain.',
          actionLabel: 'Find Hospitals',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalListScreen(
                  patientAddress: widget.patientAddress,
                ),
              ),
            );
          },
        ),
        _StepCard(
          stepNumber: 3,
          title: 'Hospital Submits Claim',
          icon: Icons.description,
          color: Colors.orange,
          description:
              'Hospital Admin fills claim: patient address, ICD code, CPT code, treatment summary, '
              'amount. Status: Pending Patient Approval.',
          actionLabel: 'Go to Hospital Dashboard',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalDashboard(
                  address: MockDataService.hospitalAAddress,
                ),
              ),
            );
          },
        ),
        _StepCard(
          stepNumber: 4,
          title: 'Patient Reviews Claim',
          icon: Icons.verified_user,
          color: AppTheme.success,
          description:
              'Patient sees pending claim. Reviews treatment details. Can APPROVE or REJECT with reasons: '
              'Overbilled, Underbilled, False Bill, Bill Without Treatment Completion.',
        ),
        _StepCard(
          stepNumber: 5,
          title: 'Oracle + Insurer Payment',
          icon: Icons.payment,
          color: AppTheme.violet,
          description:
              'After patient approval, oracle validates ICD/CPT codes (3-second auto in demo). '
              'Insurer pays approved claim. Hospital confirms receipt.',
          actionLabel: 'Insurer Dashboard',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InsurerDashboard(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Contract addresses ────────────────────────────────────────────────────

  Widget _buildContractAddresses() {
    final contracts = [
      _ContractEntry(
          name: 'ZKConsentVerifier',
          address: ContractAddresses.zkConsentVerifier),
      _ContractEntry(
          name: 'HospitalRegistry',
          address: ContractAddresses.hospitalRegistry),
      _ContractEntry(
          name: 'PatientProfile',
          address: ContractAddresses.patientProfile),
      _ContractEntry(
          name: 'MedicalRecord',
          address: ContractAddresses.medicalRecord),
      _ContractEntry(
          name: 'InsurancePolicy',
          address: ContractAddresses.insurancePolicy),
      _ContractEntry(
          name: 'MultiOracleConsensus',
          address: ContractAddresses.multiOracleConsensus),
      _ContractEntry(
          name: 'MediClaim',
          address: ContractAddresses.mediClaim),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: contracts.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, color: AppTheme.border),
              _buildContractRow(c),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContractRow(_ContractEntry c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.code, color: AppTheme.primary, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _truncate(c.address),
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
            onTap: () => _copyToClipboard(c.address, c.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.copy, color: AppTheme.primary, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Copy',
                    style:
                        TextStyle(color: AppTheme.primary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pre-loaded demo data ──────────────────────────────────────────────────

  Widget _buildPreloadedData() {
    final hospitals = _svc.getApprovedHospitals();
    final policies = _svc.getPatientPolicies(MockDataService.demoPatientAddress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hospitals sub-section
        const Text(
          'Hospitals',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: hospitals.asMap().entries.map((entry) {
              final i = entry.key;
              final h = entry.value;
              final labels = ['A', 'B', 'C', 'D'];
              final label = i < labels.length ? labels[i] : '${i + 1}';
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: AppTheme.border),
                  _buildHospitalRow(label, h),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Insurance plans sub-section
        const Text(
          'Insurance Plans',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: policies.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: AppTheme.border),
                  _buildPlanRow(p),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalRow(String label, HospitalModel h) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
                  h.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppTheme.textMuted, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      h.location,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: AppTheme.success,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRow(PolicyModel p) {
    final tierColors = {
      InsuranceTier.basic: Colors.blueGrey,
      InsuranceTier.medium: AppTheme.primary,
      InsuranceTier.premium: Colors.amber,
    };
    final tierLabels = {
      InsuranceTier.basic: 'Basic',
      InsuranceTier.medium: 'Medium',
      InsuranceTier.premium: 'Premium',
    };

    final color = tierColors[p.tier] ?? AppTheme.primary;
    final tierName = tierLabels[p.tier] ?? 'Plan';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shield_outlined, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tierName Plan',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Coverage: ${p.coverageLimitEth.toStringAsFixed(1)} ETH',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${p.coverageLimitEth.toStringAsFixed(0)} ETH',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StepCard ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Step $stepNumber',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          iconColor: color,
          collapsedIconColor: AppTheme.textMuted,
          children: [
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _StatTile {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _ContractEntry {
  final String name;
  final String address;

  const _ContractEntry({required this.name, required this.address});
}
