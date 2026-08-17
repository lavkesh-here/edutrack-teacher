import 'package:flutter/material.dart';
import '../core/theme.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _faqSections
        : _faqSections
            .map((s) => _FaqSection(
                  title: s.title,
                  icon: s.icon,
                  items: s.items
                      .where((i) =>
                          i.q.toLowerCase().contains(_query.toLowerCase()) ||
                          i.a.toLowerCase().contains(_query.toLowerCase()))
                      .toList(),
                ))
            .where((s) => s.items.isNotEmpty)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search questions…',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          'No results for "$_query"',
                          style: const TextStyle(color: AppColors.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, si) {
                      final section = filtered[si];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (si > 0) const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(section.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                section.title.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: List.generate(section.items.length, (qi) {
                                  final item = section.items[qi];
                                  final isLast = qi == section.items.length - 1;
                                  return Column(
                                    children: [
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 2),
                                          childrenPadding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 14),
                                          expandedCrossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          iconColor: context.primary,
                                          collapsedIconColor: AppColors.muted,
                                          title: Text(
                                            item.q,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          children: [
                                            Text(
                                              item.a,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.muted,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLast)
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.border,
                                          indent: 16,
                                          endIndent: 16,
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _FaqItem {
  const _FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class _FaqSection {
  const _FaqSection({required this.title, required this.icon, required this.items});
  final String title;
  final String icon;
  final List<_FaqItem> items;
}

const _faqSections = <_FaqSection>[
  _FaqSection(
    title: 'Getting Started',
    icon: '🚀',
    items: [
      _FaqItem(
        'How do I log in?',
        'Enter your school code, email address, and password on the login screen. '
            'Your school code and credentials are provided by your school administrator.',
      ),
      _FaqItem(
        'I forgot my password. What should I do?',
        'Contact your school administrator to reset your password. '
            'They can issue you a temporary password from the admin panel.',
      ),
      _FaqItem(
        'How do I set up fingerprint / face unlock?',
        'Go to More → Biometric Unlock and toggle it on. '
            'You will be asked to verify your biometric once to activate it. '
            'After 60 seconds of inactivity the app will lock and prompt your fingerprint or face.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Attendance',
    icon: '✅',
    items: [
      _FaqItem(
        'How do I mark attendance for my class?',
        'Tap the Attendance tab at the bottom. Select the class and date, '
            'then tap each student to mark them Present, Absent, or Late. '
            'Tap Save when done.',
      ),
      _FaqItem(
        'Can I edit attendance after saving?',
        'Yes. Open the same class and date, make your changes, and tap Save again. '
            'The system will update the existing record.',
      ),
      _FaqItem(
        'How do I check my own attendance record?',
        'Go to More → My Attendance. It shows your GPS check-in history and '
            'a monthly summary.',
      ),
      _FaqItem(
        'How does GPS self-attendance work?',
        'When you arrive at school, open the app and tap Check In. '
            'The app verifies your location is within the school boundary and records your arrival time.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Tests & Scores',
    icon: '📝',
    items: [
      _FaqItem(
        'How do I upload scores for a test?',
        'Tap the Tests tab, find the test, and tap Enter Scores. '
            'Enter each student\'s marks and tap Save. '
            'You can also add optional remarks which improve the analysis.',
      ),
      _FaqItem(
        'What is the Smart Analysis?',
        'After scores are uploaded, tap Get Smart Analysis on the test scores page. '
            'It reviews class performance, identifies weak chapters, spots at-risk students, '
            'and gives actionable suggestions — all in a few seconds.',
      ),
      _FaqItem(
        'Can I re-run the analysis after adding more scores?',
        'Yes. Tap Refresh Analysis on the scores page. '
            'The system detects when scores have changed and runs a fresh analysis.',
      ),
      _FaqItem(
        'How do I view a student\'s report and score history?',
        'Tap a student\'s name anywhere in the app to open their profile. '
            'The Report tab shows their score trend over time, chapter heatmap, and smart remarks.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Leaves & Schedule',
    icon: '🗓️',
    items: [
      _FaqItem(
        'How do I apply for leave?',
        'Go to More → My Leaves and tap Apply for Leave. '
            'Choose the leave type, select dates, add a reason, and submit. '
            'You will be notified once it is approved or rejected.',
      ),
      _FaqItem(
        'How many leave days do I have?',
        'Open More → My Leaves to see your balance for each leave type '
            '(Casual Leave, Sick Leave, etc.).',
      ),
      _FaqItem(
        'Where can I see my timetable?',
        'Go to More → My Schedule to view your full weekly timetable with '
            'class, subject, and room details for each period.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Students & Parents',
    icon: '👨‍👩‍👦',
    items: [
      _FaqItem(
        'How do I view a student\'s full profile?',
        'Tap any student\'s name from the attendance list or test scores screen. '
            'Their profile shows personal info, attendance history, test scores, documents, and smart report.',
      ),
      _FaqItem(
        'How do parents see their child\'s progress?',
        'Parents use the separate Edtrack Parent app. '
            'An admin must first create a parent account and link it to the student. '
            'Parents can then view attendance, test scores, and school announcements.',
      ),
      _FaqItem(
        'Can I send messages to parents?',
        'Yes. Use the Chat tab to send direct messages to parents '
            'of students in your sections.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Profile & Settings',
    icon: '⚙️',
    items: [
      _FaqItem(
        'How do I update my profile photo?',
        'Go to More and tap your profile card at the top. '
            'Tap the photo area to upload a new picture from your gallery.',
      ),
      _FaqItem(
        'How do I manage my notification preferences?',
        'Go to More → Notification Preferences to turn on or off '
            'alerts for leaves, announcements, score uploads, and other events.',
      ),
      _FaqItem(
        'The text in the app looks too small. What can I do?',
        'You can increase the font size from your phone\'s Settings → Display → '
            'Font Size. The app automatically adjusts to your phone\'s font setting.',
      ),
    ],
  ),
];
