import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';

class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  List<StaffDirectoryEntry> _staff = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final staff = await ApiClient.getStaffDirectory();
      if (mounted) setState(() { _staff = staff; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load staff directory'; _loading = false; });
    }
  }

  List<StaffDirectoryEntry> get _filtered {
    if (_search.isEmpty) return _staff;
    final q = _search.toLowerCase();
    return _staff.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.role.toLowerCase().contains(q) ||
        s.functionalTags.any((t) => t.toLowerCase().contains(q))).toList();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _emailStaff(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: AppColors.text),
        title: const Text('Staff Directory',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, role, or tag...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('No staff found', style: TextStyle(color: AppColors.muted)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _StaffRow(
                                staff: _filtered[i],
                                onCall: _callPhone,
                                onEmail: _emailStaff,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffDirectoryEntry staff;
  final void Function(String phone) onCall;
  final void Function(String email) onEmail;

  const _StaffRow({required this.staff, required this.onCall, required this.onEmail});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'director': return 'Director';
      case 'principal': return 'Principal';
      case 'hod': return 'HOD';
      default: return 'Teacher';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: (staff.profilePhotoUrl != null && staff.profilePhotoUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: staff.profilePhotoUrl!,
                      width: 44, height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(_initials(staff.name),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                      ),
                    )
                  : Center(
                      child: Text(_initials(staff.name),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(_roleLabel(staff.role),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                if (staff.functionalTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: staff.functionalTags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              if (staff.phone != null && staff.phone!.isNotEmpty)
                IconButton(
                  tooltip: 'Call ${staff.name}',
                  onPressed: () => onCall(staff.phone!),
                  icon: const Icon(Icons.call_rounded, size: 20, color: AppColors.green),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                tooltip: 'Email ${staff.name}',
                onPressed: () => onEmail(staff.email),
                icon: const Icon(Icons.email_outlined, size: 20, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
