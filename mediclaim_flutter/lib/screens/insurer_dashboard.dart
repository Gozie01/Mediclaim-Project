import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';

class InsurerDashboard extends StatefulWidget {
  const InsurerDashboard({super.key});
  @override
  State<InsurerDashboard> createState() => _InsurerDashboardState();
}

class _InsurerDashboardState extends State<InsurerDashboard>
    with SingleTickerProviderStateMixin {
  final _svc = MockDataService.instance;

  late TabController _tabController;

  List<ClaimModel> _claims = [];
  List<PatientModel> _allPatients = [];
  List<HospitalModel> _allHospitals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _claims = _svc.getApprovedClaimsForInsurer();
      _allPatients = _svc.getAllRegisteredPatients();
      _allHospitals = _svc.getAllHospitals();
      _loading = false;
    });
  }

  Future<void> _payClaim(ClaimModel claim) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Confirm Payment',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Pay ${claim.amountEth.toStringAsFixed(4)} ETH to '
          '${claim.hospitalName}\n\nPatient: ${claim.patientName}'
          '\nClaim: ${claim.id}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _svc.payClaim(claim.id);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Payment of ${claim.amountEth.toStringAsFixed(4)} ETH sent to '
          '${claim.hospitalName}'),
      backgroundColor: AppTheme.success,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        title: const Text('Insurer Dashboard',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Claims'),
            Tab(
                icon: Icon(Icons.people_outline, size: 18),
                text: 'Patients'),
            Tab(
                icon: Icon(Icons.local_hospital_outlined, size: 18),
                text: 'Hospitals'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClaimsTab(),
                _buildPatientsTab(),
                _buildHospitalsTab(),
              ],
            ),
    );
  }

  // ── Claims Tab ───────────────────────────────────────────────────────────────

  Widget _buildClaimsTab() {
    final pendingPay =
        _claims.where((c) => c.status == ClaimStatus.approved).toList();
    final paid = _claims
        .where((c) =>
            c.status == ClaimStatus.paid ||
            c.status == ClaimStatus.paymentConfirmed)
        .toList();

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
            Row(children: [
              _statCard('Pending Pay', '${pendingPay.length}',
                  AppTheme.warning),
              const SizedBox(width: 8),
              _statCard('Total Paid', '${paid.length}', AppTheme.success),
              const SizedBox(width: 8),
              _statCard(
                  'All Claims', '${_claims.length}', AppTheme.primary),
            ]),
            const SizedBox(height: 20),
            if (pendingPay.isNotEmpty) ...[
              const Text('Awaiting Payment',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...pendingPay.map((c) => _claimCard(c, showPayButton: true)),
              const SizedBox(height: 20),
            ],
            if (paid.isNotEmpty) ...[
              const Text('Payment History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...paid.map((c) => _claimCard(c, showPayButton: false)),
            ],
            if (_claims.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const Icon(Icons.receipt_long_outlined,
                        color: AppTheme.textMuted, size: 60),
                    const SizedBox(height: 12),
                    const Text('No approved claims yet',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Claims appear here after patients approve them'
                      ' and oracle validates.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Patients Tab ─────────────────────────────────────────────────────────────

  Widget _buildPatientsTab() {
    if (_allPatients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                color: AppTheme.textMuted, size: 56),
            SizedBox(height: 12),
            Text('No registered patients',
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allPatients.length,
        itemBuilder: (_, i) => _buildPatientRow(_allPatients[i]),
      ),
    );
  }

  Widget _buildPatientRow(PatientModel p) {
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
                Text(p.did,
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chip('FHIR: ${p.fhirId}', AppTheme.teal),
                    const SizedBox(width: 6),
                    _chip(p.bloodType, AppTheme.warning),
                  ],
                ),
              ],
            ),
          ),
          _chip('Active', AppTheme.success),
        ],
      ),
    );
  }

  // ── Hospitals Tab ─────────────────────────────────────────────────────────────

  Widget _buildHospitalsTab() {
    if (_allHospitals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_outlined,
                color: AppTheme.textMuted, size: 56),
            SizedBox(height: 12),
            Text('No registered hospitals',
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allHospitals.length,
        itemBuilder: (_, i) => _buildHospitalRow(_allHospitals[i]),
      ),
    );
  }

  Widget _buildHospitalRow(HospitalModel h) {
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_hospital,
                color: AppTheme.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(h.location,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(h.specialties,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _chip(h.approved ? 'Approved' : 'Pending',
                  h.approved ? AppTheme.success : AppTheme.warning),
              const SizedBox(height: 4),
              _chip(h.licenseNumber, AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────────

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _claimCard(ClaimModel claim, {required bool showPayButton}) {
    final statusColor = Color(claim.status.color);
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
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(claim.id,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(claim.hospitalName,
                            style: const TextStyle(
                                color: AppTheme.primary, fontSize: 13)),
                      ]),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(claim.status.label,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
            const SizedBox(height: 10),
            Row(children: [
              _infoChip('Patient', claim.patientName),
              const SizedBox(width: 8),
              _infoChip('Amount',
                  '${claim.amountEth.toStringAsFixed(4)} ETH'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _infoChip('ICD', claim.icdCode),
              const SizedBox(width: 8),
              _infoChip('CPT', claim.cptCode),
            ]),
            const SizedBox(height: 8),
            Text(claim.treatmentSummary,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (claim.paidAt != null) ...[
              const SizedBox(height: 6),
              Text('Paid: ${_fmt(claim.paidAt!)}',
                  style: const TextStyle(
                      color: AppTheme.success, fontSize: 11)),
              if (claim.status == ClaimStatus.paymentConfirmed)
                const Text('✓ Hospital confirmed receipt',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
            ],
            if (showPayButton) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(
                      'Pay ${claim.amountEth.toStringAsFixed(4)} ETH'),
                  onPressed: () => _payClaim(claim),
                ),
              ),
            ],
          ]),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
