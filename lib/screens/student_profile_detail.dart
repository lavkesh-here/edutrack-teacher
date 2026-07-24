import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'whatsapp_report.dart';
import 'library_screen.dart';

class StudentProfileDetail extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String sectionLabel;

  const StudentProfileDetail({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.sectionLabel,
  });

  @override
  State<StudentProfileDetail> createState() => _StudentProfileDetailState();
}

class _StudentProfileDetailState extends State<StudentProfileDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _showLibraryTab = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    _showLibraryTab = user != null &&
        (user.role == 'admin' || user.role == 'principal' || user.role == 'director' || user.hasTag('librarian'));
    _tabs = TabController(length: _showLibraryTab ? 9 : 8, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiClient.getStudentProfile(
        widget.studentId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() { _profile = p; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  void _openPhotoFullscreen(String photoUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(photoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    final photoUrl = _profile?['photo_url'] as String?;
    final photoUploadedBy = _profile?['photo_uploaded_by'] as String?;
    final canChange = photoUploadedBy != 'teacher';
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    if (!hasPhoto && !canChange) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.visibility_rounded, color: context.primary),
                title: const Text('View Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openPhotoFullscreen(photoUrl!);
                },
              ),
            if (canChange)
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: context.primary),
                title: const Text('Change Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _doUpload();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _doUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploading = true);
    try {
      final resp = await ApiClient.getStudentPhotoUploadUrl(
          widget.studentId, file.name, contentType, bytes.lengthInBytes);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      final putResp = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
        throw Exception('Storage upload failed (${putResp.statusCode})');
      }
      await ApiClient.saveStudentPhoto(widget.studentId, photoUrl);
      setState(() {
        _profile = Map<String, dynamic>.from(_profile ?? {})
          ..['photo_url'] = photoUrl
          ..['photo_uploaded_by'] = 'teacher';
      });
      if (mounted) showSnack(context, 'Photo uploaded ✓');
    } on ApiError catch (e) {
      if (e.statusCode == 409) {
        if (mounted) showSnack(context, 'Photo already uploaded — only a parent can change it', error: true);
      } else {
        if (mounted) showSnack(context, 'Upload failed', error: true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Upload failed', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    final name = _profile!['name'] as String? ?? widget.studentName;
    final admNo = _profile!['admission_number'] as String? ?? '';
    final classLabel = _profile!['class_label'] as String? ?? widget.sectionLabel;
    final photoUrl = _profile!['photo_url'] as String?;
    final gender = _profile!['gender'] as String?;
    final photoUploadedBy = _profile!['photo_uploaded_by'] as String?;
    final canUpload = photoUploadedBy != 'teacher';

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        // ── Gradient hero (collapsed: orange bar + name) ──────────────────
        SliverAppBar(
          expandedHeight: 210,
          pinned: true,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          title: Text(
            '$name · $classLabel',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          actions: [
            if (context.read<AuthProvider>().features.aiAnalysis)
              IconButton(
                tooltip: 'WhatsApp Report',
                icon: const Text('💬', style: TextStyle(fontSize: 20)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WhatsAppReportScreen(
                      studentId: widget.studentId,
                      studentName: widget.studentName,
                    ),
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Builder(
              builder: (ctx) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(ctx).colorScheme.primary,
                    Theme.of(ctx).colorScheme.primary.withOpacity(0.82),
                    AppColors.coral,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Tappable avatar with camera badge
                    GestureDetector(
                      onTap: _uploading ? null : _showPhotoOptions,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _HeroAvatar(
                            initials: _initials(name),
                            photoUrl: photoUrl,
                            gender: gender,
                            size: 72,
                            uploading: _uploading,
                          ),
                          if (canUpload)
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                              ),
                              child: Icon(Icons.camera_alt, size: 14, color: context.primary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '$classLabel · $admNo',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),

        // ── Sticky white tab bar (separate from gradient) ─────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBar(_tabs, showLibrary: _showLibraryTab),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(profile: _profile!, studentId: widget.studentId),
          _AttendanceTab(
            profile: _profile!,
            month: _selectedMonth,
            year: _selectedYear,
            onMonthChanged: (m, y) {
              setState(() { _selectedMonth = m; _selectedYear = y; });
              _load();
            },
          ),
          _TestsTab(tests: (_profile!['tests'] as List?)?.cast<Map<String, dynamic>>() ?? []),
          _StudentWorkLogsTab(studentId: widget.studentId),
          _ReportTab(studentId: widget.studentId),
          _FullReportCardTab(studentId: widget.studentId),
          _CertificatesTab(studentId: widget.studentId),
          _MedicalProfileTab(studentId: widget.studentId),
          if (_showLibraryTab) StudentLibraryTab(studentId: widget.studentId),
        ],
      ),
    );
  }
}

// ── Sticky tab bar delegate ───────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final bool showLibrary;
  const _StickyTabBar(this.controller, {this.showLibrary = false});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: null,
        indicatorWeight: 3,
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.muted,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: [
          const Tab(text: 'Profile'),
          const Tab(text: 'Attendance'),
          const Tab(text: 'Tests'),
          const Tab(text: 'Work Logs'),
          const Tab(text: 'Report'),
          const Tab(text: 'Report Card'),
          const Tab(text: 'Certificates'),
          const Tab(text: 'Medical'),
          if (showLibrary) const Tab(text: 'Library'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// ── Hero avatar ───────────────────────────────────────────────────────────────

class _HeroAvatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final String? gender;
  final double size;
  final bool uploading;
  const _HeroAvatar({required this.initials, this.photoUrl, this.gender, required this.size, this.uploading = false});

  Widget _initialsWidget() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
        ),
        child: Center(
          child: Text(initials, style: TextStyle(fontSize: size * 0.37, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(),
        ),
      );
    }
    return _initialsWidget();
  }
}

// ── Tab 1: Profile ────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String studentId;
  const _ProfileTab({required this.profile, required this.studentId});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  List<Map<String, dynamic>>? _contacts;
  bool _loadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ApiClient.getStudentEmergencyContacts(widget.studentId);
      if (mounted) setState(() { _contacts = contacts; _loadingContacts = false; });
    } catch (_) {
      if (mounted) setState(() { _contacts = []; _loadingContacts = false; });
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _showAddContactDialog() => _showContactFormDialog();

  Future<void> _showEditContactDialog(Map<String, dynamic> contact) =>
      _showContactFormDialog(existing: contact);

  Future<void> _showContactFormDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final relationCtrl = TextEditingController(text: existing?['relation'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    int priority = existing?['priority'] as int? ?? 1;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEdit ? 'Edit Emergency Contact' : 'Add Emergency Contact', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relationCtrl,
                decoration: const InputDecoration(labelText: 'Relation (e.g. Mother) *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Mobile Number *', counterText: ''),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length == 10 ? null : 'Enter 10-digit mobile number';
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Priority:', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(width: 12),
                for (int p = 1; p <= 3; p++)
                  GestureDetector(
                    onTap: () => setD(() => priority = p),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: priority == p ? Theme.of(ctx).colorScheme.primary : AppColors.bg,
                        border: Border.all(
                          color: priority == p ? Theme.of(ctx).colorScheme.primary : AppColors.border,
                        ),
                      ),
                      child: Center(child: Text('$p', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: priority == p ? Colors.white : AppColors.muted,
                      ))),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await ApiClient.updateEmergencyContact(
                      existing['id'].toString(),
                      name: nameCtrl.text.trim(),
                      relation: relationCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      priority: priority,
                    );
                  } else {
                    await ApiClient.addEmergencyContact(
                      studentId: widget.studentId,
                      name: nameCtrl.text.trim(),
                      relation: relationCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      priority: priority,
                    );
                  }
                  _loadContacts();
                } catch (e) {
                  if (mounted) showSnack(context, 'Failed: $e', error: true);
                }
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(String contactId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact?'),
        content: Text('Remove $name from emergency contacts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.deleteEmergencyContact(contactId);
      _loadContacts();
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to delete: $e', error: true);
    }
  }

  Widget _buildEmergencyContactsSection(bool isAdmin) {
    final contacts = _contacts ?? [];
    return _SectionCard(
      title: 'Emergency Contacts',
      trailing: isAdmin
          ? InkWell(
              onTap: _showAddContactDialog,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline, size: 16, color: context.primary),
                const SizedBox(width: 4),
                Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.primary)),
              ]),
            )
          : null,
      children: [
        if (_loadingContacts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (contacts.isEmpty)
          Text(
            isAdmin ? 'No emergency contacts added — tap Add' : 'No emergency contacts added',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          Column(
            children: [
              for (int i = 0; i < contacts.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _EmergencyContactRow(
                  contact: contacts[i],
                  isAdmin: isAdmin,
                  onEdit: () => _showEditContactDialog(contacts[i]),
                  onDelete: () => _deleteContact(
                    contacts[i]['id'].toString(),
                    contacts[i]['name'] as String? ?? 'this contact',
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final phone2 = profile['guardian_phone_2'] as String?;
    final user = context.read<AuthProvider>().user;
    final isAdmin = user != null && (user.role == 'admin' || user.role == 'principal' || user.role == 'director');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Personal Information',
          children: [
            _InfoRow(label: 'Admission No.', value: profile['admission_number']?.toString() ?? '—'),
            _InfoRow(label: 'Gender', value: _capitalize(profile['gender']?.toString() ?? '—')),
            _InfoRow(label: 'Date of Birth', value: _fmtDate(profile['dob']?.toString())),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Guardian',
          children: [
            _InfoRow(label: 'Name', value: profile['guardian_name']?.toString() ?? '—'),
            _InfoRow(label: 'Primary Phone', value: profile['guardian_phone']?.toString() ?? '—'),
            if (phone2 != null && phone2.isNotEmpty)
              _InfoRow(label: 'Secondary Phone', value: phone2),
          ],
        ),
        const SizedBox(height: 12),
        _buildEmergencyContactsSection(isAdmin),
      ],
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EmergencyContactRow({required this.contact, required this.isAdmin, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final priority = contact['priority'] as int? ?? 1;
    final addedBy = contact['added_by_type'] as String? ?? 'admin';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priority == 1 ? AppColors.coral.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: priority == 1 ? AppColors.coralLight : AppColors.amberLight,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('$priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
            color: priority == 1 ? AppColors.coral : AppColors.amber))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(contact['name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(contact['relation'] as String? ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          InkWell(
            onTap: () async {
              final phone = contact['phone'] as String? ?? '';
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: context.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call, size: 14, color: context.primary),
                const SizedBox(width: 4),
                Text(contact['phone'] as String? ?? '—', style: TextStyle(fontSize: 12, color: context.primary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text('Added by $addedBy', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
        if (isAdmin) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
            tooltip: 'Edit contact',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.coral),
            tooltip: 'Remove contact',
            onPressed: onDelete,
          ),
        ],
      ]),
    );
  }
}

// ── Tab 2: Attendance (calendar) ──────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int month;
  final int year;
  final void Function(int month, int year) onMonthChanged;

  const _AttendanceTab({
    required this.profile,
    required this.month,
    required this.year,
    required this.onMonthChanged,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final att = profile['attendance_this_month'] as Map<String, dynamic>? ?? {};
    final pct = att['percentage'];
    final attDays = (profile['attendance_days'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Build lookup map: date string => status
    final statusMap = <String, String>{};
    for (final d in attDays) {
      final date = d['date'] as String? ?? '';
      final status = d['status'] as String? ?? '';
      statusMap[date] = status;
    }

    final now = DateTime.now();
    final isCurrentMonth = month == now.month && year == now.year;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary badges
        _SectionCard(
          title: '${_monthNames[month - 1]} $year',
          children: [
            Row(
              children: [
                _AttBadge(label: 'Present', value: '${att['present'] ?? 0}', color: AppColors.teal, bg: AppColors.tealLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Absent', value: '${att['absent'] ?? 0}', color: AppColors.coral, bg: AppColors.coralLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Late', value: '${att['late'] ?? 0}', color: AppColors.amber, bg: AppColors.amberLight),
                const SizedBox(width: 8),
                _AttBadge(label: '%', value: '${pct ?? 0}%', color: AppColors.sky, bg: AppColors.skyLight),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((pct as num).toDouble() / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  color: pct >= 75 ? AppColors.teal : pct >= 50 ? AppColors.amber : AppColors.coral,
                  minHeight: 7,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Month navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (month == 1) {
                    onMonthChanged(12, year - 1);
                  } else {
                    onMonthChanged(month - 1, year);
                  }
                },
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month - 1]} $year',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: isCurrentMonth ? null : () {
                  if (month == 12) {
                    onMonthChanged(1, year + 1);
                  } else {
                    onMonthChanged(month + 1, year);
                  }
                },
                icon: Icon(Icons.chevron_right_rounded,
                    color: isCurrentMonth ? AppColors.border : AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Calendar grid
        _AttendanceCalendar(
          month: month,
          year: year,
          statusMap: statusMap,
        ),

        const SizedBox(height: 12),

        // Legend
        _SectionCard(
          title: 'LEGEND',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _LegendItem(color: AppColors.teal, label: 'Present (P)'),
                _LegendItem(color: AppColors.coral, label: 'Absent (A)'),
                _LegendItem(color: AppColors.amber, label: 'Late (L)'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  final int month;
  final int year;
  final Map<String, String> statusMap;

  const _AttendanceCalendar({
    required this.month,
    required this.year,
    required this.statusMap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    // Monday=1, so offset = (weekday - 1) to get 0-based Mon index
    final startOffset = (firstDay.weekday - 1) % 7;

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: dayLabels.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Day cells
          Builder(builder: (context) {
            final cells = <Widget>[];
            // Empty cells before first day
            for (int i = 0; i < startOffset; i++) {
              cells.add(const Expanded(child: SizedBox()));
            }
            for (int day = 1; day <= daysInMonth; day++) {
              final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final status = statusMap[dateStr];
              final isToday = DateTime.now().year == year &&
                  DateTime.now().month == month &&
                  DateTime.now().day == day;
              cells.add(Expanded(child: _CalendarCell(
                day: day,
                status: status,
                isToday: isToday,
              )));
            }
            // Pad to complete the last row
            final remainder = cells.length % 7;
            if (remainder != 0) {
              for (int i = 0; i < 7 - remainder; i++) {
                cells.add(const Expanded(child: SizedBox()));
              }
            }
            // Chunk into rows of 7
            final rows = <Widget>[];
            for (int i = 0; i < cells.length; i += 7) {
              rows.add(Row(children: cells.sublist(i, i + 7)));
              if (i + 7 < cells.length) rows.add(const SizedBox(height: 4));
            }
            return Column(children: rows);
          }),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final int day;
  final String? status;
  final bool isToday;

  const _CalendarCell({required this.day, this.status, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'present' => (AppColors.teal, Colors.white, 'P'),
      'absent'  => (AppColors.coral, Colors.white, 'A'),
      'late'    => (AppColors.amber, Colors.white, 'L'),
      _         => (Colors.transparent, AppColors.muted, ''),
    };

    return Container(
      margin: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: status != null ? bg : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && status == null
                ? Border.all(color: context.primary, width: 1.5)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status != null ? fg : (isToday ? context.primary : AppColors.text2),
                ),
              ),
              if (status != null)
                Positioned(
                  bottom: 2,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: fg.withOpacity(0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ],
      );
}

// ── Tab 3: Tests ──────────────────────────────────────────────────────────────

class _TestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> tests;
  const _TestsTab({required this.tests});

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return const _EmptyState(icon: '📊', label: 'No test records yet');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _TestScoreCard(test: tests[i]),
    );
  }
}

class _TestScoreCard extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestScoreCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final title = test['title'] as String? ?? '';
    final subject = test['subject'] as String? ?? '';
    final total = (test['total_marks'] as num?)?.toDouble() ?? 0;
    final score = (test['score'] as num?)?.toDouble();
    final isAbsent = test['is_absent'] as bool? ?? false;
    final pct = (test['percentage'] as num?)?.toDouble();
    final date = test['scheduled_date'] as String?;
    final examType = (test['work_type'] ?? test['exam_type']) as String? ?? '';

    final (Color statusColor, String statusLabel) = isAbsent
        ? (AppColors.coral, 'Absent')
        : pct == null
            ? (AppColors.muted, '—')
            : pct >= 75
                ? (AppColors.teal, 'Pass')
                : pct >= 40
                    ? (AppColors.amber, 'Pass')
                    : (AppColors.coral, 'Fail');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (subject.isNotEmpty) ...[
                Text(subject, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(width: 8),
              ],
              if (examType.isNotEmpty) ...[
                Text(_fmtExamType(examType), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                const SizedBox(width: 8),
              ],
              if (date != null)
                Text(_fmtDate(date), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (isAbsent)
            const Text('Absent from test', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600))
          else if (score != null) ...[
            Row(
              children: [
                Text(
                  '${score % 1 == 0 ? score.toInt() : score}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                Text(' / ${total % 1 == 0 ? total.toInt() : total}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                if (pct != null)
                  Text('$pct%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  color: statusColor,
                  minHeight: 5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _fmtExamType(String t) => switch (t) {
        'weekly' => 'Weekly', 'monthly' => 'Monthly', 'quarterly' => 'Quarterly',
        'half_yearly' => 'Half Yearly', 'annual' => 'Annual', 'unit_test' => 'Unit Test',
        _ => t,
      };
}

// ── Tab 4: Work Logs ──────────────────────────────────────────────────────────

class _StudentWorkLogsTab extends StatefulWidget {
  final String studentId;
  const _StudentWorkLogsTab({required this.studentId});

  @override
  State<_StudentWorkLogsTab> createState() => _StudentWorkLogsTabState();
}

class _StudentWorkLogsTabState extends State<_StudentWorkLogsTab>
    with AutomaticKeepAliveClientMixin {
  List<WorkLogEntry> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getWorkLogs(studentId: widget.studentId);
      if (mounted) setState(() { _logs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ),
    );
    if (_logs.isEmpty) return const _EmptyState(icon: '📝', label: 'No work logs assigned to this student');
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _WorkLogCard(entry: _logs[i]),
      ),
    );
  }
}

class _WorkLogCard extends StatelessWidget {
  final WorkLogEntry entry;
  const _WorkLogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (typeIcon, typeColor, typeBg) = switch (entry.logType) {
      'homework'  => ('📚', AppColors.coral, AppColors.coralLight),
      'note'      => ('📌', AppColors.amber, AppColors.amberLight),
      _           => ('📖', AppColors.sky,   AppColors.skyLight),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
            child: Text('$typeIcon ${entry.logType[0].toUpperCase()}${entry.logType.substring(1)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
          ),
          const Spacer(),
          Text(entry.date, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        Text(entry.description,
            style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4)),
        if (entry.dueDate != null) ...[
          const SizedBox(height: 6),
          Text('Due: ${entry.dueDate}',
              style: const TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w500)),
        ],
        if (entry.subjectName != null || entry.sectionLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [if (entry.subjectName != null) entry.subjectName!, if (entry.sectionLabel.isNotEmpty) entry.sectionLabel].join(' · '),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
        if (entry.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: entry.imageUrls.map((url) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _openImageViewer(context, entry.imageUrls, entry.imageUrls.indexOf(url)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 64, height: 64, color: AppColors.border,
                          child: const Icon(Icons.broken_image_outlined, size: 20, color: AppColors.muted))),
                ),
              ),
            )).toList(),
          ),
        ],
      ]),
    );
  }
}

void _openImageViewer(BuildContext context, List<String> urls, int initialIndex) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(urls[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.muted)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


// ── Tab 5: Longitudinal Report ────────────────────────────────────────────────

class _ReportTab extends StatefulWidget {
  final String studentId;
  const _ReportTab({required this.studentId});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _generating = false;
  String? _error;
  final _notesController = TextEditingController();
  String? _previousTeacherNotes; // notes from before the most recent analysis

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.getLongitudinalReport(widget.studentId);
      if (mounted) {
        // Restore saved notes into the text field
        final savedNotes = r['teacher_notes'] as String?;
        if (savedNotes != null && savedNotes.isNotEmpty) {
          _notesController.text = savedNotes;
        }
        setState(() {
          _report = r;
          _previousTeacherNotes = r['previous_teacher_notes'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final is404 = e is ApiError && e.statusCode == 404 ||
            e.toString().contains('404') || e.toString().contains('Not Found') ||
            e.toString().contains('Student not found');
        setState(() {
          _error = is404 ? null : e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _generateAnalysis() async {
    setState(() => _generating = true);
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    try {
      final r = await ApiClient.generateLongitudinalAnalysis(widget.studentId, teacherNotes: notes);
      if (mounted) {
        setState(() {
          _report = {
            ..._report ?? {},
            'ai_analysis': r['analysis'],
            'ai_analysis_generated_at': r['generated_at'],
            'teacher_notes': r['teacher_notes'],
            'analysis_version': r['version_number'],
          };
          // Previous notes become the notes from before this regeneration
          _previousTeacherNotes = _report?['teacher_notes'] as String?;
        });
        showSnack(context, 'Smart report generated');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Generation failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _EmptyState(icon: '⚠️', label: 'Could not load report');
    final report = _report!;
    final canUseAi = context.read<AuthProvider>().features.aiAnalysis;

    final history = (report['test_history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final heatmap = (report['chapter_heatmap'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final analysis = report['ai_analysis'] as Map<String, dynamic>?;
    final generatedAt = report['ai_analysis_generated_at'] as String?;
    final trend = report['trend'] as String? ?? 'first_test';
    final avg = (report['average_percentage'] as num?)?.toDouble();
    final total = report['total_tests'] as int? ?? 0;

    return RefreshIndicator(
      color: context.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary strip ──
          Row(children: [
            _StatChip(label: 'Tests', value: '$total', color: AppColors.sky),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Average',
              value: avg != null ? '${avg.toStringAsFixed(1)}%' : '—',
              color: avg == null ? AppColors.muted : avg >= 75 ? AppColors.teal : avg >= 50 ? AppColors.amber : AppColors.coral,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Trend',
              value: switch (trend) {
                'improving' => '↑ Improving',
                'declining' => '↓ Declining',
                'stable' => '→ Stable',
                _ => '— First',
              },
              color: switch (trend) {
                'improving' => AppColors.teal,
                'declining' => AppColors.coral,
                _ => AppColors.amber,
              },
            ),
          ]),
          const SizedBox(height: 16),

          // ── Score trend chart ──
          if (history.isNotEmpty) ...[
            _SectionCard(title: 'Score Trend', children: [
              _ScoreTrendChart(history: history),
            ]),
            const SizedBox(height: 12),
          ],

          // ── AI Analysis ──
          if (!canUseAi) ...[
            _PlanUpgradeCard(feature: 'Smart Analysis', requiredPlan: 'Premium'),
            const SizedBox(height: 12),
          ] else if (analysis != null) ...[
            _SectionCard(title: 'Smart Analysis${generatedAt != null ? ' · ${_fmtDate(generatedAt)}' : ''}', children: [
              _AnalysisCard(analysis: analysis),
              const SizedBox(height: 16),
              // Teacher notes — shown pre-filled when regenerating
              if (_previousTeacherNotes != null && _previousTeacherNotes!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your previous notes',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.primary)),
                      const SizedBox(height: 4),
                      Text(_previousTeacherNotes!,
                          style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add your observations before refreshing (optional)…',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('refresh_analysis_button'),
                  onPressed: _generating ? null : _generateAnalysis,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.primary,
                    side: BorderSide(color: context.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _generating
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Refresh Analysis', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                const Text('🤖', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                const Text('No analysis yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('Add your observations to personalise the report.', style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Your observations about this student (optional)…',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('generate_ai_report_button'),
                    onPressed: total == 0 || _generating ? null : _generateAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: null,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _generating
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Generate Report', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (total == 0) ...[
                  const SizedBox(height: 8),
                  const Text('No test records yet — enter scores first', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 12),

          // ── Chapter heatmap ──
          if (heatmap.isNotEmpty) ...[
            _SectionCard(title: 'Chapter Performance', children: [
              ...heatmap.map((c) => _ChapterHeatRow(chapter: c)),
            ]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return iso; }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
      ]),
    ),
  );
}

class _ScoreTrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  const _ScoreTrendChart({required this.history});
  @override
  State<_ScoreTrendChart> createState() => _ScoreTrendChartState();
}

class _ScoreTrendChartState extends State<_ScoreTrendChart> {
  int? _selectedIndex;

  List<Map<String, dynamic>> get _scored => widget.history
      .where((t) => t['percentage'] != null && t['is_absent'] == false)
      .toList();

  String _shortDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month-1]}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final scored = _scored;
    final dataPoints = scored.map((t) => (t['percentage'] as num).toDouble()).toList();

    if (dataPoints.isEmpty) {
      return const Center(child: Text('No scored tests yet',
          style: TextStyle(fontSize: 12, color: AppColors.muted)));
    }

    final dates = scored.map((t) => _shortDate(t['date'] as String?)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTapUp: (details) {
          if (dataPoints.length < 2) {
            setState(() => _selectedIndex = _selectedIndex == null ? 0 : null);
            return;
          }
          final renderBox = context.findRenderObject() as RenderBox?;
          final w = renderBox?.size.width ?? 300.0;
          final tappedX = details.localPosition.dx;
          int nearest = 0;
          double minDist = double.infinity;
          for (int i = 0; i < dataPoints.length; i++) {
            final x = i / (dataPoints.length - 1) * w;
            final dist = (x - tappedX).abs();
            if (dist < minDist) { minDist = dist; nearest = i; }
          }
          setState(() => _selectedIndex = _selectedIndex == nearest ? null : nearest);
        },
        child: SizedBox(
          height: 130,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              dataPoints,
              dates: dates,
              color: context.primary,
              selectedIndex: _selectedIndex,
            ),
          ),
        ),
      ),
      // Selected test info card
      if (_selectedIndex != null && _selectedIndex! < scored.length) ...[
        const SizedBox(height: 8),
        _TestDetailTile(test: scored[_selectedIndex!]),
      ],
      const SizedBox(height: 4),
      Text(
        '${dataPoints.length} test${dataPoints.length == 1 ? '' : 's'} · tap a dot for details',
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      ),
    ]);
  }
}

class _TestDetailTile extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestDetailTile({required this.test});

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month-1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final title = test['title'] as String? ?? 'Test';
    final subject = test['subject'] as String? ?? '';
    final date = _fmtDate(test['date'] as String?);
    final score = test['score'];
    final total = test['total_marks'];
    final pct = (test['percentage'] as num?)?.toDouble() ?? 0;

    final color = pct >= 75 ? AppColors.green : pct >= 50 ? AppColors.amber : AppColors.coral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subject.isNotEmpty || date.isNotEmpty)
            Text('${subject.isNotEmpty ? subject : ''}${subject.isNotEmpty && date.isNotEmpty ? ' · ' : ''}$date',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          if (score != null && total != null)
            Text('$score / $total', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final List<String> dates;
  final Color color;
  final int? selectedIndex;
  _LinePainter(this.points, {required this.color, this.dates = const [], this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Reserve bottom space for date labels
    const dateAreaH = 18.0;
    final h = size.height - dateAreaH - 8;
    final w = size.width;
    final min = points.reduce((a, b) => a < b ? a : b).clamp(0, 100).toDouble();
    final max = points.reduce((a, b) => a > b ? a : b).clamp(0, 100).toDouble();
    final range = (max - min).clamp(10, 100).toDouble();

    double xOf(int i) => points.length == 1 ? w / 2 : i / (points.length - 1) * w;
    double yOf(double v) => h - ((v - min) / range * h);

    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final bgPaint = Paint()..color = color.withOpacity(0.08)..style = PaintingStyle.fill;

      final path = Path()..moveTo(xOf(0), yOf(points[0]));
      for (int i = 1; i < points.length; i++) path.lineTo(xOf(i), yOf(points[i]));

      final fill = Path.from(path)
        ..lineTo(xOf(points.length - 1), h)
        ..lineTo(xOf(0), h)
        ..close();
      canvas.drawPath(fill, bgPaint);
      canvas.drawPath(path, linePaint);
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);

    // Draw dots and score labels
    for (int i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i]);
      final isSelected = selectedIndex == i;

      // Outer ring for selected
      if (isSelected) {
        canvas.drawCircle(Offset(x, y), 8, Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(x, y), 6, Paint()..color = color..style = PaintingStyle.fill);
      } else {
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = color..style = PaintingStyle.fill);
      }

      // Score label above dot — always visible
      final labelText = '${points[i].toStringAsFixed(0)}%';
      tp.text = TextSpan(
        text: labelText,
        style: TextStyle(fontSize: 8, color: isSelected ? color : AppColors.muted, fontWeight: FontWeight.w700),
      );
      tp.layout();
      final lx = x - tp.width / 2;
      final ly = (y - tp.height - 5).clamp(0.0, h - tp.height);
      tp.paint(canvas, Offset(lx.clamp(0.0, w - tp.width), ly));
    }

    // Date labels below chart — show all if ≤ 6, else every other
    if (dates.isNotEmpty) {
      final step = points.length > 6 ? 2 : 1;
      for (int i = 0; i < points.length; i += step) {
        if (i >= dates.length) break;
        final dateLabel = dates[i];
        if (dateLabel.isEmpty) continue;
        tp.text = TextSpan(
          text: dateLabel,
          style: const TextStyle(fontSize: 7.5, color: AppColors.muted, fontWeight: FontWeight.w500),
        );
        tp.layout();
        final x = xOf(i) - tp.width / 2;
        tp.paint(canvas, Offset(x.clamp(0.0, w - tp.width), h + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points || old.selectedIndex != selectedIndex;
}

class _AnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final level = analysis['performance_level'] as String? ?? '';
    final (levelColor, levelBg) = switch (level) {
      'excellent' => (const Color(0xFF166534), const Color(0xFFDCFCE7)),
      'good' => (const Color(0xFF1E40AF), const Color(0xFFDBEAFE)),
      'average' => (const Color(0xFF854D0E), const Color(0xFFFEF9C3)),
      'needs_attention' => (const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      _ => (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: levelBg, borderRadius: BorderRadius.circular(20)),
        child: Text(level.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: levelColor)),
      ),
      const SizedBox(height: 12),
      if ((analysis['strengths'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '✅', label: 'Strengths', text: analysis['strengths'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['weak_areas'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '⚠️', label: 'Weak Areas', text: analysis['weak_areas'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['action_plan'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '📋', label: 'Action Plan', text: analysis['action_plan'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['parent_note'] as String? ?? '').isNotEmpty)
        _AnalysisRow(icon: '💬', label: 'Parent Note', text: analysis['parent_note'] as String),
    ]);
  }
}

class _AnalysisRow extends StatelessWidget {
  final String icon;
  final String label;
  final String text;
  const _AnalysisRow({required this.icon, required this.label, required this.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$icon $label', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text)),
      const SizedBox(height: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.45)),
    ],
  );
}

class _ChapterHeatRow extends StatelessWidget {
  final Map<String, dynamic> chapter;
  const _ChapterHeatRow({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final name = chapter['chapter_name'] as String? ?? '';
    final pct = (chapter['avg_pct'] as num?)?.toDouble();
    final heat = chapter['heat_level'] as String? ?? 'none';
    final (barColor, bg) = switch (heat) {
      'green' => (AppColors.teal, AppColors.tealLight),
      'amber' => (AppColors.amber, AppColors.amberLight),
      'red'   => (AppColors.coral, AppColors.coralLight),
      _       => (AppColors.muted, AppColors.bg),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct != null ? (pct / 100).clamp(0.0, 1.0) : 0,
                backgroundColor: AppColors.border,
                color: barColor,
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: barColor),
          ),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
          ],
        ),
      );
}

class _AttBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _AttBadge({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      );
}

// ── Plan upgrade prompt ───────────────────────────────────────────────────────

class _PlanUpgradeCard extends StatelessWidget {
  final String feature;
  final String requiredPlan;
  const _PlanUpgradeCard({required this.feature, required this.requiredPlan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🔒', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 10),
        Text(feature, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 4),
        Text(
          'This feature requires the $requiredPlan plan. Contact your school administrator to upgrade.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── Full Report Card Tab ──────────────────────────────────────────────────────

class _FullReportCardTab extends StatefulWidget {
  final String studentId;
  const _FullReportCardTab({required this.studentId});

  @override
  State<_FullReportCardTab> createState() => _FullReportCardTabState();
}

class _FullReportCardTabState extends State<_FullReportCardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.getStudentFullReport(widget.studentId);
      if (mounted) setState(() { _report = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        // 404 = no report generated yet — not an error, just show Generate button
        final is404 = e is ApiError && e.statusCode == 404 ||
            e.toString().contains('404') || e.toString().contains('Not Found') ||
            e.toString().contains('No report');
        setState(() {
          _report = null;
          _error = is404 ? null : e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final r = await ApiClient.generateStudentFullReport(widget.studentId);
      if (mounted) {
        setState(() { _report = r; });
        showSnack(context, 'Report card generated');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Generation failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Plan gate — show upgrade prompt before anything else
    final canUseAi = context.read<AuthProvider>().features.aiAnalysis;
    if (!canUseAi) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _PlanUpgradeCard(feature: 'Holistic Report Card', requiredPlan: 'Premium'),
        ),
      );
    }

    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadReport, child: const Text('Retry')),
          ],
        ),
      ),
    );

    final reportJson = _report?['report'] as Map<String, dynamic>?;
    final isStale = _report?['is_stale'] as bool? ?? true;
    final hasReport = reportJson != null;

    return RefreshIndicator(
      color: context.primary,
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Holistic Report Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (hasReport && isStale)
                      const Text('Data may have changed — regenerate for latest', style: TextStyle(color: AppColors.amber, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _generating ? null : _generateReport,
                icon: _generating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('✨', style: TextStyle(fontSize: 14)),
                label: Text(hasReport ? 'Regenerate' : 'Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: null,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          if (!hasReport) ...[
            const SizedBox(height: 32),
            const _EmptyState(icon: '📋', label: 'No report card yet.\nTap Generate to create one.'),
          ] else ...[
            const SizedBox(height: 16),

            // Level & trend
            Row(
              children: [
                _RcChip(reportJson['overall_level'] as String? ?? '—', context.primary, context.primaryLight),
                const SizedBox(width: 8),
                _RcChip(_trendLabel(reportJson['overall_trend'] as String? ?? ''), AppColors.teal, AppColors.tealLight),
              ],
            ),

            // Summary
            if ((reportJson['summary'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(reportJson['summary'] as String, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],

            // Strengths
            const SizedBox(height: 16),
            const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['strengths'] as List<dynamic>? ?? []).map((s) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ ', style: TextStyle(fontSize: 13)),
                    Expanded(child: Text(s.toString(), style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),

            // Focus Areas
            const SizedBox(height: 16),
            const Text('Focus Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['focus_areas'] as List<dynamic>? ?? []).map((f) {
              final fa = f as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.coral.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fa['area'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((fa['observation'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(fa['observation'] as String, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
                    ],
                    if ((fa['action'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text('→ ${fa['action']}', style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              );
            }),

            // Subject Feedback
            const SizedBox(height: 16),
            const Text('Subject Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['subject_feedback'] as List<dynamic>? ?? []).map((sf) {
              final s = sf as Map<String, dynamic>;
              final avg = (s['avg_pct'] as num?)?.toDouble() ?? 0;
              Color barColor = AppColors.green;
              if (avg < 60) barColor = AppColors.coral;
              else if (avg < 80) barColor = AppColors.amber;
              else if (avg < 90) barColor = AppColors.sky;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s['subject'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('${avg.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (avg / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 5,
                      ),
                    ),
                    if ((s['feedback'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(s['feedback'] as String, style: const TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4)),
                    ],
                  ],
                ),
              );
            }),

            // Parent Message
            if ((reportJson['parent_message'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              const Text('Parent Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                ),
                child: Text(reportJson['parent_message'] as String,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2)),
              ),
            ],

            // Teacher Note
            if ((reportJson['teacher_note'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text('Teacher Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                ),
                child: Text(reportJson['teacher_note'] as String,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2)),
              ),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _trendLabel(String trend) {
    return switch (trend) {
      'improving' => '↑ Improving',
      'declining' => '↓ Declining',
      'stable' => '→ Stable',
      _ => '— First',
    };
  }
}

class _RcChip extends StatelessWidget {
  const _RcChip(this.label, this.fg, this.bg);
  final String label;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
  );
}

// ── Certificates tab ─────────────────────────────────────────────────────────

const _certTypeColors = {
  'academic':      Color(0xFFFEF3C7),
  'sports':        Color(0xFFDBEAFE),
  'participation': Color(0xFFCCFBF1),
  'cultural':      Color(0xFFFEE2E2),
  'attendance':    Color(0xFFDCFCE7),
  'custom':        Color(0xFFEDE9FE),
};
const _certTypeFg = {
  'academic':      Color(0xFF92400E),
  'sports':        Color(0xFF1E3A8A),
  'participation': Color(0xFF134E4A),
  'cultural':      Color(0xFF7F1D1D),
  'attendance':    Color(0xFF14532D),
  'custom':        Color(0xFF4C1D95),
};
const _certTypeEmoji = {
  'academic': '🎓', 'sports': '🏆', 'participation': '🎗️',
  'cultural': '🎭', 'attendance': '📅', 'custom': '📜',
};

class _CertificatesTab extends StatefulWidget {
  final String studentId;
  const _CertificatesTab({required this.studentId});
  @override
  State<_CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<_CertificatesTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _certs = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getStudentCertificates(widget.studentId);
      if (mounted) setState(() { _certs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_certs.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🎓', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('No certificates issued yet', style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _certs.length,
        itemBuilder: (_, i) => _CertCard(cert: _certs[i]),
      ),
    );
  }
}

class _CertCard extends StatefulWidget {
  final Map<String, dynamic> cert;
  const _CertCard({required this.cert});
  @override
  State<_CertCard> createState() => _CertCardState();
}

class _CertCardState extends State<_CertCard> {
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final url = await ApiClient.getCertificatePdfUrl(widget.cert['id'] as String);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open certificate PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month-1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final cert = widget.cert;
    final type = cert['cert_type'] as String? ?? 'custom';
    final bg = _certTypeColors[type] ?? const Color(0xFFEDE9FE);
    final fg = _certTypeFg[type] ?? const Color(0xFF4C1D95);
    final emoji = _certTypeEmoji[type] ?? '📜';
    final fields = (cert['field_values'] as Map?)?.cast<String, dynamic>() ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text('$emoji ${cert['title_text'] ?? 'Certificate'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            ),
            const Spacer(),
            Text(_fmtDate(cert['issued_at'] as String?),
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          Text(cert['template_name'] as String? ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          if (cert['academic_year'] != null) ...[
            const SizedBox(height: 2),
            Text('Academic Year: ${cert['academic_year']}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: fields.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border)),
              child: Text('${e.value}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            )).toList()),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text('Cert No: ${cert['cert_number'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted, fontFamily: 'monospace')),
            const Spacer(),
            Text('Issued by ${cert['issued_by_name'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloading ? null : _downloadPdf,
              icon: _downloading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: Text(_downloading ? 'Opening…' : 'Download PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.violet,
                side: BorderSide(color: AppColors.violet.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Medical Profile Tab ───────────────────────────────────────────────────────

class _MedicalProfileTab extends StatefulWidget {
  final String studentId;
  const _MedicalProfileTab({required this.studentId});
  @override
  State<_MedicalProfileTab> createState() => _MedicalProfileTabState();
}

class _MedicalProfileTabState extends State<_MedicalProfileTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiClient.getStudentMedicalProfile(widget.studentId);
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _showEditDialog() async {
    final p = _profile ?? {};
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown'];
    String? bloodGroup = p['blood_group'] as String?;
    final allergiesCtrl = TextEditingController(
      text: ((p['allergies'] as List?)?.cast<String>() ?? []).join(', '),
    );
    final medicinesCtrl = TextEditingController(
      text: ((p['ongoing_medicines'] as List?)?.cast<String>() ?? []).join(', '),
    );
    final historyCtrl = TextEditingController(text: p['medical_history'] as String? ?? '');
    final notesCtrl = TextEditingController(text: p['emergency_notes'] as String? ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Medical Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: bloodGroup,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                items: bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setD(() => bloodGroup = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: allergiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  hintText: 'Comma-separated, e.g. Peanuts, Dust',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: medicinesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ongoing Medicines',
                  hintText: 'Comma-separated',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: historyCtrl,
                decoration: const InputDecoration(labelText: 'Medical History'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Emergency Notes'),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                List<String> _split(String s) =>
                    s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                try {
                  await ApiClient.upsertStudentMedicalProfile(
                    widget.studentId,
                    bloodGroup: bloodGroup,
                    allergies: _split(allergiesCtrl.text),
                    ongoingMedicines: _split(medicinesCtrl.text),
                    medicalHistory: historyCtrl.text.trim().isEmpty ? null : historyCtrl.text.trim(),
                    emergencyNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  _load();
                } catch (e) {
                  if (mounted) showSnack(context, 'Failed: $e', error: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isAdmin = user != null && (user.role == 'admin' || user.role == 'principal' || user.role == 'director');

    if (_loading) return const Center(child: CircularProgressIndicator());
    final p = _profile;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showEditDialog,
              icon: Icon(p == null ? Icons.add_rounded : Icons.edit_rounded),
              label: Text(p == null ? 'Add Medical Info' : 'Edit', style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: p == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🏥', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  const Text('No medical profile on record', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin ? 'Tap + to add medical info' : 'Admin can add it from the app',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ]),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((p['blood_group'] as String?)?.isNotEmpty == true)
                  _MedCard(
                    icon: '🩸', label: 'Blood Group',
                    child: Text(p['blood_group'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.coral)),
                  ),
                if ((p['allergies'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _MedCard(
                    icon: '⚠️', label: 'Allergies',
                    child: Wrap(spacing: 6, runSpacing: 6, children: ((p['allergies'] as List).cast<String>()).map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600)),
                    )).toList()),
                  ),
                ],
                if ((p['ongoing_medicines'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _MedCard(
                    icon: '💊', label: 'Ongoing Medicines',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ((p['ongoing_medicines'] as List).cast<String>()).map((m) =>
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                        const Text('• ', style: TextStyle(color: AppColors.muted)),
                        Text(m, style: const TextStyle(fontSize: 13)),
                      ]))).toList()),
                  ),
                ],
                if ((p['medical_history'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _MedCard(
                    icon: '📋', label: 'Medical History',
                    child: Text(p['medical_history'] as String, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2)),
                  ),
                ],
                if ((p['emergency_notes'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _MedCard(
                    icon: '🚨', label: 'Emergency Notes',
                    child: Text(p['emergency_notes'] as String,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2, fontWeight: FontWeight.w500)),
                  ),
                ],
              ]),
            ),
    );
  }
}

class _MedCard extends StatelessWidget {
  final String icon;
  final String label;
  final Widget child;
  const _MedCard({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$icon $label', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      child,
    ]),
  );
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('Failed to load profile', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}
