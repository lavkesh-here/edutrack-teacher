import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Like count after the server confirms the toggle result. Must account for
/// both the count's state before the optimistic update (wasLiked) and the
/// server-confirmed state (nowLiked) — using only nowLiked silently cancels
/// the optimistic decrement on unlike. See test/forum_like_count_test.dart.
int nextLikeCount(int wasCount, bool wasLiked, bool nowLiked) {
  return wasCount + (nowLiked ? 1 : 0) - (wasLiked ? 1 : 0);
}

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
        key: const Key('new_announcement_fab'),
        onPressed: _showCreateSheet,
        backgroundColor: null,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: context.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
                          onCommentTap: () => _openComments(_announcements![i]),
                        ),
                      ),
      ),
    );
  }

  void _openComments(Announcement a) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _CommentsScreen(announcement: a)),
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
                    key: const Key('announcement_title_field'),
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('announcement_body_field'),
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
                        activeColor: ctx2.primary,
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
                      key: const Key('add_images_button'),
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
                      key: const Key('post_announcement_button'),
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
                                for (int i = 0; i < pickedImages.length; i++) {
                                  final img = pickedImages[i];
                                  final bytes = await img.readAsBytes();
                                  final ext = img.name.split('.').last.toLowerCase();
                                  final ct = ext == 'png' ? 'image/png' : 'image/jpeg';
                                  final urlData = await ApiClient.getAnnouncementUploadUrl(img.name, ct, bytes.length);
                                  await http.put(Uri.parse(urlData['upload_url'] as String),
                                      headers: {'Content-Type': ct}, body: bytes);
                                  await ApiClient.attachAnnouncementImage(
                                      annId, urlData['gcs_url'] as String, img.name, bytes.length, i);
                                }
                                if (mounted) Navigator.pop(ctx2);
                                _load();
                                if (mounted) showSnack(context, 'Announcement posted ✓');
                              } on ApiError catch (e) {
                                setSheet(() => saving = false);
                                if (mounted) showSnack(context, e.message, error: true);
                              } catch (_) {
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

// ── Post card ─────────────────────────────────────────────────────────────────

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
  bool _expanded = false;

  void _openImageFullscreen(List<AnnouncementImage> images, int startIndex) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final ctrl = PageController(initialPage: startIndex);
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: ctrl,
                itemCount: images.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  child: Center(
                    child: Image.network(images[i].gcsUrl, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                  ),
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
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _liked = widget.a.likedByMe;
    _likeCount = widget.a.likeCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    final wasCount = _likeCount;
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try {
      final result = await ApiClient.toggleAnnouncementLike(widget.a.id);
      final nowLiked = result['liked'] as bool? ?? !wasLiked;
      if (mounted) setState(() {
        _liked = nowLiked;
        _likeCount = nextLikeCount(wasCount, wasLiked, nowLiked);
      });
    } catch (_) {
      if (mounted) setState(() { _liked = wasLiked; _likeCount = wasCount; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final preview = a.previewComment;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: a.isPinned ? context.primary.withOpacity(0.4) : AppColors.border,
          width: a.isPinned ? 2 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + author + audience chip
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: context.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (a.authorName ?? 'T').substring(0, 1).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.primary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (a.isPinned) ...[
                          const Text('📌', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            a.authorName ?? 'Teacher',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _AudienceChip(a.audience),
                      ],
                    ),
                    Text(fmtDate(a.createdAt),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Title
          if (a.title.isNotEmpty) ...[
            Text(a.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
          ],

          // Body with Read More
          if (a.body.isNotEmpty) ...[
            Text(
              a.body,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.5),
            ),
            if (!_expanded && a.body.length > 120)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Read more',
                      style: TextStyle(fontSize: 12, color: context.primary, fontWeight: FontWeight.w600)),
                ),
              ),
          ],

          // Images strip
          if (a.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: a.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openImageFullscreen(a.images, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      a.images[i].gcsUrl,
                      width: 90, height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90, height: 90,
                        color: AppColors.bg,
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Action bar
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: _liked ? AppColors.coral : AppColors.muted,
                    ),
                    if (_likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text('$_likeCount',
                          style: TextStyle(
                              fontSize: 12,
                              color: _liked ? AppColors.coral : AppColors.muted,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              if (a.allowComments) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: widget.onCommentTap,
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 17, color: AppColors.muted),
                      if (a.commentCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('${a.commentCount}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (a.allowComments && widget.onCommentTap != null)
                GestureDetector(
                  onTap: widget.onCommentTap,
                  child: Row(
                    children: [
                      Text(
                        a.commentCount > 0 ? 'View ${a.commentCount} comment${a.commentCount == 1 ? '' : 's'}' : 'Add comment',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
            ],
          ),

          // Preview comment
          if (preview != null && a.allowComments) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.onCommentTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: AppColors.text2),
                          children: [
                            TextSpan(
                              text: '${preview['author'] ?? ''} ',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                            TextSpan(text: preview['body'] as String? ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Full-screen comments ──────────────────────────────────────────────────────

class _CommentsScreen extends StatefulWidget {
  final Announcement announcement;
  const _CommentsScreen({required this.announcement});

  @override
  State<_CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<_CommentsScreen> {
  List<AnnouncementComment> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _posting = false;
  String? _replyToId;
  String? _replyToAuthor;
  String? _replyToText;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 400;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
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
      await ApiClient.createComment(widget.announcement.id, text, parentId: _replyToId);
      _ctrl.clear();
      setState(() { _replyToId = null; _replyToAuthor = null; _replyToText = null; });
      await _load();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLevel = _comments.where((c) => c.parentId == null).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.announcement.title.isNotEmpty
            ? widget.announcement.title
            : 'Comments'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Post body preview card
          if (widget.announcement.body.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.announcement.title.isNotEmpty) ...[
                    Text(
                      widget.announcement.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    widget.announcement.body,
                    style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.45),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          if (widget.announcement.body.isNotEmpty)
            const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      _comments.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('💬', style: TextStyle(fontSize: 40)),
                                  SizedBox(height: 10),
                                  Text('No comments yet.\nBe the first!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: context.primary,
                              onRefresh: _load,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                itemCount: topLevel.length,
                                itemBuilder: (_, i) {
                                  final c = topLevel[i];
                                  final replies = _comments.where((r) => r.parentId == c.id).toList();
                                  return _CommentBlock(
                                    comment: c,
                                    replies: replies,
                                    onReply: (id, author, body) => setState(() {
                                      _replyToId = id;
                                      _replyToAuthor = author;
                                      _replyToText = body;
                                      FocusScope.of(context).requestFocus(FocusNode());
                                    }),
                                  );
                                },
                              ),
                            ),
                      if (_showBackToTop)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _scrollCtrl.animateTo(0,
                                  duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.text.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Back to top',
                                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // Reply banner with quote
          if (_replyToAuthor != null)
            Container(
              color: context.primaryLight,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: _replyToText != null ? 40 : 20,
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyToAuthor!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.primary),
                        ),
                        if (_replyToText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _replyToText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.text2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _replyToId = null; _replyToAuthor = null; _replyToText = null; }),
                    child: Icon(Icons.close, size: 16, color: context.primary),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            color: Colors.white,
            // NOT + MediaQuery.viewInsets.bottom here — the enclosing Scaffold
            // already has resizeToAvoidBottomInset:true (the default) and shrinks
            // this whole body by the keyboard height on its own. Adding it again
            // doubled the gap between the input and the keyboard (visibly a huge
            // blank strip once the keyboard opened) — reported multiple times,
            // root-caused 2026-07-26 by tracing the Scaffold's resize behavior.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('comment_field'),
                    controller: _ctrl,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: _replyToAuthor != null ? 'Write a reply…' : 'Say something…',
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
                  key: const Key('post_comment_button'),
                  onTap: _post,
                  child: Builder(builder: (ctx) => Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.primary, shape: BoxShape.circle),
                    child: _posting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment block (top-level + nested replies) ────────────────────────────────

class _CommentBlock extends StatelessWidget {
  final AnnouncementComment comment;
  final List<AnnouncementComment> replies;
  final void Function(String id, String author, String body) onReply;

  const _CommentBlock({required this.comment, required this.replies, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(comment: comment, onReply: onReply),
        ...replies.map((r) => Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _CommentTile(comment: r, onReply: onReply, isReply: true),
        )),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _CommentTile extends StatefulWidget {
  final AnnouncementComment comment;
  final void Function(String id, String author, String body) onReply;
  final bool isReply;

  const _CommentTile({required this.comment, required this.onReply, this.isReply = false});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.comment.likedByMe;
    _likeCount = widget.comment.likeCount;
  }

  Future<void> _toggleLike() async {
    final was = _liked;
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try {
      await ApiClient.toggleCommentLike(widget.comment.id);
    } catch (_) {
      if (mounted) setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: widget.isReply ? 28 : 32,
            height: widget.isReply ? 28 : 32,
            decoration: BoxDecoration(
              color: widget.isReply ? AppColors.tealLight : AppColors.skyLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (c.authorName ?? 'T').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: widget.isReply ? AppColors.teal : AppColors.sky,
                  fontSize: widget.isReply ? 12 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.authorName ?? 'Teacher',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                      ),
                      Text(fmtDate(c.createdAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(c.body, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 14,
                              color: _liked ? AppColors.coral : AppColors.muted,
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text('$_likeCount',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _liked ? AppColors.coral : AppColors.muted,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                      if (!widget.isReply) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => onReply(c.id, c.authorName ?? 'Teacher', c.body),
                          child: const Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 14, color: AppColors.muted),
                              SizedBox(width: 3),
                              Text('Reply',
                                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onReply(String id, String author, String body) => widget.onReply(id, author, body);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
