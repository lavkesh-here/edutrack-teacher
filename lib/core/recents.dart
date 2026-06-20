import 'package:shared_preferences/shared_preferences.dart';

class RecentScreen {
  final String id;
  final String emoji;
  final String label;
  const RecentScreen({required this.id, required this.emoji, required this.label});
}

class RecentsManager {
  static const _max = 3;

  static const _screens = <String, RecentScreen>{
    'schedule':         RecentScreen(id: 'schedule',         emoji: '🕐', label: 'My Schedule'),
    'parents':          RecentScreen(id: 'parents',          emoji: '👨‍👩‍👦', label: 'Parent Accounts'),
    'transport':        RecentScreen(id: 'transport',        emoji: '🚌', label: 'Transport'),
    'school_settings':  RecentScreen(id: 'school_settings',  emoji: '🏫', label: 'School Settings'),
    'admin_worklogs':   RecentScreen(id: 'admin_worklogs',   emoji: '📋', label: 'Work Log Overview'),
    'attenders':        RecentScreen(id: 'attenders',        emoji: '👤', label: 'Attenders'),
    'fees':             RecentScreen(id: 'fees',             emoji: '💰', label: 'Fee Management'),
    'leave_config':     RecentScreen(id: 'leave_config',     emoji: '⚙️', label: 'Leave Config'),
    'leaves':           RecentScreen(id: 'leaves',           emoji: '🗓️', label: 'My Leaves'),
    'payroll':          RecentScreen(id: 'payroll',          emoji: '💳', label: 'Payroll'),
    'todos':            RecentScreen(id: 'todos',            emoji: '✅', label: 'My Todos'),
  };

  static Future<String> _key() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('teacher_id') ?? '';
    return 'recent_screens_$userId';
  }

  static Future<List<RecentScreen>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _key();
    final ids = prefs.getStringList(key) ?? [];
    return ids.map((id) => _screens[id]).whereType<RecentScreen>().toList();
  }

  static Future<void> record(String id) async {
    if (!_screens.containsKey(id)) return;
    final prefs = await SharedPreferences.getInstance();
    final key = await _key();
    final ids = List<String>.from(prefs.getStringList(key) ?? []);
    ids.remove(id);
    ids.insert(0, id);
    await prefs.setStringList(key, ids.take(_max).toList());
  }
}
