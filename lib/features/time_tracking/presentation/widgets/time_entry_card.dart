import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';

class TimeEntryCard extends StatelessWidget {
  const TimeEntryCard({
    required this.entry,
    required this.onStopSession,
    super.key,
  });

  final TimeEntry entry;
  final VoidCallback? onStopSession;

  static Color _colorForCategory(TaskCategory cat) => switch (cat) {
    TaskCategory.productive => const Color(0xFF22D3A6),
    TaskCategory.learning => const Color(0xFF818CF8),
    TaskCategory.break_ => const Color(0xFFFBBC05),
    TaskCategory.distraction => const Color(0xFFEA4335),
    TaskCategory.other => const Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final duration = _formatDuration(entry.duration);
    final accent = scheme.primary;
    final dotColor = entry.isActive
        ? accent
        : _colorForCategory(entry.category);

    final subtitle = entry.isActive
        ? '${entry.category.label} · ${AppStrings.inProgress}'
        : '${entry.category.label} · $duration';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: entry.isActive
            ? Border.all(color: accent.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status dot
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: entry.isActive
                ? _PulsingDot(color: dotColor)
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          // Task + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.taskName.isEmpty
                      ? AppStrings.unknownTask
                      : entry.taskName,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Duration + live / stop
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _clock(entry.duration),
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              if (entry.isActive)
                GestureDetector(
                  onTap: onStopSession,
                  child: Text(
                    'Live',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Reference shows mm:ss (e.g. 17:48) — promotes to h:mm:ss past an hour.
  String _clock(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    final s = value.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
