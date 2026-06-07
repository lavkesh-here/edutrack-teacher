import 'package:shared_preferences/shared_preferences.dart';

class RecentScreen {
  final String id;
  final String emoji;
  final String label;
  const RecentScreen({required this.id, required this.emoji, required this.label});
}

class RecentsManager {
  static const _key = 'recent_screens';
  static const _max = 5;

  static const _screens = <String, RecentScreen>{
    'attendance': RecentScreen(id: 'attendance', emoji: '📋', label: 'Attendance'),
    'worklog':    RecentScreen(id: 'worklog',    emoji: '📚', label: 'Work Log'),
    'notify':     RecentScreen(id: 'notify',     emoji: '🔔', label: 'Notify'),
    'todos':      RecentScreen(id: 'todos',      emoji: '✅', label: 'Todos'),
    'students':   RecentScreen(id: 'students',   emoji: '👥', label: 'Students'),
    'calendar':   RecentScreen(id: 'calendar',   emoji: '📅', label: 'Calendar'),
    'results':    RecentScreen(id: 'results',    emoji: '📊', label: 'Results'),
    'leaves':     RecentScreen(id: 'leaves',     emoji: '🗓️', label: 'Leaves'),
    'payslips':   RecentScreen(id: 'payslips',   emoji: '💰', label: 'Payslips'),
    'schedule':   RecentScreen(id: 'schedule',   emoji: '🕐', label: 'Schedule'),
  };

  static Future<List<RecentScreen>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    return ids.map((id) => _screens[id]).whereType<RecentScreen>().toList();
  }

  static Future<void> record(String id) async {
    if (!_screens.containsKey(id)) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(prefs.getStringList(_key) ?? []);
    ids.remove(id);
    ids.insert(0, id);
    await prefs.setStringList(_key, ids.take(_max).toList());
  }
}
