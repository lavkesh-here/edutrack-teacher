import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brain Booster Hub
// ─────────────────────────────────────────────────────────────────────────────

class BrainBoosterScreen extends StatefulWidget {
  const BrainBoosterScreen({super.key});

  @override
  State<BrainBoosterScreen> createState() => _BrainBoosterScreenState();
}

class _BrainBoosterScreenState extends State<BrainBoosterScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>>? _leaderboard;
  bool _loading = true;

  late final AnimationController _cardSlideCtrl;
  late final List<Animation<Offset>> _cardSlides;

  @override
  void initState() {
    super.initState();
    _cardSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardSlides = List.generate(
      3,
      (i) => Tween<Offset>(
        begin: Offset(0, 0.4 + i * 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _cardSlideCtrl,
        curve: Interval(i * 0.15, 0.7 + i * 0.1, curve: Curves.easeOutCubic),
      )),
    );
    _load();
  }

  @override
  void dispose() {
    _cardSlideCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await ApiClient.brainBoosterMe();
      final lb = await ApiClient.brainBoosterLeaderboard();
      if (mounted) {
        setState(() {
          _me = me;
          _leaderboard = (lb as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
        _cardSlideCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: p,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p, AppColors.violet, AppColors.sky.withOpacity(0.8)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🧠', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Brain Booster',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                                  Text('Daily puzzles · 2PM – 6AM',
                                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                                ],
                              ),
                            ),
                            if (_me != null)
                              _StreakBadge(streak: _me!['current_streak'] ?? 0),
                          ],
                        ),
                        if (_me != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _StatPill('${_me!['games_played'] ?? 0}', 'Played'),
                              const SizedBox(width: 10),
                              _StatPill('${_me!['longest_streak'] ?? 0}', 'Best Streak'),
                              const SizedBox(width: 10),
                              _StatPill('${_me!['average_score'] ?? 0}', 'Avg Score'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text('Brain Booster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              collapseMode: CollapseMode.parallax,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          if (_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator(color: p)),
              ),
            )
          else ...[
            // ── Games ────────────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text("TODAY'S GAMES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SlideTransition(
                    position: _cardSlides[0],
                    child: _GameCard(
                      emoji: '🔢',
                      title: 'Sudoku',
                      subtitle: 'Fill the 9×9 grid · ${_me?['today_played'] == true ? "Played ✓" : "Not played yet"}',
                      color: p,
                      lightColor: p.withOpacity(0.12),
                      played: _me?['today_played'] == true,
                      score: _me?['today_score'],
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SudokuGameScreen()));
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _cardSlides[1],
                    child: const _GameCard(
                      emoji: '👑',
                      title: 'Grid Lock',
                      subtitle: 'Place queens in every zone',
                      color: AppColors.violet,
                      lightColor: AppColors.violetLight,
                      comingSoon: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _cardSlides[2],
                    child: const _GameCard(
                      emoji: '🔤',
                      title: 'Wordsmith',
                      subtitle: 'Unscramble today\'s word',
                      color: AppColors.teal,
                      lightColor: AppColors.tealLight,
                      comingSoon: true,
                    ),
                  ),
                ]),
              ),
            ),

            // ── Leaderboard ───────────────────────────────────────────────────
            if (_leaderboard != null && _leaderboard!.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text("TODAY'S LEADERBOARD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _LeaderboardRow(entry: _leaderboard![i], index: i),
                    childCount: _leaderboard!.length,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StreakBadge extends StatefulWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  State<_StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<_StreakBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    if (widget.streak > 0) _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.streak == 0) return const SizedBox.shrink();
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text('${widget.streak}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  const _StatPill(this.value, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _GameCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Color lightColor;
  final bool comingSoon;
  final bool played;
  final int? score;
  final VoidCallback? onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lightColor,
    this.comingSoon = false,
    this.played = false,
    this.score,
    this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.96, upperBound: 1.0, value: 1.0);
    _pressScale = _pressCtrl;
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { if (!widget.comingSoon) _pressCtrl.reverse(); },
      onTapUp: (_) { _pressCtrl.forward(); widget.onTap?.call(); },
      onTapCancel: () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.played ? widget.color.withOpacity(0.4) : AppColors.border, width: widget.played ? 2 : 1.5),
            boxShadow: widget.played
                ? [BoxShadow(color: widget.color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: widget.lightColor, borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: widget.comingSoon ? AppColors.muted : AppColors.text)),
                        if (widget.comingSoon) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(6)),
                            child: const Text('SOON', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.amber)),
                          ),
                        ],
                        if (widget.played) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(6)),
                            child: const Text('DONE ✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.teal)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    if (widget.score != null) ...[
                      const SizedBox(height: 6),
                      Text('Score: ${widget.score}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.color)),
                    ],
                  ],
                ),
              ),
              if (!widget.comingSoon)
                Icon(Icons.chevron_right_rounded, color: widget.color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int index;
  const _LeaderboardRow({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final rank = (entry['rank'] as int?) ?? index + 1;
    final isTop3 = rank <= 3;
    final medalEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTop3 ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank == 1 ? const Color(0xFFFFD700).withOpacity(0.4)
              : rank == 2 ? const Color(0xFFC0C0C0).withOpacity(0.4)
              : rank == 3 ? const Color(0xFFCD7F32).withOpacity(0.4)
              : AppColors.border,
          width: isTop3 ? 1.5 : 1,
        ),
        boxShadow: isTop3 ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))] : [],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medalEmoji != null
                ? Text(medalEmoji, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center)
                : Text('#$rank', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.muted), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (entry['name'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(entry['user_type'] == 'teacher' ? 'Teacher' : 'Parent',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry['score'] ?? 0}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
              Text('${entry['time_seconds'] ?? 0}s', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sudoku Game Screen
// ─────────────────────────────────────────────────────────────────────────────

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({super.key});

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> with TickerProviderStateMixin {
  // Puzzle state
  List<List<int>> _puzzle = [];
  List<List<int>> _userBoard = [];
  List<List<bool>> _given = [];
  List<List<bool>> _errors = [];
  int? _selRow, _selCol;
  int _puzzleNumber = 0;
  String _difficulty = '';
  bool _loading = true;
  bool _completed = false;
  bool _submitting = false;
  Map<String, dynamic>? _result;

  // Hints
  int _hintsUsed = 0;
  static const _maxHints = 4;
  List<Map<String, dynamic>> _hintCache = [];
  Map<String, dynamic>? _activeHint;

  // Timer
  late Timer _timer;
  int _elapsed = 0;
  bool _timerRunning = false;

  // Animations
  late final AnimationController _shakeCtrl;
  late final Animation<Offset> _shakeAnim;
  int? _shakeRow, _shakeCol;

  late final AnimationController _celebrationCtrl;
  late final Animation<double> _celebrationScale;

  // Per-cell hint glow
  final Map<String, AnimationController> _glowCtrls = {};

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0.03, 0)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.03, 0), end: const Offset(-0.03, 0)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.03, 0), end: const Offset(0.02, 0)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.02, 0), end: Offset.zero), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _celebrationCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _celebrationScale = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _celebrationCtrl, curve: Curves.elasticOut));

    _load();
  }

  @override
  void dispose() {
    _timer.cancel();
    _shakeCtrl.dispose();
    _celebrationCtrl.dispose();
    for (final c in _glowCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.brainBoosterSudokuToday();
      final board = (data['board'] as List).map((row) => (row as List).map((c) => c as int).toList()).toList();

      // If already played today, show result directly
      if (data['my_score'] != null) {
        final score = data['my_score'] as Map<String, dynamic>;
        setState(() {
          _puzzle = board;
          _userBoard = [for (final row in board) [...row]];
          _given = [for (final row in board) [for (final c in row) c != 0]];
          _errors = List.generate(9, (_) => List.filled(9, false));
          _puzzleNumber = data['puzzle_number'];
          _difficulty = data['difficulty'] ?? '';
          _completed = true;
          _elapsed = score['time_seconds'] ?? 0;
          _result = {'score': score['score'], 'correct': true, 'hints_used': score['hints_used'] ?? 0, 'time_seconds': score['time_seconds'] ?? 0};
          _loading = false;
        });
        return;
      }

      setState(() {
        _puzzle = board;
        _userBoard = [for (final row in board) [...row]];
        _given = [for (final row in board) [for (final c in row) c != 0]];
        _errors = List.generate(9, (_) => List.filled(9, false));
        _puzzleNumber = data['puzzle_number'];
        _difficulty = data['difficulty'] ?? '';
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, e is ApiError ? e.message : 'Failed to load puzzle', error: true);
      }
    }
  }

  void _startTimer() {
    _timerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timerRunning && !_completed) {
        setState(() => _elapsed++);
      }
    });
  }

  void _selectCell(int r, int c) {
    if (_given[r][c] || _completed) return;
    setState(() { _selRow = r; _selCol = c; });
  }

  void _enterNumber(int num) {
    if (_selRow == null || _selCol == null || _completed) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_given[r][c]) return;

    HapticFeedback.lightImpact();
    setState(() {
      _userBoard[r][c] = num;
      _errors[r][c] = false;
    });

    // Check if board is fully filled
    final allFilled = !_userBoard.any((row) => row.any((v) => v == 0));
    if (allFilled) _checkAndSubmit();
  }

  void _erase() {
    if (_selRow == null || _selCol == null || _completed) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_given[r][c]) return;
    setState(() { _userBoard[r][c] = 0; _errors[r][c] = false; });
  }

  Future<void> _checkAndSubmit() async {
    // Basic local validation — highlight errors
    bool hasErrors = false;
    final newErrors = List.generate(9, (_) => List.filled(9, false));

    for (int r = 0; r < 9; r++) {
      final seen = <int>{};
      for (int c = 0; c < 9; c++) {
        final v = _userBoard[r][c];
        if (v == 0) { hasErrors = true; continue; }
        if (!seen.add(v)) {
          newErrors[r][c] = true;
          for (int c2 = 0; c2 < c; c2++) {
            if (_userBoard[r][c2] == v) newErrors[r][c2] = true;
          }
          hasErrors = true;
        }
      }
    }
    for (int c = 0; c < 9; c++) {
      final seen = <int>{};
      for (int r = 0; r < 9; r++) {
        final v = _userBoard[r][c];
        if (v == 0 || newErrors[r][c]) continue;
        if (!seen.add(v)) {
          newErrors[r][c] = true;
          for (int r2 = 0; r2 < r; r2++) {
            if (_userBoard[r2][c] == v) newErrors[r2][c] = true;
          }
          hasErrors = true;
        }
      }
    }
    for (int br = 0; br < 9; br += 3) {
      for (int bc = 0; bc < 9; bc += 3) {
        final seen = <int>{};
        for (int r = br; r < br + 3; r++) {
          for (int c = bc; c < bc + 3; c++) {
            final v = _userBoard[r][c];
            if (v == 0 || newErrors[r][c]) continue;
            if (!seen.add(v)) {
              newErrors[r][c] = true;
              hasErrors = true;
            }
          }
        }
      }
    }

    if (hasErrors) {
      setState(() { _errors = newErrors; _shakeRow = _selRow; _shakeCol = _selCol; });
      HapticFeedback.mediumImpact();
      _shakeCtrl.forward(from: 0);
      return;
    }

    // All good — submit
    _timerRunning = false;
    setState(() => _submitting = true);

    try {
      final result = await ApiClient.brainBoosterSubmit(
        puzzleNumber: _puzzleNumber,
        hintsUsed: _hintsUsed,
        timeSeconds: _elapsed,
        board: _userBoard,
      );
      setState(() {
        _result = result;
        _completed = true;
        _submitting = false;
      });
      HapticFeedback.heavyImpact();
      _celebrationCtrl.forward(from: 0).then((_) => _celebrationCtrl.reverse());
      _showResultSheet();
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) showSnack(context, e is ApiError ? e.message : 'Submit failed', error: true);
    }
  }

  Future<void> _useHint() async {
    if (_hintsUsed >= _maxHints || _completed) return;
    final hintNum = _hintsUsed + 1;

    // Check cache first
    Map<String, dynamic>? hint;
    if (hintNum <= _hintCache.length) {
      hint = _hintCache[hintNum - 1];
    } else {
      try {
        hint = await ApiClient.brainBoosterHint(hintNum);
        _hintCache.add(hint!);
      } catch (e) {
        if (mounted) showSnack(context, e is ApiError ? e.message : 'Could not load hint', error: true);
        return;
      }
    }

    setState(() {
      _hintsUsed++;
      _activeHint = hint;
    });

    // If it's a cell reveal, fill the cell with animation
    if (hint['type'] == 'cell_reveal') {
      final r = hint['row'] as int;
      final c = hint['col'] as int;
      final key = '$r-$c';

      // Create glow controller for this cell
      final glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
      _glowCtrls[key] = glowCtrl;
      await glowCtrl.forward();

      setState(() {
        _userBoard[r][c] = hint!['value'] as int;
        _errors[r][c] = false;
        _selRow = r;
        _selCol = c;
      });
      HapticFeedback.lightImpact();

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _activeHint = null);
    } else {
      // Strategic/constraint hint — show as snackbar overlay
      if (mounted) showSnack(context, hint['message'] ?? 'Hint: look carefully!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _activeHint = null);
    }
  }

  void _showResultSheet() {
    if (_result == null) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ResultSheet(result: _result!, elapsed: _elapsed, puzzleNumber: _puzzleNumber),
    );
  }

  String _timerColor() {
    if (_elapsed < 120) return 'green';
    if (_elapsed < 300) return 'amber';
    return 'red';
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: p),
            const SizedBox(height: 16),
            const Text('Loading puzzle…', style: TextStyle(color: AppColors.muted)),
          ],
        )),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sudoku #$_puzzleNumber', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                        Text(_difficulty, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  // Timer
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _timerColor() == 'green' ? AppColors.tealLight
                          : _timerColor() == 'amber' ? AppColors.amberLight
                          : AppColors.coralLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 14,
                            color: _timerColor() == 'green' ? AppColors.teal
                                : _timerColor() == 'amber' ? AppColors.amber
                                : AppColors.coral),
                        const SizedBox(width: 4),
                        Text(
                          '${(_elapsed ~/ 60).toString().padLeft(2, '0')}:${(_elapsed % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: _timerColor() == 'green' ? AppColors.teal
                                : _timerColor() == 'amber' ? AppColors.amber
                                : AppColors.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Sudoku Grid ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ScaleTransition(
                  scale: _celebrationScale,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _SudokuGrid(
                      puzzle: _puzzle,
                      userBoard: _userBoard,
                      given: _given,
                      errors: _errors,
                      selRow: _selRow,
                      selCol: _selCol,
                      shakeAnim: _shakeAnim,
                      shakeRow: _shakeRow,
                      shakeCol: _shakeCol,
                      glowCtrls: _glowCtrls,
                      onSelect: _selectCell,
                      completed: _completed,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Hint + Erase row ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.lightbulb_outline,
                    label: 'Hint (${_maxHints - _hintsUsed} left)',
                    color: AppColors.amber,
                    onTap: (_hintsUsed < _maxHints && !_completed) ? _useHint : null,
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: Icons.backspace_outlined,
                    label: 'Erase',
                    color: AppColors.muted,
                    onTap: (!_completed) ? _erase : null,
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: Icons.check_circle_outline,
                    label: _submitting ? 'Checking…' : 'Check',
                    color: p,
                    onTap: (!_completed && !_submitting) ? _checkAndSubmit : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Number Pad ──────────────────────────────────────────────────
            if (!_completed)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _NumberPad(onNumber: _enterNumber),
                ),
              ),

            if (_completed && _result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showResultSheet,
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: const Text('View Result', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sudoku Grid Widget ───────────────────────────────────────────────────────

class _SudokuGrid extends StatelessWidget {
  final List<List<int>> puzzle;
  final List<List<int>> userBoard;
  final List<List<bool>> given;
  final List<List<bool>> errors;
  final int? selRow, selCol;
  final Animation<Offset> shakeAnim;
  final int? shakeRow, shakeCol;
  final Map<String, AnimationController> glowCtrls;
  final void Function(int, int) onSelect;
  final bool completed;

  const _SudokuGrid({
    required this.puzzle,
    required this.userBoard,
    required this.given,
    required this.errors,
    required this.selRow,
    required this.selCol,
    required this.shakeAnim,
    required this.shakeRow,
    required this.shakeCol,
    required this.glowCtrls,
    required this.onSelect,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: p.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: List.generate(9, (r) => Expanded(
            child: Row(
              children: List.generate(9, (c) {
                final isSelected = selRow == r && selCol == c;
                final isSameRow = selRow == r;
                final isSameCol = selCol == c;
                final isSameBox = selRow != null && selCol != null &&
                    (r ~/ 3 == selRow! ~/ 3) && (c ~/ 3 == selCol! ~/ 3);
                final isHighlighted = (isSameRow || isSameCol || isSameBox) && !isSelected;
                final isGiven = given.isNotEmpty && given[r][c];
                final val = userBoard.isNotEmpty ? userBoard[r][c] : 0;
                final sameNum = val != 0 && selRow != null && selCol != null
                    && userBoard[selRow!][selCol!] == val && !isSelected;
                final hasError = errors.isNotEmpty && errors[r][c];
                final key = '$r-$c';
                final isGlowing = glowCtrls.containsKey(key);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(r, c),
                    child: SlideTransition(
                      position: (shakeRow == r && shakeCol == c) ? shakeAnim : const AlwaysStoppedAnimation(Offset.zero),
                      child: AnimatedBuilder(
                        animation: isGlowing ? glowCtrls[key]! : const AlwaysStoppedAnimation(0.0),
                        builder: (_, __) {
                          final glowVal = isGlowing ? glowCtrls[key]!.value : 0.0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              color: isSelected ? p.withOpacity(0.2)
                                  : hasError ? AppColors.coralLight
                                  : isGlowing && glowVal > 0.3 ? AppColors.amberLight
                                  : sameNum ? p.withOpacity(0.1)
                                  : isHighlighted ? p.withOpacity(0.05)
                                  : Colors.transparent,
                              border: Border(
                                right: BorderSide(
                                  color: (c == 2 || c == 5) ? p.withOpacity(0.4) : AppColors.border.withOpacity(0.5),
                                  width: (c == 2 || c == 5) ? 2 : 0.5,
                                ),
                                bottom: BorderSide(
                                  color: (r == 2 || r == 5) ? p.withOpacity(0.4) : AppColors.border.withOpacity(0.5),
                                  width: (r == 2 || r == 5) ? 2 : 0.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: val == 0
                                  ? null
                                  : AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 150),
                                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                      child: Text(
                                        '$val',
                                        key: ValueKey('$r-$c-$val'),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: isGiven ? FontWeight.w800 : FontWeight.w600,
                                          color: hasError ? AppColors.coral
                                              : isGiven ? AppColors.text
                                              : isSelected ? p
                                              : isGlowing ? AppColors.amber
                                              : p.withOpacity(0.85),
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          )),
        ),
      ),
    );
  }
}

// ─── Number Pad ──────────────────────────────────────────────────────────────

class _NumberPad extends StatelessWidget {
  final void Function(int) onNumber;
  const _NumberPad({required this.onNumber});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(9, (i) {
        final num = i + 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _PadButton(number: num, color: p, onTap: () => onNumber(num)),
          ),
        );
      }),
    );
  }
}

class _PadButton extends StatefulWidget {
  final int number;
  final Color color;
  final VoidCallback onTap;
  const _PadButton({required this.number, required this.color, required this.onTap});

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80), lowerBound: 0.88, upperBound: 1.0, value: 1.0);
    _scale = _ctrl;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) { _ctrl.forward(); widget.onTap(); },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Center(
            child: Text(
              '${widget.number}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Action Button ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(0.1) : AppColors.border,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: enabled ? color.withOpacity(0.3) : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: enabled ? color : AppColors.muted, size: 20),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: enabled ? color : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result Sheet ─────────────────────────────────────────────────────────────

class _ResultSheet extends StatefulWidget {
  final Map<String, dynamic> result;
  final int elapsed;
  final int puzzleNumber;

  const _ResultSheet({required this.result, required this.elapsed, required this.puzzleNumber});

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = Tween<double>(begin: 0, end: (widget.result['score'] as int? ?? 0).toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    final score = widget.result['score'] as int? ?? 0;
    final hintsUsed = widget.result['hints_used'] as int? ?? 0;
    final elapsed = widget.result['time_seconds'] as int? ?? widget.elapsed;
    final percentile = widget.result['percentile'] as int?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(score >= 800 ? '🏆' : score >= 500 ? '⭐' : '💪', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            score >= 800 ? 'Outstanding!' : score >= 500 ? 'Well Done!' : 'Good Try!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
          ),
          Text('Sudoku #${widget.puzzleNumber}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),

          // Animated score display
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (_, __) => Text(
              '${_scoreAnim.value.toInt()}',
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: p),
            ),
          ),
          const Text('points', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w600)),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ResultStat('⏱', '${elapsed ~/ 60}m ${elapsed % 60}s', 'Time'),
              _ResultStat('💡', '$hintsUsed / 4', 'Hints Used'),
              if (percentile != null) _ResultStat('📊', 'Top $percentile%', 'School Rank'),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: p, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Back to Brain Booster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _ResultStat(this.emoji, this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
    ],
  );
}
