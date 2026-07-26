import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _actionMeta = {
  'first_aid':      {'label': 'First Aid Given',    'icon': Icons.healing_rounded},
  'medication':     {'label': 'Medication Given',   'icon': Icons.medication_rounded},
  'parent_called':  {'label': 'Parent Called',      'icon': Icons.phone_rounded},
  'sent_home':      {'label': 'Sent Home',           'icon': Icons.home_rounded},
  'sent_to_hospital':{'label': 'Sent to Hospital',  'icon': Icons.local_hospital_rounded},
  'other':          {'label': 'Other',               'icon': Icons.more_horiz_rounded},
};

// ── List screen ───────────────────────────────────────────────────────────────

class HealthIncidentsScreen extends StatefulWidget {
  const HealthIncidentsScreen({super.key});

  @override
  State<HealthIncidentsScreen> createState() => _HealthIncidentsScreenState();
}

class _HealthIncidentsScreenState extends State<HealthIncidentsScreen> {
  List<Map<String, dynamic>> _incidents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.listHealthIncidents();
      if (mounted) setState(() { _incidents = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Incidents'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final logged = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const _LogIncidentScreen()),
          );
          if (logged == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Incident'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _incidents.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🏥', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No incidents recorded', style: TextStyle(fontSize: 16, color: AppColors.muted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _incidents.length,
                        itemBuilder: (ctx, i) => _IncidentCard(incident: _incidents[i]),
                      ),
                    ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final actions = (incident['actions'] as List?)?.cast<String>() ?? [];
    final hasMedication = actions.contains('medication');
    final sentHome = actions.contains('sent_home');
    final sentHospital = actions.contains('sent_to_hospital');
    final isSerious = sentHospital;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSerious ? const Color(0xFFFCA5A5) : AppColors.border,
          width: isSerious ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident['student_name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                  ),
                ),
                if (incident['class_label'] != null && (incident['class_label'] as String).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      incident['class_label'] as String,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              incident['description'] as String? ?? '',
              style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: actions.map((a) {
                final meta = _actionMeta[a];
                final label = meta?['label'] as String? ?? a;
                final icon = meta?['icon'] as IconData? ?? Icons.circle;
                final isAlert = a == 'sent_to_hospital';
                return _ActionChip(label: label, icon: icon, alert: isAlert);
              }).toList(),
            ),
            if (hasMedication && incident['medication_name'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.medication_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(incident['medication_name'] as String, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  if (incident['medication_consent'] == true) ...[
                    const SizedBox(width: 6),
                    const Text('• Consent obtained', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                  ],
                ],
              ),
            ],
            if ((sentHome || sentHospital) && incident['pickup_person_name'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Picked up by ${incident['pickup_person_name']}${incident['pickup_person_relation'] != null ? ' (${incident['pickup_person_relation']})' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  _formatDate(incident['occurred_at'] as String?),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const Spacer(),
                Text(
                  'by ${incident['reported_by_name'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) { return iso; }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool alert;
  const _ActionChip({required this.label, required this.icon, this.alert = false});

  @override
  Widget build(BuildContext context) {
    final bg = alert ? const Color(0xFFFEE2E2) : AppColors.bg;
    final fg = alert ? const Color(0xFFDC2626) : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: alert ? const Color(0xFFFCA5A5) : AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

// ── Log incident form ─────────────────────────────────────────────────────────

class _LogIncidentScreen extends StatefulWidget {
  const _LogIncidentScreen();

  @override
  State<_LogIncidentScreen> createState() => _LogIncidentScreenState();
}

class _LogIncidentScreenState extends State<_LogIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _medNameCtrl = TextEditingController();
  final _pickupNameCtrl = TextEditingController();
  final _pickupRelCtrl = TextEditingController();
  final _pickupPhoneCtrl = TextEditingController();

  // Student selection
  List<SectionInfo> _sections = [];
  SectionInfo? _selectedSection;
  List<AttendanceStudent> _sectionStudents = [];
  AttendanceStudent? _selectedStudent;
  bool _loadingStudents = false;

  // Form state
  DateTime _occurredAt = DateTime.now();
  final Set<String> _selectedActions = {};
  bool _medicationConsent = false;
  String? _pickupType; // parent | attender | emergency
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _attenders = [];
  Map<String, dynamic>? _selectedPickupPerson;
  DateTime? _pickupTime;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _medNameCtrl.dispose();
    _pickupNameCtrl.dispose();
    _pickupRelCtrl.dispose();
    _pickupPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final sections = await ApiClient.getMySections();
      if (mounted) setState(() => _sections = sections);
    } catch (_) {}
  }

  Future<void> _onSectionChanged(SectionInfo? s) async {
    setState(() {
      _selectedSection = s;
      _selectedStudent = null;
      _sectionStudents = [];
    });
    if (s == null) return;
    setState(() => _loadingStudents = true);
    try {
      final students = await ApiClient.getAttendance(s.id, _today());
      if (mounted) setState(() { _sectionStudents = students; _loadingStudents = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _onStudentChanged(AttendanceStudent? student) async {
    setState(() {
      _selectedStudent = student;
      _parents = [];
      _attenders = [];
      _selectedPickupPerson = null;
      _pickupType = null;
    });
  }

  Future<void> _loadPickupPersons() async {
    if (_selectedStudent == null) return;
    try {
      final data = await ApiClient.getPickupPersons(_selectedStudent!.id);
      if (mounted) {
        setState(() {
          _parents = (data['parents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _attenders = (data['attenders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (_) {}
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  bool get _showPickup => _selectedActions.contains('sent_home') || _selectedActions.contains('sent_to_hospital');
  bool get _showMedication => _selectedActions.contains('medication');

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedStudent == null) {
      _showError('Please select a student');
      return;
    }
    if (_selectedActions.isEmpty) {
      _showError('Please select at least one action');
      return;
    }
    if (_showMedication && _medNameCtrl.text.trim().isEmpty) {
      _showError('Please enter the medication name');
      return;
    }

    setState(() => _saving = true);

    Map<String, dynamic>? pickup;
    if (_showPickup && _pickupType != null) {
      pickup = {
        'pickup_type': _pickupType,
        if (_selectedPickupPerson != null) 'pickup_person_id': _selectedPickupPerson!['id'],
        if (_pickupNameCtrl.text.isNotEmpty) 'pickup_person_name': _pickupNameCtrl.text.trim(),
        if (_pickupRelCtrl.text.isNotEmpty) 'pickup_person_relation': _pickupRelCtrl.text.trim(),
        if (_pickupPhoneCtrl.text.isNotEmpty) 'pickup_person_phone': _pickupPhoneCtrl.text.trim(),
        if (_pickupTime != null) 'pickup_time': _pickupTime!.toIso8601String(),
      };
      // Fill name/relation from selected person if not overridden
      if (_selectedPickupPerson != null) {
        pickup['pickup_person_name'] ??= _selectedPickupPerson!['name'];
        pickup['pickup_person_relation'] ??= _selectedPickupPerson!['relation'];
        pickup['pickup_person_phone'] ??= _selectedPickupPerson!['phone'];
      }
    }

    try {
      await ApiClient.logHealthIncident({
        'student_id': _selectedStudent!.id,
        'occurred_at': _occurredAt.toIso8601String(),
        'description': _descCtrl.text.trim(),
        'actions': _selectedActions.toList(),
        'notes': _notesCtrl.text.trim(),
        if (_showMedication && _medNameCtrl.text.isNotEmpty) 'medication_name': _medNameCtrl.text.trim(),
        if (_showMedication) 'medication_consent': _medicationConsent,
        if (pickup != null) 'pickup': pickup,
      });

      if (mounted) {
        showSnack(context, 'Incident logged. Parents notified.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showError(String msg) {
    showSnack(context, msg, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Log Health Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // ── Student picker ────────────────────────────────────────────
            _SectionHeader(title: 'Student', icon: Icons.person_rounded),
            const SizedBox(height: 8),
            _Dropdown<SectionInfo>(
              hint: 'Select class/section',
              items: _sections,
              selected: _selectedSection,
              labelFn: (s) => s.label,
              onChanged: _onSectionChanged,
            ),
            if (_selectedSection != null) ...[
              const SizedBox(height: 8),
              _loadingStudents
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2)),
                    )
                  : _Dropdown<AttendanceStudent>(
                      hint: 'Select student',
                      items: _sectionStudents,
                      selected: _selectedStudent,
                      labelFn: (s) => s.name,
                      onChanged: _onStudentChanged,
                    ),
            ],

            const SizedBox(height: 20),

            // ── Date & Time ───────────────────────────────────────────────
            _SectionHeader(title: 'Date & Time', icon: Icons.access_time_rounded),
            const SizedBox(height: 8),
            _DateTimePicker(
              value: _occurredAt,
              onChanged: (dt) => setState(() => _occurredAt = dt),
            ),

            const SizedBox(height: 20),

            // ── What happened ─────────────────────────────────────────────
            _SectionHeader(title: 'What Happened', icon: Icons.description_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(hintText: 'Describe the incident...'),
              maxLines: 3,
              validator: (v) => (v?.trim().length ?? 0) < 5 ? 'Please describe the incident' : null,
            ),

            const SizedBox(height: 20),

            // ── Actions taken ─────────────────────────────────────────────
            _SectionHeader(title: 'Actions Taken', icon: Icons.medical_services_rounded),
            const SizedBox(height: 4),
            const Text('Select all that apply', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actionMeta.entries.map((e) {
                final selected = _selectedActions.contains(e.key);
                return FilterChip(
                  label: Text(e.value['label'] as String),
                  avatar: Icon(e.value['icon'] as IconData, size: 16),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedActions.add(e.key);
                        if (e.key == 'sent_home' || e.key == 'sent_to_hospital') {
                          _loadPickupPersons();
                        }
                      } else {
                        _selectedActions.remove(e.key);
                      }
                    });
                  },
                  selectedColor: primary.withOpacity(0.15),
                  checkmarkColor: primary,
                  labelStyle: TextStyle(
                    color: selected ? primary : AppColors.text2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  side: BorderSide(color: selected ? primary : AppColors.border),
                  backgroundColor: Colors.white,
                );
              }).toList(),
            ),

            // ── Medication details ────────────────────────────────────────
            if (_showMedication) ...[
              const SizedBox(height: 20),
              _SectionHeader(title: 'Medication Details', icon: Icons.medication_rounded),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ensure parental consent is obtained before administering medication.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _medNameCtrl,
                decoration: const InputDecoration(hintText: 'Medication name (e.g. Paracetamol 500mg)'),
                validator: (_) => _showMedication && _medNameCtrl.text.trim().isEmpty ? 'Enter medication name' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _medicationConsent,
                    onChanged: (v) => setState(() => _medicationConsent = v ?? false),
                    activeColor: primary,
                  ),
                  const Expanded(child: Text('Parental consent was obtained before giving medication', style: TextStyle(fontSize: 13, color: AppColors.text2))),
                ],
              ),
            ],

            // ── Notes (mandatory) ─────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionHeader(title: 'Notes', icon: Icons.notes_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(hintText: 'Additional notes (required, 10–200 chars)'),
              maxLines: 3,
              maxLength: 200,
              validator: (v) {
                final len = v?.trim().length ?? 0;
                if (len < 10) return 'Notes must be at least 10 characters';
                return null;
              },
            ),

            // ── Pickup info ───────────────────────────────────────────────
            if (_showPickup) ...[
              const SizedBox(height: 20),
              _SectionHeader(title: 'Pickup Details', icon: Icons.directions_car_rounded),
              const SizedBox(height: 8),
              _PickupSection(
                parents: _parents,
                attenders: _attenders,
                pickupType: _pickupType,
                selectedPerson: _selectedPickupPerson,
                pickupTime: _pickupTime,
                nameCtrl: _pickupNameCtrl,
                relCtrl: _pickupRelCtrl,
                phoneCtrl: _pickupPhoneCtrl,
                onTypeChanged: (t) => setState(() {
                  _pickupType = t;
                  _selectedPickupPerson = null;
                  _pickupNameCtrl.clear();
                  _pickupRelCtrl.clear();
                  _pickupPhoneCtrl.clear();
                }),
                onPersonChanged: (p) => setState(() => _selectedPickupPerson = p),
                onTimeChanged: (dt) => setState(() => _pickupTime = dt),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Log Incident & Notify Parents'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pickup section widget ─────────────────────────────────────────────────────

class _PickupSection extends StatelessWidget {
  final List<Map<String, dynamic>> parents;
  final List<Map<String, dynamic>> attenders;
  final String? pickupType;
  final Map<String, dynamic>? selectedPerson;
  final DateTime? pickupTime;
  final TextEditingController nameCtrl;
  final TextEditingController relCtrl;
  final TextEditingController phoneCtrl;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<Map<String, dynamic>?> onPersonChanged;
  final ValueChanged<DateTime?> onTimeChanged;

  const _PickupSection({
    required this.parents,
    required this.attenders,
    required this.pickupType,
    required this.selectedPerson,
    required this.pickupTime,
    required this.nameCtrl,
    required this.relCtrl,
    required this.phoneCtrl,
    required this.onTypeChanged,
    required this.onPersonChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final types = [
      ('parent', 'Registered Parent', Icons.family_restroom_rounded),
      ('attender', 'Registered Attender', Icons.person_outline_rounded),
      ('emergency', 'Emergency Contact', Icons.warning_amber_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type selector
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = pickupType == t.$1;
            return ChoiceChip(
              label: Text(t.$2),
              avatar: Icon(t.$3, size: 15),
              selected: selected,
              onSelected: (v) => onTypeChanged(v ? t.$1 : null),
              selectedColor: primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? primary : AppColors.text2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              side: BorderSide(color: selected ? primary : AppColors.border),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),

        if (pickupType == 'parent' && parents.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Dropdown<Map<String, dynamic>>(
            hint: 'Select parent',
            items: parents,
            selected: selectedPerson,
            labelFn: (p) => '${p['name']} (${p['relation']}) • ${p['phone']}',
            onChanged: onPersonChanged,
          ),
        ],

        if (pickupType == 'attender' && attenders.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Dropdown<Map<String, dynamic>>(
            hint: 'Select attender',
            items: attenders,
            selected: selectedPerson,
            labelFn: (p) => '${p['name']} (${p['relation']}) • ${p['phone']}',
            onChanged: onPersonChanged,
          ),
        ],

        if (pickupType == 'emergency' || (pickupType != null && (pickupType == 'parent' && parents.isEmpty) || (pickupType == 'attender' && attenders.isEmpty))) ...[
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Person name', prefixIcon: Icon(Icons.person_rounded, size: 20))),
          const SizedBox(height: 8),
          TextField(controller: relCtrl, decoration: const InputDecoration(hintText: 'Relation (e.g. Uncle, Neighbour)', prefixIcon: Icon(Icons.people_rounded, size: 20))),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone number', prefixIcon: Icon(Icons.phone_rounded, size: 20))),
        ],

        if (pickupType != null) ...[
          const SizedBox(height: 12),
          _DateTimePicker(
            label: 'Pickup Time',
            value: pickupTime ?? DateTime.now(),
            onChanged: onTimeChanged,
          ),
        ],
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String hint;
  final List<T> items;
  final T? selected;
  final String Function(T) labelFn;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.hint,
    required this.items,
    required this.selected,
    required this.labelFn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          value: selected,
          items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(labelFn(item), style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final String? label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DateTimePicker({this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final formatted = '${value.day} ${months[value.month - 1]} ${value.year}, ${value.hour.toString().padLeft(2,'0')}:${value.minute.toString().padLeft(2,'0')}';

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: value, firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now());
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
        if (time == null) return;
        onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: primary),
            const SizedBox(width: 8),
            if (label != null) ...[
              Text('$label: ', style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600)),
            ],
            Text(formatted, style: const TextStyle(fontSize: 14, color: AppColors.text)),
            const Spacer(),
            Icon(Icons.edit_rounded, size: 14, color: primary),
          ],
        ),
      ),
    );
  }
}
