import 'package:flutter/material.dart';
import '../core/theme.dart';

class _Message {
  final String text;
  final bool isTeacher;
  final String time;

  const _Message({
    required this.text,
    required this.isTeacher,
    required this.time,
  });
}

class ChatViewScreen extends StatefulWidget {
  final String parentName;
  final String studentName;

  const ChatViewScreen({
    super.key,
    required this.parentName,
    required this.studentName,
  });

  @override
  State<ChatViewScreen> createState() => _ChatViewScreenState();
}

class _ChatViewScreenState extends State<ChatViewScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late List<_Message> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      _Message(
        text: 'Hello, I wanted to discuss ${widget.studentName}\'s recent test performance.',
        isTeacher: true,
        time: '10:00 AM',
      ),
      _Message(
        text: 'Thank you for reaching out. How did they do?',
        isTeacher: false,
        time: '10:05 AM',
      ),
      _Message(
        text: '${widget.studentName} scored 78/100. There\'s room for improvement in the theory section.',
        isTeacher: true,
        time: '10:08 AM',
      ),
      _Message(
        text: 'I see. We\'ll work on it at home. Thank you for letting me know.',
        isTeacher: false,
        time: '10:12 AM',
      ),
      _Message(
        text: 'Also, please ensure the homework is submitted by Friday.',
        isTeacher: true,
        time: '10:14 AM',
      ),
      _Message(
        text: 'Of course, I\'ll make sure of it.',
        isTeacher: false,
        time: '10:16 AM',
      ),
    ];
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(
        text: text,
        isTeacher: true,
        time: _now(),
      ));
    });
    _msgCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _now() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.parentName.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [context.primary, AppColors.coral]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.parentName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                Text(
                  'Parent of ${widget.studentName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Demo mode banner
          Container(
            color: AppColors.violetLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Demo Mode',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Messages are local only — live chat coming soon',
                    style: TextStyle(fontSize: 11, color: AppColors.violet),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),

          // Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        key: const Key('chat_message_field'),
                        controller: _msgCtrl,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const Key('send_message_button'),
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Message msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment:
              msg.isTeacher ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!msg.isTeacher) ...[
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Text('👨', style: TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 6),
            ],
            Column(
              crossAxisAlignment: msg.isTeacher
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isTeacher ? context.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isTeacher ? 18 : 4),
                      bottomRight: Radius.circular(msg.isTeacher ? 4 : 18),
                    ),
                    border: msg.isTeacher
                        ? null
                        : Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: msg.isTeacher ? Colors.white : AppColors.text,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.time,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
            if (msg.isTeacher) const SizedBox(width: 6),
          ],
        ),
      );
}
