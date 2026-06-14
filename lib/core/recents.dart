import 'package:shared_preferences/shared_preferences.dart';

class RecentScreen {
  final String id;
  final String emoji;
  final String label;
  const RecentScreen({required this.id, required this.emoji, required this.label});
}

class RecentsManager {
  static const _key = 'recent_screens';
  static const _max = 3;

  // Only items exclusively reachable via More tab (not bottom nav, dashboard tiles, quick actions, or profile)
  static const _screens = <String, RecentScreen>{
    'schedule':         RecentScreen(id: 'schedule',         emoji: '🕐', label: 'My Schedule'),
    'parents':          RecentScreen(id: 'parents',          emoji: '👨‍👩‍👦', label: 'Parent Accounts'),
    'transport':        RecentScreen(id: 'transport',        emoji: '🚌', label: 'Transport'),
    'school_settings':  RecentScreen(id: 'school_settings',  emoji: '🏫', label: 'School Settings'),
    'admin_worklogs':   RecentScreen(id: 'admin_worklogs',   emoji: '📋', label: 'Work Log Overview'),
    'attenders':        RecentScreen(id: 'attenders',        emoji: '👤', label: 'Attenders'),
    'fees':             RecentScreen(id: 'fees',             emoji: '💰', label: 'Fee Management'),
    'leave_config':     RecentScreen(id: 'leave_config',     emoji: '⚙️', label: 'Leave Config'),
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
