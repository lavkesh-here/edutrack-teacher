import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Announcement>? _announcements;
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
      final list = await ApiClient.getAnnouncements();
      setState(() { _announcements = list; _loading = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load announcements'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Forum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            color: AppColors.muted,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.sun,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.sun,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _announcements == null || _announcements!.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Text('📢', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text(
                                  'No announcements yet',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tap + to post the first announcement',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _announcements!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _AnnouncementCard(a: _announcements![i]),
                      ),
      ),
    );
  }

  void _showCreateSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';
    bool isPinned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Announcement',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Audience:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: audience,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Everyone')),
                          DropdownMenuItem(value: 'teachers', child: Text('Teachers')),
                          DropdownMenuItem(value: 'students', child: Text('Students')),
                          DropdownMenuItem(value: 'parents', child: Text('Parents')),
                        ],
                        onChanged: (v) => setSheet(() => audience = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: isPinned,
                      activeColor: AppColors.sun,
                      onChanged: (v) => setSheet(() => isPinned = v),
                    ),
                    const Text('Pin this announcement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      try {
                        await ApiClient.createAnnouncement(
                          title: titleCtrl.text.trim(),
                          body: bodyCtrl.text.trim(),
                          audience: audience,
                          isPinned: isPinned,
                        );
                        if (mounted) Navigator.pop(ctx2);
                        _load();
                        if (mounted) showSnack(context, 'Announcement posted ✓');
                      } on ApiError catch (e) {
                        if (mounted) showSnack(context, e.message, error: true);
                      }
                    },
                    child: const Text('Post Announcement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  const _AnnouncementCard({required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: a.isPinned ? AppColors.sun.withOpacity(0.4) : AppColors.border,
          width: a.isPinned ? 2 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (a.isPinned) ...[
                const Text('📌', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              _AudienceChip(a.audience),
            ],
          ),
          if (a.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              a.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            fmtDate(a.createdAt),
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String audience;
  const _AudienceChip(this.audience);

  Color get _color {
    switch (audience) {
      case 'teachers': return AppColors.violet;
      case 'students': return AppColors.sky;
      case 'parents': return AppColors.teal;
      default: return AppColors.sun;
    }
  }

  Color get _bg {
    switch (audience) {
      case 'teachers': return AppColors.violetLight;
      case 'students': return AppColors.skyLight;
      case 'parents': return AppColors.tealLight;
      default: return AppColors.sunLight;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          audience[0].toUpperCase() + audience.substring(1),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _color),
        ),
      );
}
