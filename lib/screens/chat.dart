import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'chat_view.dart';

class _ChatThread {
  final String name;
  final String relation;
  final String studentName;
  final String lastMessage;
  final String time;
  final int unread;
  final String initials;

  const _ChatThread({
    required this.name,
    required this.relation,
    required this.studentName,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.initials,
  });
}

const _mockThreads = [
  _ChatThread(
    name: 'Rajesh Sharma',
    relation: 'Father',
    studentName: 'Ananya Sharma',
    lastMessage: 'Thank you for letting me know about the assignment.',
    time: '2:30 PM',
    unread: 2,
    initials: 'RS',
  ),
  _ChatThread(
    name: 'Priya Mehta',
    relation: 'Mother',
    studentName: 'Arjun Mehta',
    lastMessage: "I'll make sure he completes the homework by Friday.",
    time: '11:45 AM',
    unread: 0,
    initials: 'PM',
  ),
  _ChatThread(
    name: 'Suresh Kumar',
    relation: 'Father',
    studentName: 'Riya Kumar',
    lastMessage: 'Can we schedule a meeting this week?',
    time: 'Yesterday',
    unread: 1,
    initials: 'SK',
  ),
  _ChatThread(
    name: 'Anita Verma',
    relation: 'Mother',
    studentName: 'Dev Verma',
    lastMessage: 'Thank you for the feedback on the test.',
    time: 'Mon',
    unread: 0,
    initials: 'AV',
  ),
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _mockThreads
        .where((t) =>
            _query.isEmpty ||
            t.name.toLowerCase().contains(_query.toLowerCase()) ||
            t.studentName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const Key('chat_search_field'),
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search parents...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // Thread list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No conversations found',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 72, color: AppColors.border),
                    itemBuilder: (_, i) => _ThreadTile(
                      thread: filtered[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatViewScreen(
                            parentName: filtered[i].name,
                            studentName: filtered[i].studentName,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // Coming soon banner
          Container(
            color: AppColors.amberLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('🔔', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Live chat with parents — coming soon',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E)),
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

class _ThreadTile extends StatelessWidget {
  final _ChatThread thread;
  final VoidCallback onTap;

  const _ThreadTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.primary, AppColors.coral],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    thread.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        Text(
                          thread.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: thread.unread > 0
                                ? context.primary
                                : AppColors.muted,
                            fontWeight: thread.unread > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${thread.relation} of ${thread.studentName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: thread.unread > 0
                                  ? AppColors.text2
                                  : AppColors.muted,
                              fontWeight: thread.unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (thread.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${thread.unread}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
