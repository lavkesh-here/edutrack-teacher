import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class VidyaScreen extends StatefulWidget {
  const VidyaScreen({super.key});

  @override
  State<VidyaScreen> createState() => _VidyaScreenState();
}

class _VidyaScreenState extends State<VidyaScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  static const _maxChars = 400;
  static const _tealDark = Color(0xFF0C3B36);

  // Follow-up chips only trail the most recent reply, and disappear once a
  // new question is in flight — stale suggestions from an earlier turn
  // shouldn't linger once the conversation has moved on.
  List<String> get _trailingSuggestions {
    if (_loading || _messages.isEmpty) return const [];
    final last = _messages.last;
    if (last.role != 'assistant' || last.isError) return const [];
    return last.suggestions;
  }

  // Suggested prompts for onboarding / empty state
  static const _suggestions = [
    'Who was absent today?',
    'Which students are below 60%?',
    'What\'s my syllabus coverage?',
    'Show work log summary this week',
    'How many fee defaulters this month?',
    'What\'s the school attendance today?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _loading = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    // Build history from previous messages (last 5 turns)
    final history = _messages.length > 1
        ? _messages
            .sublist(0, _messages.length - 1)
            .takeLast(5)
            .map((m) => {'role': m.role == 'user' ? 'user' : 'assistant', 'content': m.text})
            .toList()
        : <Map<String, String>>[];

    try {
      final result = await ApiClient.askVidya(question: text, history: history);
      if (mounted) {
        setState(() => _messages.add(_Msg(
          role: 'assistant',
          text: result.reply,
          suggestions: result.suggestedQuestions,
        )));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(const _Msg(
          role: 'assistant',
          text: 'I\'m having trouble right now. Please try again in a moment.',
          isError: true,
        )));
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_tealDark, AppColors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('✨', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vidya', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text)),
                Text('School copilot', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          if (_messages.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _messages.clear()),
              child: const Text('Clear', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages / empty state
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(suggestions: _suggestions, onTap: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length +
                        (_loading ? 1 : 0) +
                        (_trailingSuggestions.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length && _loading) return const _TypingIndicator();
                      if (i == _messages.length + (_loading ? 1 : 0)) {
                        return _FollowUpChips(suggestions: _trailingSuggestions, onTap: _send);
                      }
                      return _Bubble(msg: _messages[i]);
                    },
                  ),
          ),

          // Input
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        maxLength: _maxChars,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 14, color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Ask Vidya anything...',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          counterText: '',
                        ),
                        onSubmitted: (v) => _send(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_ctrl.text),
                    child: Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_tealDark, AppColors.teal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

// ── Empty state with suggestion chips ────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _EmptyState({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C3B36), AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 16),
          const Text('Hi, I\'m Vidya',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text(
            'Your school copilot. Ask me about attendance,\nstudent performance, syllabus, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('TRY ASKING',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.muted, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: suggestions.map((s) => GestureDetector(
              onTap: () => onTap(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vidya only shares data you have access to. Always verify important decisions in the dashboard.',
                    style: TextStyle(fontSize: 12, color: AppColors.text2, height: 1.4),
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

// ── Message bubble ────────────────────────────────────────────────────────────

class _Msg {
  final String role; // 'user' or 'assistant'
  final String text;
  final bool isError;
  final List<String> suggestions;
  const _Msg({required this.role, required this.text, this.isError = false, this.suggestions = const []});
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0C3B36), AppColors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('✨', style: TextStyle(fontSize: 12))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0C3B36)
                    : msg.isError
                        ? AppColors.coralLight
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isUser ? Colors.white : msg.isError ? AppColors.coral : AppColors.text,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Follow-up suggestion chips (after the latest reply) ────────────────────────

class _FollowUpChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _FollowUpChips({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 10),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: suggestions.map((s) => GestureDetector(
          onTap: () => onTap(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

extension _ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0C3B36), AppColors.teal],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 12))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = ((_anim.value * 3) - i).clamp(0.0, 1.0);
                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
