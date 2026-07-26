import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/motivation.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  List<TodoItem>? _todos;
  bool _loading = true;
  String _quote = Motivation.random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final todos = await ApiClient.getTodos();
      if (mounted) {
        setState(() {
          _todos = todos;
          _loading = false;
          _quote = Motivation.random(exclude: _quote);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, 'Failed to load todos', error: true);
      }
    }
  }

  Future<void> _setStatus(TodoItem todo, String newStatus) async {
    try {
      await ApiClient.updateTodo(todo.id, status: newStatus);
      await _load();
      if (mounted) {
        final msg = switch (newStatus) {
          'in_progress' => 'Moved to In Progress',
          'done' => 'Marked as Done ✓',
          _ => 'Moved to To Do',
        };
        showSnack(context, msg);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Update failed', error: true);
    }
  }

  Future<void> _delete(TodoItem todo) async {
    try {
      await ApiClient.deleteTodo(todo.id);
      await _load();
      if (mounted) showSnack(context, 'Deleted');
    } catch (_) {
      if (mounted) showSnack(context, 'Delete failed', error: true);
    }
  }

  void _showStatusSheet(TodoItem todo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            Text(todo.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            const Text('Update status', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            _StatusOption(
              label: 'To Do',
              color: AppColors.muted,
              bgColor: const Color(0xFFF3F4F6),
              selected: todo.status == 'todo',
              onTap: () { Navigator.pop(context); _setStatus(todo, 'todo'); },
            ),
            const SizedBox(height: 8),
            _StatusOption(
              label: 'In Progress',
              color: const Color(0xFFB45309),
              bgColor: const Color(0xFFFEF3C7),
              selected: todo.status == 'in_progress',
              onTap: () { Navigator.pop(context); _setStatus(todo, 'in_progress'); },
            ),
            const SizedBox(height: 8),
            _StatusOption(
              label: 'Done',
              color: AppColors.teal,
              bgColor: const Color(0xFFD1FAE5),
              selected: todo.status == 'done',
              onTap: () { Navigator.pop(context); _setStatus(todo, 'done'); },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? dueDate;
    bool isPersonal = false;
    String? titleError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
              const Text('New Todo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 14),
              TextField(
                key: const Key('todo_title_field'),
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) { if (titleError != null) setSheet(() => titleError = null); },
                decoration: InputDecoration(
                  labelText: 'Title *',
                  errorText: titleError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('todo_notes_field'),
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(dueDate == null
                          ? 'Due date'
                          : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSheet(() => dueDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isPersonal,
                        onChanged: (v) => setSheet(() => isPersonal = v ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      const Text('Personal', style: TextStyle(fontSize: 13, color: AppColors.text)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('add_todo_button'),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      setSheet(() => titleError = 'Please enter a title');
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.createTodo(
                        title: title,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        dueDate: dueDate != null
                            ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
                            : null,
                        isPersonal: isPersonal,
                      );
                      await _load();
                      if (mounted) showSnack(context, 'Todo added ✓');
                    } catch (_) {
                      if (mounted) showSnack(context, 'Create failed', error: true);
                    }
                  },
                  child: const Text('Add Todo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _todos?.where((t) => t.status != 'done').toList() ?? [];
    final done   = _todos?.where((t) => t.status == 'done').toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My Todos'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: null,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_todos?.isEmpty ?? true)
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    children: [
                      const Center(child: Text('📝', style: TextStyle(fontSize: 48))),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text('No todos yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text('Tap + to add a task',
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      const SizedBox(height: 20),
                      _QuoteCard(quote: _quote),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      _QuoteCard(quote: _quote),
                      const SizedBox(height: 12),
                      if (active.isNotEmpty) ...[
                        _SectionLabel('ACTIVE  (${active.length})'),
                        ...active.map((t) => _TodoCard(
                              todo: t,
                              onLongPress: () => _showStatusSheet(t),
                              onToggle: () => _showStatusSheet(t),
                              onDelete: () => _delete(t),
                            )),
                      ],
                      if (done.isNotEmpty)
                        _DoneSection(
                          todos: done,
                          onLongPress: _showStatusSheet,
                          onToggle: (t) => _setStatus(t, 'todo'),
                          onDelete: _delete,
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label, required this.color, required this.bgColor,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          if (selected) Icon(Icons.check, color: color, size: 18),
        ],
      ),
    ),
  );
}

class _DoneSection extends StatefulWidget {
  final List<TodoItem> todos;
  final void Function(TodoItem) onLongPress;
  final void Function(TodoItem) onToggle;
  final void Function(TodoItem) onDelete;

  const _DoneSection({
    required this.todos, required this.onLongPress,
    required this.onToggle, required this.onDelete,
  });

  @override
  State<_DoneSection> createState() => _DoneSectionState();
}

class _DoneSectionState extends State<_DoneSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
            child: Row(
              children: [
                Text(
                  'DONE  (${widget.todos.length})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.todos.map((t) => _TodoCard(
                todo: t,
                onLongPress: () => widget.onLongPress(t),
                onToggle: () => widget.onToggle(t),
                onDelete: () => widget.onDelete(t),
              )),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
      );
}

class _QuoteCard extends StatelessWidget {
  final String quote;
  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                quote,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.primary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

class _TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoCard({
    required this.todo, required this.onLongPress,
    required this.onToggle, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Dismissible(
        key: Key('todo_${todo.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
        ),
        onDismissed: (_) => onDelete(),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => onToggle(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    activeColor: AppColors.teal,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                todo.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: todo.isCompleted ? AppColors.muted : AppColors.text,
                                  decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: onLongPress,
                              child: _StatusChip(todo.status),
                            ),
                            if (todo.isPersonal) ...[
                              const SizedBox(width: 4),
                              _PersonalChip(),
                            ],
                          ],
                        ),
                        if (todo.notes != null && todo.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(todo.notes!,
                              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 10,
                          runSpacing: 3,
                          children: [
                            if (todo.dueDate != null)
                              _MetaChip(
                                icon: Icons.calendar_today,
                                label: _formatDate(todo.dueDate!),
                                highlight: _isOverdue(todo),
                              ),
                            if (todo.createdAt != null)
                              _MetaChip(
                                icon: Icons.add_circle_outline,
                                label: 'Created ${_formatDate(todo.createdAt!)}',
                              ),
                            if (todo.completedAt != null)
                              _MetaChip(
                                icon: Icons.check_circle_outline,
                                label: 'Done ${_formatDate(todo.completedAt!)}',
                                color: AppColors.teal,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month]}';
    } catch (_) {
      return iso;
    }
  }

  bool _isOverdue(TodoItem t) {
    if (t.isCompleted || t.dueDate == null) return false;
    try {
      return DateTime.parse(t.dueDate!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'done'        => ('DONE', const Color(0xFFD1FAE5), AppColors.teal),
      'in_progress' => ('IN PROGRESS', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _             => ('TODO', const Color(0xFFF3F4F6), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _PersonalChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(6)),
        child: const Text('Personal',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.violet)),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color color;

  const _MetaChip({
    required this.icon, required this.label,
    this.highlight = false, this.color = AppColors.muted,
  });

  @override
  Widget build(BuildContext context) {
    final c = highlight ? AppColors.coral : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: c,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}
