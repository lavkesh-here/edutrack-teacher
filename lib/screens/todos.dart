import 'package:flutter/material.dart';
import '../core/api.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final todos = await ApiClient.getTodos();
      if (mounted) setState(() { _todos = todos; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, 'Failed to load todos', error: true);
      }
    }
  }

  Future<void> _toggleDone(TodoItem todo) async {
    try {
      await ApiClient.updateTodo(todo.id, isCompleted: !todo.isCompleted);
      await _load();
    } catch (_) {
      if (mounted) showSnack(context, 'Update failed', error: true);
    }
  }

  Future<void> _delete(TodoItem todo) async {
    try {
      await ApiClient.deleteTodo(todo.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Deleted'),
            backgroundColor: AppColors.text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Delete failed', error: true);
    }
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? dueDate;
    bool isPersonal = false;

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
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
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
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
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
    final pending = _todos?.where((t) => !t.isCompleted).toList() ?? [];
    final done = _todos?.where((t) => t.isCompleted).toList() ?? [];

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
        backgroundColor: AppColors.sun,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _todos!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('No todos yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 4),
                      const Text('Tap + to add a task', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _SectionLabel('TO DO  (${pending.length})'),
                        ...pending.map((t) => _TodoCard(
                              todo: t,
                              onToggle: () => _toggleDone(t),
                              onDelete: () => _delete(t),
                            )),
                      ],
                      if (done.isNotEmpty) ...[
                        _SectionLabel('DONE  (${done.length})'),
                        ...done.map((t) => _TodoCard(
                              todo: t,
                              onToggle: () => _toggleDone(t),
                              onDelete: () => _delete(t),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
        ),
      );
}

class _TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoCard({required this.todo, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: Key('todo_${todo.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
        ),
        onDismissed: (_) => onDelete(),
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
                  padding: const EdgeInsets.fromLTRB(0, 14, 14, 12),
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
                          if (todo.isPersonal)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.violetLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Personal',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.violet)),
                            ),
                        ],
                      ),
                      if (todo.notes != null && todo.notes!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(todo.notes!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                      if (todo.dueDate != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 11, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(_formatDate(todo.dueDate!),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _isOverdue(todo) ? AppColors.coral : AppColors.muted,
                                    fontWeight: _isOverdue(todo) ? FontWeight.w700 : FontWeight.w400)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_month(d.month)} ${d.year}';
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

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}
