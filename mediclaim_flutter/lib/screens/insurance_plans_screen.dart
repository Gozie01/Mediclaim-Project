import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';

class InsurancePlansScreen extends StatefulWidget {
  final String patientAddress;
  const InsurancePlansScreen({super.key, required this.patientAddress});
  @override
  State<InsurancePlansScreen> createState() => _InsurancePlansScreenState();
}

class _InsurancePlansScreenState extends State<InsurancePlansScreen> {
  late List<PolicyModel> _policies;
  final _svc = MockDataService.instance;

  @override
  void initState() {
    super.initState();
    _policies = _svc.getPatientPolicies(widget.patientAddress);
  }

  @override
  Widget build(BuildContext context) {
    final allHospitals = _svc.getApprovedHospitals();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        title: const Text('Insurance Coverage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.shield, color: AppTheme.primary, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Insurance Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${_policies.length} active plan${_policies.length != 1 ? 's' : ''} registered on PureChain', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),

          if (_policies.isEmpty) ...[
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 60),
                SizedBox(height: 12),
                Text('No insurance plans found', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                SizedBox(height: 8),
                Text('Contact your insurer to register a policy.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
              ]),
            )),
          ] else ...[
            ...(_policies.map((policy) {
              final tierColor = Color(policy.tier.color);
              final coveredHospitals = allHospitals.where((h) => policy.coveredHospitalAddresses.contains(h.address)).toList();
              final pct = (policy.usagePercent * 100).clamp(0.0, 100.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: tierColor, width: 4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Tier header
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Text(policy.tier.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('${policy.tier.label} Plan', style: TextStyle(color: tierColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                            child: const Text('ACTIVE', style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        Text('Policy: ${policy.hash}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ])),
                    ]),
                  ),

                  // Coverage bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Coverage Used: ${policy.usedAmountEth.toStringAsFixed(3)} ETH', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('Limit: ${policy.coverageLimitEth.toStringAsFixed(1)} ETH', style: TextStyle(color: tierColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: policy.usagePercent.clamp(0.0, 1.0),
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation(pct > 80 ? AppTheme.error : tierColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Remaining: ${policy.remainingEth.toStringAsFixed(3)} ETH (${(100 - pct).toStringAsFixed(0)}%)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Services covered
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Covered Services', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: policy.coveredServices.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, color: tierColor, size: 12),
                            const SizedBox(width: 4),
                            Text(s, style: TextStyle(color: tierColor, fontSize: 11)),
                          ]),
                        )).toList(),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Covered hospitals
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Covered Hospitals (${coveredHospitals.length})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...coveredHospitals.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${h.location} · ${h.specialties}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Verified', style: TextStyle(color: AppTheme.success, fontSize: 10)),
                          ),
                        ]),
                      )),
                    ]),
                  ),

                  // Validity
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Valid From', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                          Text(_fmtDate(policy.validFrom), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('Valid Until', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                          Text(_fmtDate(policy.validUntil), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              );
            })),
          ],

          // Plan comparison table
          const SizedBox(height: 10),
          const Text('Plan Comparison', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _planComparisonTable(),
        ]),
      ),
    );
  }

  Widget _planComparisonTable() {
    final rows = [
      ['Coverage Limit', '1.0 ETH', '5.0 ETH', '20.0 ETH'],
      ['Hospitals Covered', '2 hospitals', '3 hospitals', '4 hospitals'],
      ['Emergency Care', '✓', '✓', '✓'],
      ['Generic Medications', '✓', '✓', '✓'],
      ['Specialist Visits', '✗', '✓', '✓'],
      ['Surgery', '✗', '✓', '✓'],
      ['MRI / CT Scans', '✗', '✓', '✓'],
      ['International Care', '✗', '✗', '✓'],
      ['Dental & Vision', '✗', '✗', '✓'],
      ['Mental Health', '✗', '✗', '✓'],
    ];

    return Container(
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            const Expanded(flex: 3, child: Padding(padding: EdgeInsets.all(10), child: Text('Feature', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)))),
            Expanded(flex: 2, child: Center(child: Padding(padding: const EdgeInsets.all(10), child: Text('🩺 Basic', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold))))),
            Expanded(flex: 2, child: Center(child: Padding(padding: const EdgeInsets.all(10), child: Text('🏥 Medium', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold))))),
            Expanded(flex: 2, child: Center(child: Padding(padding: const EdgeInsets.all(10), child: Text('👑 Premium', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold))))),
          ]),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key; final row = e.value;
          return Container(
            color: i.isOdd ? AppTheme.background.withValues(alpha: 0.5) : Colors.transparent,
            child: Row(children: [
              Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(10), child: Text(row[0], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)))),
              ...([row[1], row[2], row[3]].asMap().entries.map((ce) {
                final v = ce.value;
                final color = v == '✓' ? AppTheme.success : v == '✗' ? AppTheme.error : Colors.white;
                return Expanded(flex: 2, child: Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(v, style: TextStyle(color: color, fontSize: 12, fontWeight: v == '✓' || v == '✗' ? FontWeight.bold : FontWeight.normal)))));
              })),
            ]),
          );
        }),
      ]),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
}
