import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'my_students.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Library Management Screen
// Access: admin/principal/director roles OR teacher with 'librarian' tag
// ─────────────────────────────────────────────────────────────────────────────

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Books'),
              Tab(text: 'Issues'),
              Tab(text: 'Stats'),
            ],
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.muted,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        body: const TabBarView(
          children: [
            _BooksTab(),
            _IssuesTab(),
            _StatsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Books Tab ────────────────────────────────────────────────────────────────

class _BooksTab extends StatefulWidget {
  const _BooksTab();

  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;
  String? _filterType;
  bool _availableOnly = false;
  int _page = 0;
  int _total = 0;
  static const _pageSize = 25;

  final _bookTypes = ['textbook', 'reference', 'fiction', 'non_fiction', 'magazine', 'newspaper', 'other'];

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

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _page = 0; _books = []; });
    setState(() => _loading = true);
    try {
      final data = await ApiClient.libraryListBooks(
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        bookType: _filterType,
        availableOnly: _availableOnly,
        page: _page,
        pageSize: _pageSize,
      );
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _books = reset ? items : [..._books, ...items];
        _total = data['total'] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showSnack(context, e is ApiError ? e.message : 'Failed to load books', error: true);
    }
  }

  void _showAddEditSheet({Map<String, dynamic>? book}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BookFormSheet(
        book: book,
        onSaved: () => _load(reset: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: p,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search title, author, ISBN…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _load(reset: true); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _load(reset: true),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Available only',
                        selected: _availableOnly,
                        onTap: () { setState(() => _availableOnly = !_availableOnly); _load(reset: true); },
                      ),
                      const SizedBox(width: 6),
                      ..._bookTypes.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: _bookTypeLabel(t),
                          selected: _filterType == t,
                          onTap: () { setState(() => _filterType = _filterType == t ? null : t); _load(reset: true); },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _books.isEmpty
                ? Center(child: CircularProgressIndicator(color: p))
                : _books.isEmpty
                    ? const Center(child: Text('No books found', style: TextStyle(color: AppColors.muted)))
                    : RefreshIndicator(
                        color: p,
                        onRefresh: () => _load(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          itemCount: _books.length + (_books.length < _total ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _books.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () { setState(() => _page++); _load(); },
                                    child: Text('Load more', style: TextStyle(color: p, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              );
                            }
                            return _BookCard(
                              book: _books[i],
                              onEdit: () => _showAddEditSheet(book: _books[i]),
                              onRefresh: () => _load(reset: true),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  const _BookCard({required this.book, required this.onEdit, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final available = (book['available_copies'] as int?) ?? 0;
    final total = (book['total_copies'] as int?) ?? 0;
    final isOut = available == 0;
    final isLow = available > 0 && available <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 60,
                decoration: BoxDecoration(
                  color: AppColors.violetLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('📚', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (book['author'] != null)
                      Text(book['author'], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _MiniChip(_bookTypeLabel(book['book_type'] ?? 'general'), AppColors.skyLight, AppColors.sky),
                        if (book['shelf_location'] != null)
                          _MiniChip('📍 ${book['shelf_location']}', AppColors.amberLight, AppColors.amber),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOut ? AppColors.coralLight : isLow ? AppColors.amberLight : AppColors.greenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$available/$total',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: isOut ? AppColors.coral : isLow ? AppColors.amber : AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(isOut ? 'Out of stock' : isLow ? 'Low stock' : 'Available',
                      style: TextStyle(fontSize: 10, color: isOut ? AppColors.coral : isLow ? AppColors.amber : AppColors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Issues Tab ──────────────────────────────────────────────────────────────

class _IssuesTab extends StatefulWidget {
  const _IssuesTab();

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab> {
  List<Map<String, dynamic>> _issues = [];
  bool _loading = true;
  String _statusFilter = 'all';
  bool _overdueOnly = false;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _page = 0; _issues = []; });
    setState(() => _loading = true);
    try {
      final data = await ApiClient.libraryListIssues(
        status: _statusFilter == 'all' ? null : _statusFilter,
        overdueOnly: _overdueOnly,
        page: _page,
      );
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _issues = reset ? items : [..._issues, ...items];
        _total = data['total'] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showSnack(context, e is ApiError ? e.message : 'Failed to load', error: true);
    }
  }

  void _showIssueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _IssueBookSheet(onIssued: () => _load(reset: true)),
    );
  }

  Future<void> _returnBook(String issueId) async {
    try {
      final result = await ApiClient.libraryReturnBook(issueId);
      final fine = result['fine_amount_due'];
      if (mounted) {
        showSnack(context, fine != null && fine > 0 ? 'Book returned. Fine due: ₹$fine' : 'Book returned successfully');
        _load(reset: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e is ApiError ? e.message : 'Return failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showIssueSheet,
        backgroundColor: p,
        icon: const Icon(Icons.book_outlined, color: Colors.white),
        label: const Text('Issue Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Overdue only',
                    selected: _overdueOnly,
                    onTap: () { setState(() => _overdueOnly = !_overdueOnly); _load(reset: true); },
                    activeColor: AppColors.coral,
                  ),
                  const SizedBox(width: 6),
                  ...['all', 'issued', 'overdue', 'returned', 'lost'].map((s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: _statusLabel(s),
                      selected: _statusFilter == s,
                      onTap: () { setState(() => _statusFilter = s); _load(reset: true); },
                    ),
                  )),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading && _issues.isEmpty
                ? Center(child: CircularProgressIndicator(color: p))
                : _issues.isEmpty
                    ? const Center(child: Text('No issues found', style: TextStyle(color: AppColors.muted)))
                    : RefreshIndicator(
                        color: p,
                        onRefresh: () => _load(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          itemCount: _issues.length,
                          itemBuilder: (_, i) => _IssueCard(
                            issue: _issues[i],
                            onReturn: () => _returnBook(_issues[i]['id'].toString()),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final Map<String, dynamic> issue;
  final VoidCallback onReturn;

  const _IssueCard({required this.issue, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final status = issue['status'] as String? ?? 'issued';
    final isOverdue = status == 'overdue';
    final isReturned = status == 'returned';
    final isLost = status == 'lost';
    final fine = issue['fine_amount_due'];
    final hasFine = fine != null && (fine is num) && fine > 0;

    final statusColor = isOverdue ? AppColors.coral : isReturned ? AppColors.teal : isLost ? AppColors.muted : AppColors.sky;
    final statusBg = isOverdue ? AppColors.coralLight : isReturned ? AppColors.tealLight : isLost ? AppColors.border : AppColors.skyLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? AppColors.coral.withOpacity(0.3) : AppColors.border,
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(issue['book_title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(status).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${issue['student_name'] ?? 'Unknown'} · ${issue['class_section'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              _DateChip('Issued', issue['issued_date'] as String?),
              const SizedBox(width: 8),
              _DateChip('Due', issue['due_date'] as String?, highlight: isOverdue),
              if (isReturned && issue['returned_date'] != null) ...[
                const SizedBox(width: 8),
                _DateChip('Returned', issue['returned_date'] as String?),
              ],
            ],
          ),
          if (hasFine) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️ Fine due: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.coral)),
                  Text('₹$fine', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.coral)),
                ],
              ),
            ),
          ],
          if (!isReturned && !isLost) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReturn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Mark Returned', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String? date;
  final bool highlight;
  const _DateChip(this.label, this.date, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: highlight ? AppColors.coralLight : AppColors.bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: highlight ? AppColors.coral.withOpacity(0.3) : AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: highlight ? AppColors.coral : AppColors.muted)),
        Text(date ?? '—', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? AppColors.coral : AppColors.text)),
      ],
    ),
  );
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.libraryStats();
      setState(() { _stats = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    if (_loading) return Center(child: CircularProgressIndicator(color: p));
    if (_stats == null) return const Center(child: Text('Failed to load stats', style: TextStyle(color: AppColors.muted)));

    final topBooks = (_stats!['top_5_issued_books'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final byType = (_stats!['by_type'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: p,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('COLLECTION OVERVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard('Total Books', '${_stats!['total_books'] ?? 0}', '📚', AppColors.violet, AppColors.violetLight),
                _StatCard('Total Copies', '${_stats!['total_copies'] ?? 0}', '📖', AppColors.sky, AppColors.skyLight),
                _StatCard('Available', '${_stats!['available_copies'] ?? 0}', '✅', AppColors.teal, AppColors.tealLight),
                _StatCard('Currently Issued', '${_stats!['total_issued'] ?? 0}', '📤', AppColors.amber, AppColors.amberLight),
                _StatCard('Overdue', '${_stats!['overdue_count'] ?? 0}', '⚠️', AppColors.coral, AppColors.coralLight),
                _StatCard('Lost', '${_stats!['lost_count'] ?? 0}', '❌', AppColors.rose, AppColors.border),
              ],
            ),
            const SizedBox(height: 20),
            if (topBooks.isNotEmpty) ...[
              const Text('MOST ISSUED BOOKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
              const SizedBox(height: 10),
              ...topBooks.asMap().entries.map((e) {
                final b = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: p.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: p))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (b['author'] != null) Text(b['author'], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Text('${b['issue_count']} issues', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
            if (byType.isNotEmpty) ...[
              const Text('BY CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
              const SizedBox(height: 10),
              ...byType.map((t) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text(_bookTypeLabel(t['book_type'] ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_stats!['total_books'] ?? 0) > 0 ? (t['count'] as int) / (_stats!['total_books'] as int) : 0,
                          backgroundColor: AppColors.border,
                          color: p,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${t['count']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;
  final Color bg;

  const _StatCard(this.label, this.value, this.icon, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1.5)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16)))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );
}

// ─── Book Form Sheet ─────────────────────────────────────────────────────────

class _BookFormSheet extends StatefulWidget {
  final Map<String, dynamic>? book;
  final VoidCallback onSaved;

  const _BookFormSheet({this.book, required this.onSaved});

  @override
  State<_BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends State<_BookFormSheet> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  final _copiesCtrl = TextEditingController(text: '1');
  final _subjectCtrl = TextEditingController();
  String _bookType = 'general';
  String _language = 'English';
  bool _saving = false;

  final _types = ['general', 'textbook', 'reference', 'fiction', 'non_fiction', 'magazine', 'newspaper', 'other'];
  final _langs = ['English', 'Hindi', 'Sanskrit', 'Marathi', 'Tamil', 'Telugu', 'Kannada', 'Other'];

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    if (b != null) {
      _titleCtrl.text = b['title'] ?? '';
      _authorCtrl.text = b['author'] ?? '';
      _isbnCtrl.text = b['isbn'] ?? '';
      _publisherCtrl.text = b['publisher'] ?? '';
      _shelfCtrl.text = b['shelf_location'] ?? '';
      _copiesCtrl.text = '${b['total_copies'] ?? 1}';
      _subjectCtrl.text = b['subject'] ?? '';
      _bookType = b['book_type'] ?? 'general';
      _language = b['language'] ?? 'English';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _authorCtrl.dispose(); _isbnCtrl.dispose();
    _publisherCtrl.dispose(); _shelfCtrl.dispose(); _copiesCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) { showSnack(context, 'Title is required', error: true); return; }
    final copies = int.tryParse(_copiesCtrl.text.trim()) ?? 0;
    if (copies < 1) { showSnack(context, 'At least 1 copy required', error: true); return; }

    setState(() => _saving = true);
    try {
      final payload = {
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        'isbn': _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
        'publisher': _publisherCtrl.text.trim().isEmpty ? null : _publisherCtrl.text.trim(),
        'shelf_location': _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
        'total_copies': copies,
        'subject': _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        'book_type': _bookType,
        'language': _language,
      };
      if (widget.book != null) {
        await ApiClient.libraryUpdateBook(widget.book!['id'].toString(), payload);
      } else {
        await ApiClient.libraryAddBook(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showSnack(context, widget.book != null ? 'Book updated' : 'Book added to library');
      }
    } catch (e) {
      if (mounted) { showSnack(context, e is ApiError ? e.message : 'Save failed', error: true); }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.book != null ? 'Edit Book' : 'Add Book', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 16),
            _Field('Title *', _titleCtrl),
            _Field('Author', _authorCtrl),
            _Field('ISBN', _isbnCtrl, keyboard: TextInputType.number),
            _Field('Publisher', _publisherCtrl),
            _Field('Shelf Location', _shelfCtrl, hint: 'e.g. A-3, Shelf 2'),
            _Field('Total Copies', _copiesCtrl, keyboard: TextInputType.number),
            _Field('Subject (for textbooks)', _subjectCtrl),
            const SizedBox(height: 10),
            _DropdownRow('Type', _bookType, _types, _bookTypeLabel, (v) => setState(() => _bookType = v!)),
            const SizedBox(height: 10),
            _DropdownRow('Language', _language, _langs, (s) => s, (v) => setState(() => _language = v!)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(widget.book != null ? 'Save Changes' : 'Add Book', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Issue Book Sheet ─────────────────────────────────────────────────────────

class _IssueBookSheet extends StatefulWidget {
  final VoidCallback onIssued;
  const _IssueBookSheet({required this.onIssued});

  @override
  State<_IssueBookSheet> createState() => _IssueBookSheetState();
}

class _IssueBookSheetState extends State<_IssueBookSheet> {
  final _bookSearchCtrl = TextEditingController();
  final _studentSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _bookResults = [];
  List<Map<String, dynamic>> _studentResults = [];
  Map<String, dynamic>? _selectedBook;
  Map<String, dynamic>? _selectedStudent;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _issuing = false;
  bool _searchingBooks = false;
  bool _searchingStudents = false;

  Future<void> _searchBooks(String q) async {
    if (q.length < 2) { setState(() => _bookResults = []); return; }
    setState(() => _searchingBooks = true);
    try {
      final data = await ApiClient.libraryListBooks(search: q, availableOnly: true);
      setState(() { _bookResults = (data['items'] as List).cast<Map<String, dynamic>>(); _searchingBooks = false; });
    } catch (_) { setState(() => _searchingBooks = false); }
  }

  Future<void> _searchStudents(String q) async {
    if (q.length < 2) { setState(() => _studentResults = []); return; }
    setState(() => _searchingStudents = true);
    try {
      final results = await ApiClient.librarySearchStudents(q);
      setState(() { _studentResults = results; _searchingStudents = false; });
    } catch (_) { setState(() => _searchingStudents = false); }
  }

  Future<void> _issue() async {
    if (_selectedBook == null) { showSnack(context, 'Select a book', error: true); return; }
    if (_selectedStudent == null) { showSnack(context, 'Select a student', error: true); return; }
    setState(() => _issuing = true);
    try {
      await ApiClient.libraryIssueBook(
        bookId: _selectedBook!['id'].toString(),
        studentId: _selectedStudent!['id'].toString(),
        dueDate: _dueDate.toIso8601String().split('T')[0],
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onIssued();
        showSnack(context, 'Book issued to ${_selectedStudent!['name']}');
      }
    } catch (e) {
      if (mounted) showSnack(context, e is ApiError ? e.message : 'Issue failed', error: true);
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Issue Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 16),

            // Book search
            const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(height: 6),
            if (_selectedBook != null)
              _SelectedChip(
                label: _selectedBook!['title'],
                sub: '${_selectedBook!['available_copies']} copies available',
                onClear: () => setState(() { _selectedBook = null; _bookSearchCtrl.clear(); _bookResults = []; }),
              )
            else ...[
              TextField(
                controller: _bookSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search available books…',
                  prefixIcon: _searchingBooks ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: _searchBooks,
              ),
              if (_bookResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: _bookResults.take(5).map((b) => ListTile(
                      dense: true,
                      title: Text(b['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text('${b['author'] ?? ''} · ${b['available_copies']} available', style: const TextStyle(fontSize: 11)),
                      onTap: () => setState(() { _selectedBook = b; _bookResults = []; _bookSearchCtrl.clear(); }),
                    )).toList(),
                  ),
                ),
            ],

            const SizedBox(height: 14),

            // Student search
            const Text('Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(height: 6),
            if (_selectedStudent != null)
              _SelectedChip(
                label: _selectedStudent!['name'],
                sub: _selectedStudent!['class_section'] ?? '',
                onClear: () => setState(() { _selectedStudent = null; _studentSearchCtrl.clear(); _studentResults = []; }),
              )
            else ...[
              TextField(
                controller: _studentSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search student name or ID…',
                  prefixIcon: _searchingStudents ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: _searchStudents,
              ),
              if (_studentResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: _studentResults.take(5).map((s) => ListTile(
                      dense: true,
                      title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text(s['class_section'] ?? '', style: const TextStyle(fontSize: 11)),
                      onTap: () => setState(() { _selectedStudent = s; _studentResults = []; _studentSearchCtrl.clear(); }),
                    )).toList(),
                  ),
                ),
            ],

            const SizedBox(height: 14),

            // Due date
            const Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: p),
                    const SizedBox(width: 10),
                    Text(
                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const Spacer(),
                    Text('${_dueDate.difference(DateTime.now()).inDays} days', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _issuing ? null : _issue,
                child: _issuing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Issue Book', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Student Library Tab (embedded in student profile) ───────────────────────

class StudentLibraryTab extends StatefulWidget {
  final String studentId;
  const StudentLibraryTab({super.key, required this.studentId});

  @override
  State<StudentLibraryTab> createState() => _StudentLibraryTabState();
}

class _StudentLibraryTabState extends State<StudentLibraryTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.libraryStudentBooks(widget.studentId);
      setState(() { _data = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    if (_loading) return Center(child: CircularProgressIndicator(color: p));
    if (_data == null) return const Center(child: Text('Unable to load library data', style: TextStyle(color: AppColors.muted)));

    final current = (_data!['current_issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final history = (_data!['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: p,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (current.isNotEmpty) ...[
            const Text('CURRENTLY ISSUED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...current.map((b) => _StudentBookCard(book: b)),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: const Center(child: Text('No books currently issued', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
            ),
          if (history.isNotEmpty) ...[
            const Text('RETURN HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...history.map((b) => _StudentBookCard(book: b, isHistory: true)),
          ],
        ],
      ),
    );
  }
}

class _StudentBookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool isHistory;
  const _StudentBookCard({required this.book, this.isHistory = false});

  @override
  Widget build(BuildContext context) {
    final status = book['status'] as String? ?? 'issued';
    final isOverdue = status == 'overdue';
    final fine = book['fine_amount_due'];
    final hasFine = fine != null && (fine is num) && fine > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOverdue ? AppColors.coral.withOpacity(0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['book_title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (book['book_author'] != null) Text(book['book_author'], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              if (isHistory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'lost' ? AppColors.border : AppColors.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'lost' ? 'LOST' : 'RETURNED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: status == 'lost' ? AppColors.muted : AppColors.teal),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DateChip('Issued', book['issued_date'] as String?),
              const SizedBox(width: 6),
              _DateChip('Due', book['due_date'] as String?, highlight: isOverdue),
              if (book['returned_date'] != null) ...[
                const SizedBox(width: 6),
                _DateChip('Returned', book['returned_date'] as String?),
              ],
            ],
          ),
          if (isOverdue && hasFine) ...[
            const SizedBox(height: 8),
            Text('⚠️ Fine due: ₹$fine', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.coral)),
          ],
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? color : AppColors.muted)),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _MiniChip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onClear;
  const _SelectedChip({required this.label, required this.sub, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: p.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11, color: p.withOpacity(0.7))),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.close, size: 18, color: p), onPressed: onClear, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final String? hint;

  const _Field(this.label, this.ctrl, {this.keyboard, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}

Widget _DropdownRow(String label, String value, List<String> options, String Function(String) toLabel, void Function(String?) onChanged) {
  return Row(
    children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted))),
      Expanded(
        child: DropdownButtonFormField<String>(
          value: value,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(toLabel(o), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    ],
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _bookTypeLabel(String t) {
  switch (t) {
    case 'textbook': return 'Textbook';
    case 'reference': return 'Reference';
    case 'fiction': return 'Fiction';
    case 'non_fiction': return 'Non-Fiction';
    case 'magazine': return 'Magazine';
    case 'newspaper': return 'Newspaper';
    case 'other': return 'Other';
    default: return 'General';
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'issued': return 'Issued';
    case 'returned': return 'Returned';
    case 'overdue': return 'Overdue';
    case 'lost': return 'Lost';
    default: return 'All';
  }
}
