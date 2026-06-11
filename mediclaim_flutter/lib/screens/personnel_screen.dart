// COMPLETE FILE — do not truncate
import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/models.dart';
import '../services/mock_data_service.dart';

// ─── Access matrix ───────────────────────────────────────────────────────────
// Category indices:
//   0=Demographics  1=Medical History  2=Lab Results   3=Prescriptions
//   4=Imaging       5=Vitals           6=Nursing Notes  7=Billing Info
//   8=Treatment Notes

const _roleReadAccess = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8], // 0 Doctor
  [0, 5, 6],                    // 1 Nurse
  [0, 7],                       // 2 Billing Staff
  [0, 3],                       // 3 Pharmacist
  [0, 1, 4],                    // 4 Radiologist
  [0],                          // 5 Admin
  [0, 1, 2],                    // 6 Lab Tech
  [0],                          // 7 Receptionist
];

const _roleWriteAccess = [
  [1, 2, 3, 4, 8], // 0 Doctor
  [5, 6],          // 1 Nurse
  [7],             // 2 Billing Staff
  [3],             // 3 Pharmacist
  [4],             // 4 Radiologist
  [0],             // 5 Admin
  [2],             // 6 Lab Tech
  <int>[],         // 7 Receptionist
];

// ─── Role meta ────────────────────────────────────────────────────────────────
const _roleNames = [
  'Doctor',
  'Nurse',
  'Billing Staff',
  'Pharmacist',
  'Radiologist',
  'Admin',
  'Lab Tech',
  'Receptionist',
];

const _roleIcons = [
  Icons.local_hospital,
  Icons.healing,
  Icons.attach_money,
  Icons.medication,
  Icons.biotech,
  Icons.admin_panel_settings,
  Icons.science,
  Icons.desktop_windows,
];

const _roleColors = [
  Colors.indigo,
  Colors.teal,
  Colors.amber,
  Colors.purple,
  Colors.cyan,
  Colors.grey,
  Colors.lime,
  Colors.orange,
];

// ─── Category meta ────────────────────────────────────────────────────────────
const _catNames = [
  'Demographics',
  'Medical History',
  'Lab Results',
  'Prescriptions',
  'Imaging',
  'Vitals',
  'Nursing Notes',
  'Billing Info',
  'Treatment Notes',
];

const _catIcons = [
  Icons.person,
  Icons.history,
  Icons.science,
  Icons.medication,
  Icons.image,
  Icons.favorite,
  Icons.edit_note,
  Icons.credit_card,
  Icons.medical_services,
];

// ─────────────────────────────────────────────────────────────────────────────

class PersonnelScreen extends StatefulWidget {
  final String address;
  const PersonnelScreen({super.key, required this.address});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  final _svc = MockDataService.instance;

  PersonnelModel? _personnel;
  HospitalModel? _hospital;
  bool _loading = true;

  final _patientCtrl = TextEditingController();
  List<ConsentModel> _myPatientConsents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _patientCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _personnel = _svc.getPersonnel(widget.address);
    if (_personnel != null) {
      _hospital = _svc.getHospital(_personnel!.hospitalAddress);
      _myPatientConsents = _svc.getConsentsForPersonnel(
        _personnel!.hospitalAddress, _personnel!.role);
      // Pre-fill patient field with first consenting patient
      if (_myPatientConsents.isNotEmpty && _patientCtrl.text.isEmpty) {
        _patientCtrl.text = _myPatientConsents.first.patientAddress;
      }
    }
    setState(() => _loading = false);
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  String _truncate(String s, {int start = 10, int end = 6}) {
    if (s.length <= start + end + 3) return s;
    return '${s.substring(0, start)}...${s.substring(s.length - end)}';
  }

  Color _roleColor(int role) {
    if (role < 0 || role >= _roleColors.length) return Colors.grey.shade400;
    return _roleColors[role].shade400;
  }

  IconData _roleIcon(int role) {
    if (role < 0 || role >= _roleIcons.length) return Icons.badge;
    return _roleIcons[role];
  }

  String _roleName(int role) {
    if (role < 0 || role >= _roleNames.length) return 'Staff';
    return _roleNames[role];
  }

  bool _canRead(int role, int catIndex) {
    if (role < 0 || role >= _roleReadAccess.length) return false;
    return _roleReadAccess[role].contains(catIndex);
  }

  bool _canWrite(int role, int catIndex) {
    if (role < 0 || role >= _roleWriteAccess.length) return false;
    return _roleWriteAccess[role].contains(catIndex);
  }

  // ─── Not-found view ───────────────────────────────────────────────────────

