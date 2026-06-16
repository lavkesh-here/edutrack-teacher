import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminAttendersScreen extends StatefulWidget {
  const AdminAttendersScreen({super.key});

  @override
  State<AdminAttendersScreen> createState() => _AdminAttendersScreenState();
}

class _AdminAttendersScreenState extends State<AdminAttendersScreen> {
  List<Map<String, dynamic>> _attenders = [];
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
      final data = await ApiClient.adminListAttenders();
      setState(() {
        _attenders = data;
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
        _filtered = List.from(_attenders);
      } else {
        _filtered = _attenders.where((a) {
          final attenderName = (a['attender_name'] as String? ?? a['name'] as String? ?? '').toLowerCase();
          final studentName = (a['student_name'] as String? ?? '').toLowerCase();
          return attenderName.contains(q) || studentName.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Attenders'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by attender or student name...',
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
                            const Text('👤', style: TextStyle(fontSize: 44)),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isEmpty ? 'No attenders found' : 'No results',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.sun,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _AttenderRow(attender: _filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AttenderRow extends StatefulWidget {
  final Map<String, dynamic> attender;
  const _AttenderRow({required this.attender});

  @override
  State<_AttenderRow> createState() => _AttenderRowState();
}

class _AttenderRowState extends State<_AttenderRow> {
  late bool _flagged;

  @override
  void initState() {
    super.initState();
    _flagged = widget.attender['is_flagged'] as bool? ?? false;
  }

  Future<void> _toggleFlag() async {
    final next = !_flagged;
    setState(() => _flagged = next);
    try {
      await ApiClient.adminFlagAttender(widget.attender['id'].toString(), isFlagged: next);
    } on ApiError catch (e) {
      setState(() => _flagged = !next);
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      setState(() => _flagged = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.attender['attender_name'] as String? ?? widget.attender['name'] as String? ?? '';
    final relation = widget.attender['relation'] as String? ?? widget.attender['relation_type'] as String? ?? '';
    final phone = widget.attender['phone'] as String? ?? '';
    final studentName = widget.attender['student_name'] as String? ?? '';
    final classLabel = widget.attender['class_label'] as String? ?? '';
    final photoUrl = widget.attender['photo_url'] as String?;

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _flagged ? AppColors.coralLight : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          photoUrl != null && photoUrl.isNotEmpty
              ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(photoUrl))
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: _flagged ? AppColors.coral.withOpacity(0.2) : AppColors.coralLight,
                  child: Text(initials,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                          color: _flagged ? AppColors.coral : AppColors.coral)),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ),
                    if (relation.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.violetLight, borderRadius: BorderRadius.circular(20)),
                        child: Text(_capitalise(relation),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.violet)),
                      ),
                  ],
                ),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(studentName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text2)),
                    if (classLabel.isNotEmpty) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.muted)),
                      Text(classLabel, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_flagged ? Icons.flag : Icons.flag_outlined,
                color: _flagged ? AppColors.coral : AppColors.muted, size: 20),
            tooltip: _flagged ? 'Unflag attender' : 'Flag as suspicious',
            onPressed: _toggleFlag,
          ),
        ],
      ),
    );
  }

  String _capitalise(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
