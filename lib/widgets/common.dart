import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const StatusBadge({super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

Widget statusBadgeForTest(String status) {
  switch (status) {
    case 'finalized':
      return const StatusBadge(label: 'Finalized', bg: AppColors.greenLight, fg: Color(0xFF15803D));
    case 'exported':
      return const StatusBadge(label: 'Exported', bg: AppColors.tealLight, fg: Color(0xFF0F766E));
    default:
      return const StatusBadge(label: 'Draft', bg: Color(0xFFF3F4F6), fg: Color(0xFF6B7280));
  }
}

Widget statusBadgeForLeave(String status) {
  switch (status) {
    case 'approved':
      return const StatusBadge(label: '✓ Approved', bg: AppColors.greenLight, fg: Color(0xFF15803D));
    case 'rejected':
      return const StatusBadge(label: '✗ Rejected', bg: AppColors.coralLight, fg: Color(0xFFBE123C));
    default:
      return const StatusBadge(label: '⏳ Pending', bg: AppColors.amberLight, fg: Color(0xFF92400E));
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sun,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _SnackToast(msg: msg, error: error, onDone: () {
      try { entry.remove(); } catch (_) {}
    }),
  );
  overlay.insert(entry);
}

class _SnackToast extends StatefulWidget {
  final String msg;
  final bool error;
  final VoidCallback onDone;
  const _SnackToast({required this.msg, required this.error, required this.onDone});
  @override
  State<_SnackToast> createState() => _SnackToastState();
}

class _SnackToastState extends State<_SnackToast> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.error ? AppColors.coral : AppColors.teal,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Text(
            widget.msg,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

String fmtDate(String isoDate) {
  try {
    final d = DateTime.parse(isoDate);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return isoDate;
  }
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