  void _showStaffDialog(String staffAddress) {
    final p = _svc.getPersonnel(staffAddress);
    if (p == null) return;
    final h = _svc.getHospital(p.hospitalAddress);
    final color = _roleColor(p.role);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(_roleIcon(p.role), color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('Role', _roleName(p.role)),
            _dialogRow('Staff ID', p.staffId),
            _dialogRow('Address', _truncate(p.address)),
            if (h != null) ...[
              _dialogRow('Hospital', h.name),
              _dialogRow('Location', h.location),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Not registered card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_off, color: AppTheme.error, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Not a registered staff member',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    widget.address,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hint card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline,
                        color: AppTheme.warning, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Demo Tip',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This address is not registered as hospital personnel.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Use Dr. Kim's address:",
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    MockDataService.drKimAddress,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Demo Staff Members',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _demoStaffButton(
            'Dr. Kim Jun-seo',
            'Doctor — Seoul General Hospital',
            MockDataService.drKimAddress,
            Icons.local_hospital,
            Colors.indigo.shade400,
          ),
          const SizedBox(height: 8),
          _demoStaffButton(
            'Nurse Park Ji-yeon',
            'Nurse — Seoul General Hospital',
            MockDataService.nurseParkAddress,
            Icons.healing,
            Colors.teal.shade400,
          ),
          const SizedBox(height: 8),
          _demoStaffButton(
            'Mr. Lee Billing',
            'Billing Staff — Seoul General Hospital',
            MockDataService.billingAddress,
            Icons.attach_money,
            Colors.amber.shade600,
          ),
        ],
      ),
    );
  }

  Widget _demoStaffButton(
    String name,
    String subtitle,
    String address,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      onTap: () => _showStaffDialog(address),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Personnel found view ─────────────────────────────────────────────────

  Widget _buildRoleBadgeCard() {
    final p = _personnel!;
    final color = _roleColor(p.role);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_roleIcon(p.role), color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _roleName(p.role),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Staff ID: ${p.staffId}',
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

  Widget _buildHospitalCard() {
    final h = _hospital;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
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
                  h?.name ?? 'Unknown Hospital',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (h != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    h.location,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'License: ${h.licenseNumber}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (h != null && h.approved)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: AppTheme.success, size: 12),
                  SizedBox(width: 3),
                  Text(
                    'Approved',
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
    );
  }

  Widget _buildAccessGrid() {
    final role = _personnel!.role;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Access Permissions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9,
          ),
          itemCount: 9,
          itemBuilder: (_, i) => _buildCatCard(i, role),
        ),
      ],
    );
  }

  Widget _buildCatCard(int catIndex, int role) {
    final canRead = _canRead(role, catIndex);
    final canWrite = _canWrite(role, catIndex);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canRead
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _catIcons[catIndex],
            color: canRead ? AppTheme.textPrimary : AppTheme.textMuted,
            size: 22,
          ),
          const SizedBox(height: 5),
          Text(
            _catNames[catIndex],
            style: TextStyle(
              color:
                  canRead ? AppTheme.textSecondary : AppTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          if (canRead)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _accessBadge(
                  'Read',
                  AppTheme.success,
                ),
                if (canWrite) ...[
                  const SizedBox(width: 3),
                  _accessBadge('Write', AppTheme.violet),
                ],
              ],
            )
          else
            _accessBadge('No Access', AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _accessBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── My Patients section ──────────────────────────────────────────────────

  Color _expiryColor(ConsentModel c) {
    if (c.expiresAt == null) return AppTheme.success;
    final diff = c.expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return AppTheme.error;
    if (diff.inHours < 24) return AppTheme.warning;
    return AppTheme.success;
  }

  String _fmt(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
    '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  Widget _buildMyPatientsSection() {
    final role = _personnel!.role;
    final roleColor = _roleColor(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Patients Who Granted Me Access',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_myPatientConsents.length} active',
                style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_myPatientConsents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(children: [
              Icon(Icons.person_off_outlined, color: AppTheme.textMuted, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('No patients have granted access to your role yet.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13))),
            ]),
          )
        else
          ..._myPatientConsents.map((c) {
            final patient = _svc.getPatient(c.patientAddress);
            final patName = patient?.name ?? '${c.patientAddress.substring(0, 10)}...';
            final expColor = _expiryColor(c);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(patName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_truncate(c.patientAddress), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ])),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  if (c.readAccess) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.success.withValues(alpha: 0.3))),
                    child: const Text('Read', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  if (c.writeAccess) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.violet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.violet.withValues(alpha: 0.3))),
                    child: const Text('Write', style: TextStyle(color: AppTheme.violet, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.schedule, color: expColor, size: 13),
                  const SizedBox(width: 4),
                  Text(c.expiryText, style: TextStyle(color: expColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text('Granted: ${_fmt(c.grantedAt)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
            );
          }),
      ],
    );
  }

  // ─── Check Access card ────────────────────────────────────────────────────

  Widget _buildCheckAccessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search,
                  color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Access Patient Record',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _patientCtrl,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: '0x patient address',
              prefixIcon: Icon(Icons.person_search,
                  color: AppTheme.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _patientCtrl.text = MockDataService.demoPatientAddress;
              });
            },
            icon: const Icon(Icons.auto_fix_high, size: 14),
            label: const Text('Use Demo Patient',
                style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkAccess,
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('Check Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkAccess() {
    final addr = _patientCtrl.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a patient address')),
      );
      return;
    }

    final patient = _svc.getPatient(addr);
    final role = _personnel!.role;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Access Check Result',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: patient == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cancel,
                      color: AppTheme.error, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Patient not registered or no consent granted',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _truncate(addr),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              )
            : _buildAccessGrantedContent(role, patient),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessGrantedContent(int role, PatientModel patient) {
    final readableCategories = <int>[];
    if (role >= 0 && role < _roleReadAccess.length) {
      readableCategories.addAll(_roleReadAccess[role]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppTheme.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                patient.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Access granted by patient consent',
          style: TextStyle(
              color: AppTheme.success, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Text(
          'Readable categories:',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...readableCategories.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check,
                    color: AppTheme.success, size: 14),
                const SizedBox(width: 6),
                Icon(_catIcons[i],
                    color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  _catNames[i],
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (readableCategories.isEmpty)
          const Text(
            'No category access for this role.',
            style: TextStyle(
                color: AppTheme.textMuted, fontSize: 12),
          ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hospital Staff Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _personnel == null
              ? _buildNotFound()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRoleBadgeCard(),
                      const SizedBox(height: 14),
                      _buildHospitalCard(),
                      const SizedBox(height: 20),
                      _buildAccessGrid(),
                      const SizedBox(height: 20),
                      _buildMyPatientsSection(),
                      const SizedBox(height: 20),
                      _buildCheckAccessCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
