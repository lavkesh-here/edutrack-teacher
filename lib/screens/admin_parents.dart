import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminParentsScreen extends StatefulWidget {
  const AdminParentsScreen({super.key});

  @override
  State<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends State<AdminParentsScreen> {
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListParents();
      setState(() {
        _parents = data;
        _applyFilter();
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_parents);
      } else {
        _filtered = _parents.where((p) {
          final name = (p['name'] as String? ?? '').toLowerCase();
          final phone = (p['phone'] as String? ?? '').toLowerCase();
          return name.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  void _showParentDetail(Map<String, dynamic> parent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParentDetailSheet(
        parent: parent,
        onResetPassword: () => _resetPassword(parent['id'] as int),
      ),
    );
  }

  Future<void> _resetPassword(int parentId) async {
    try {
      final tempPass = await ApiClient.adminResetParentPassword(parentId);
      if (mounted) _showTempPasswordDialog(tempPass, 'Password Reset');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showTempPasswordDialog(String password, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this temporary password with the parent. They will be asked to change it on first login.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: password));
                if (mounted) showSnack(context, 'Copied to clipboard');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        password,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const Icon(Icons.copy, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to copy',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: AppColors.sun, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddParentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddParentSheet(
        onCreated: (pass) {
          _load();
          _showTempPasswordDialog(pass, 'Parent Created');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Parent Accounts'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddParentSheet,
        backgroundColor: AppColors.sun,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Parent', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: Icon(Icons.search, color: AppColors.muted, size: 20),
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👨‍👩‍👦', style: TextStyle(fontSize: 44)),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isEmpty ? 'No parents yet' : 'No results',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add a parent using the button below',
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.sun,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ParentRow(
                            parent: _filtered[i],
                            onTap: () => _showParentDetail(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ParentRow extends StatelessWidget {
  final Map<String, dynamic> parent;
  final VoidCallback onTap;

  const _ParentRow({required this.parent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = parent['name'] as String? ?? '';
    final phone = parent['phone'] as String? ?? '';
    final email = parent['email'] as String?;
    final children = parent['children'] as List<dynamic>? ?? [];
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.tealLight,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  if (email != null && email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.skyLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${children.length} child${children.length == 1 ? '' : 'ren'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sky,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Parent Detail Bottom Sheet ────────────────────────────────────────────────

class _ParentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> parent;
  final Future<void> Function() onResetPassword;

  const _ParentDetailSheet({required this.parent, required this.onResetPassword});

  @override
  State<_ParentDetailSheet> createState() => _ParentDetailSheetState();
}

class _ParentDetailSheetState extends State<_ParentDetailSheet> {
  bool _resetting = false;

  Future<void> _doReset() async {
    setState(() => _resetting = true);
    Navigator.pop(context);
    await widget.onResetPassword();
    if (mounted) setState(() => _resetting = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final name = p['name'] as String? ?? '';
    final phone = p['phone'] as String? ?? '';
    final email = p['email'] as String?;
    final children = p['children'] as List<dynamic>? ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Parent Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('✕', style: TextStyle(fontSize: 22, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info
                    _InfoRow(icon: Icons.person_outline, label: name),
                    _InfoRow(icon: Icons.phone_outlined, label: phone),
                    if (email != null && email.isNotEmpty)
                      _InfoRow(icon: Icons.email_outlined, label: email),
                    const SizedBox(height: 16),
                    // Children
                    const Text(
                      'LINKED CHILDREN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (children.isEmpty)
                      const Text(
                        'No children linked yet.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      )
                    else
                      ...children.map((c) {
                        final child = c as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Text('👦', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      child['name'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    Text(
                                      child['class_label'] as String? ?? '',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                    // Reset password
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _resetting ? null : _doReset,
                        icon: _resetting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                              )
                            : const Icon(Icons.lock_reset, size: 18, color: AppColors.coral),
                        label: Text(
                          _resetting ? 'Resetting...' : 'Reset Password',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.coral,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.coral),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Parent Bottom Sheet ───────────────────────────────────────────────────

class _AddParentSheet extends StatefulWidget {
  final void Function(String tempPassword) onCreated;

  const _AddParentSheet({required this.onCreated});

  @override
  State<_AddParentSheet> createState() => _AddParentSheetState();
}

class _AddParentSheetState extends State<_AddParentSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      showSnack(context, 'Name and phone are required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ApiClient.adminCreateParent(
        name: name,
        phone: phone,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (mounted) {
        final tempPass = result['temp_password'] as String? ?? '';
        Navigator.pop(context);
        widget.onCreated(tempPass);
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Add Parent',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('✕', style: TextStyle(fontSize: 22, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('FULL NAME *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'e.g. Ramesh Kumar'),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('PHONE NUMBER *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'e.g. 9876543210'),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('EMAIL (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: 'e.g. ramesh@email.com'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Create Parent Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.muted,
          letterSpacing: 0.5,
        ),
      );
}
