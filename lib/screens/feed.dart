import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
                                Text('No announcements yet',
                                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 15)),
                                SizedBox(height: 6),
                                Text('Tap + to post the first announcement',
                                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _announcements!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _AnnouncementCard(
                          a: _announcements![i],
                          onCommentTap: () => _showCommentsSheet(_announcements![i]),
                        ),
                      ),
      ),
    );
  }

  void _showCommentsSheet(Announcement a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(announcement: a),
    );
  }

  void _showCreateSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';
    bool isPinned = false;
    bool allowComments = false;
    final List<XFile> pickedImages = [];
    bool saving = false;

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('New Announcement',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
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
                  Row(
                    children: [
                      Switch(
                        value: allowComments,
                        activeColor: AppColors.teal,
                        onChanged: (v) => setSheet(() => allowComments = v),
                      ),
                      const Text('Allow comments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Image picker
                  const Text('Images (max 10, 5MB each)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  if (pickedImages.isNotEmpty)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pickedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<dynamic>(
                                future: pickedImages[i].readAsBytes(),
                                builder: (_, snap) => snap.hasData
                                    ? Image.memory(snap.data!, width: 72, height: 72, fit: BoxFit.cover)
                                    : const SizedBox(width: 72, height: 72),
                              ),
                            ),
                            Positioned(
                              right: 2, top: 2,
                              child: GestureDetector(
                                onTap: () => setSheet(() => pickedImages.removeAt(i)),
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (pickedImages.length < 10) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 80);
                        final toAdd = picked.take(10 - pickedImages.length).toList();
                        setSheet(() => pickedImages.addAll(toAdd));
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: Text('Add Images (${pickedImages.length}/10)'),
                    ),
                  ],

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty) return;
                              setSheet(() => saving = true);
                              try {
                                final annId = await ApiClient.createAnnouncement(
                                  title: titleCtrl.text.trim(),
                                  body: bodyCtrl.text.trim(),
                                  audience: audience,
                                  isPinned: isPinned,
                                  allowComments: allowComments,
                                );

                                // Upload images
                                for (int i = 0; i < pickedImages.length; i++) {
                                  final img = pickedImages[i];
                                  final bytes = await img.readAsBytes();
                                  final ext = img.name.split('.').last.toLowerCase();
                                  final ct = ext == 'png' ? 'image/png' : 'image/jpeg';

                                  final urlData = await ApiClient.getAnnouncementUploadUrl(
                                      img.name, ct, bytes.length);
                                  final uploadUrl = urlData['upload_url'] as String;
                                  final gcsUrl = urlData['gcs_url'] as String;

                                  await http.put(Uri.parse(uploadUrl),
                                      headers: {'Content-Type': ct}, body: bytes);
                                  await ApiClient.attachAnnouncementImage(
                                      annId, gcsUrl, img.name, bytes.length, i);
                                }

                                if (mounted) Navigator.pop(ctx2);
                                _load();
                                if (mounted) showSnack(context, 'Announcement posted ✓');
                              } on ApiError catch (e) {
                                setSheet(() => saving = false);
                                if (mounted) showSnack(context, e.message, error: true);
                              } catch (e) {
                                setSheet(() => saving = false);
                                if (mounted) showSnack(context, 'Could not post announcement', error: true);
                              }
                            },
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Post Announcement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final Announcement a;
  final VoidCallback? onCommentTap;
  const _AnnouncementCard({required this.a, this.onCommentTap});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.a.likedByMe;
    _likeCount = widget.a.likeCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      await ApiClient.toggleAnnouncementLike(widget.a.id);
    } catch (_) {
      if (mounted) setState(() { _liked = wasLiked; _likeCount += wasLiked ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
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

          // Images strip
          if (a.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: a.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    a.images[i].gcsUrl,
                    width: 80, height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80, height: 80,
                      color: AppColors.bg,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Text(fmtDate(a.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              if (a.authorName != null) ...[
                const Text(' · ', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                Text(a.authorName!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
              const Spacer(),
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 15,
                      color: _liked ? AppColors.coral : AppColors.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$_likeCount',
                      style: TextStyle(
                          fontSize: 11,
                          color: _liked ? AppColors.coral : AppColors.muted,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (a.allowComments) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onCommentTap,
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${a.commentCount}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Announcement announcement;
  const _CommentsSheet({required this.announcement});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<AnnouncementComment> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getComments(widget.announcement.id);
      setState(() { _comments = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ApiClient.createComment(widget.announcement.id, text);
      _ctrl.clear();
      await _load();
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                const Spacer(),
                Text('${_comments.length}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet.\nBe the first!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 13)))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c.authorName ?? 'Teacher',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    const Spacer(),
                                    Text(fmtDate(c.createdAt),
                                        style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c.body, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _post,
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                    child: _posting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
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
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
        child: Text(
          audience[0].toUpperCase() + audience.substring(1),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _color),
        ),
      );
}
