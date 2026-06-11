import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/mock_data_service.dart';
import 'patient_dashboard.dart';
import 'hospital_dashboard.dart';
import 'personnel_screen.dart';
import 'hospital_list_screen.dart';
import 'insurer_dashboard.dart';

class RoleSelectorScreen extends StatefulWidget {
  const RoleSelectorScreen({super.key});

  @override
  State<RoleSelectorScreen> createState() => _RoleSelectorScreenState();
}

class _RoleSelectorScreenState extends State<RoleSelectorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Returns the typed address if valid, otherwise returns [fallback].
  String _resolveAddress(String fallback) {
    final text = _addressController.text.trim();
    if (text.isNotEmpty && text.startsWith('0x') && text.length >= 40) {
      return text;
    }
    return fallback;
  }

  void _prefillAddress(String address) {
    setState(() => _addressController.text = address);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Address set: ${_truncate(address)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _truncate(String s, {int chars = 22}) {
    if (s.length <= chars) return s;
    return '${s.substring(0, 10)}...${s.substring(s.length - 6)}';
  }

  void _navigateTo(Widget screen) {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOfflineBanner(),
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAddressField(),
                const SizedBox(height: 12),
                _buildDemoAccountButtons(),
                const SizedBox(height: 24),
                _buildRoleGrid(),
                const SizedBox(height: 28),
                _buildFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Offline banner ──────────────────────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF08A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off, color: Color(0xFF713F12), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'OFFLINE DEMO MODE — not connected to blockchain',
              style: TextStyle(
                color: Color(0xFF713F12),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MediClaim Chain',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Patient-owned healthcare on PureChain',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ── Wallet address field ────────────────────────────────────────────────────

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Wallet Address',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '0x... (leave blank to use demo address)',
            prefixIcon: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final v = value.trim();
            if (!v.startsWith('0x') || v.length < 40) {
              return 'Enter a valid 0x address (at least 40 hex chars)';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Demo account quick-fill buttons ────────────────────────────────────────

  Widget _buildDemoAccountButtons() {
    final accounts = [
      _DemoAccount(
        label: 'Patient',
        address: MockDataService.demoPatientAddress,
        color: AppTheme.primary,
      ),
      _DemoAccount(
        label: 'Dr. Kim',
        address: MockDataService.drKimAddress,
        color: const Color(0xFF0F766E),
      ),
      _DemoAccount(
        label: 'Nurse Park',
        address: MockDataService.nurseParkAddress,
        color: const Color(0xFF8B5CF6),
      ),
      _DemoAccount(
        label: 'Billing',
        address: MockDataService.billingAddress,
        color: AppTheme.warning,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((a) => _buildDemoChip(a)).toList(),
    );
  }

  Widget _buildDemoChip(_DemoAccount account) {
    return GestureDetector(
      onTap: () => _prefillAddress(account.address),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: account.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: account.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, color: account.color, size: 14),
            const SizedBox(width: 5),
            Text(
              account.label,
              style: TextStyle(
                color: account.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Role grid ───────────────────────────────────────────────────────────────

  Widget _buildRoleGrid() {
    final roles = [
      _RoleCard(
        title: 'Patient',
        subtitle: 'View records & claims',
        icon: Icons.person,
        color: const Color(0xFF6366F1),
        onTap: () => _navigateTo(
          PatientDashboard(
            address: _resolveAddress(MockDataService.demoPatientAddress),
          ),
        ),
      ),
      _RoleCard(
        title: 'Hospital Admin',
        subtitle: 'Manage hospital & claims',
        icon: Icons.business,
        color: const Color(0xFF0F766E),
        onTap: () => _navigateTo(
          HospitalDashboard(
            address: _resolveAddress(MockDataService.hospitalAAddress),
          ),
        ),
      ),
      _RoleCard(
        title: 'Hospital Staff',
        subtitle: 'Access patient data',
        icon: Icons.medical_services,
        color: const Color(0xFF8B5CF6),
        onTap: () => _navigateTo(
          PersonnelScreen(
            address: _resolveAddress(MockDataService.drKimAddress),
          ),
        ),
      ),
      _RoleCard(
        title: 'Find Hospitals',
        subtitle: 'Grant access to hospital',
        icon: Icons.search,
        color: AppTheme.warning,
        onTap: () => _navigateTo(
          HospitalListScreen(
            patientAddress:
                _resolveAddress(MockDataService.demoPatientAddress),
          ),
        ),
      ),
      _RoleCard(
        title: 'Insurer',
        subtitle: 'Review & pay claims',
        icon: Icons.account_balance,
        color: const Color(0xFF0EA5E9),
        onTap: () => _navigateTo(const InsurerDashboard()),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: roles.map(_buildRoleCardWidget).toList(),
    );
  }

  Widget _buildRoleCardWidget(_RoleCard role) {
    return GestureDetector(
      onTap: role.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent bar
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: role.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: role.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(role.icon, color: role.color, size: 20),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.subtitle,
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Offline Demo — PureChain: 900520900520',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _RoleCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _DemoAccount {
  final String label;
  final String address;
  final Color color;

  const _DemoAccount({
    required this.label,
    required this.address,
    required this.color,
  });
}
