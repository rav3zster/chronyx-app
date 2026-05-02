import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final String startedAt = DateFormat.Hm().format(entry.startedAt.toLocal());
    final String duration = _formatDuration(entry.duration);
    final catColor = _colorForCategory(entry.category);

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: entry.isActive ? catColor.withValues(alpha: 0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category color bar
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.taskName.isEmpty
                            ? AppStrings.unknownTask
                            : entry.taskName,
                        style: textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.isActive)
                      _PulsingDot(color: catColor),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${entry.category.emoji} ${entry.category.label}',
                      style: textTheme.labelSmall?.copyWith(
                        color: catColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '  ·  $startedAt',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: entry.isActive
                          ? catColor
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.isActive
                          ? duration
                          : AppStrings.inProgress,
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.isActive
                            ? catColor
                            : scheme.onSurfaceVariant,
                        fontWeight: entry.isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (entry.isActive)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                foregroundColor: scheme.error,
              ),
              onPressed: onStopSession,
              child: const Text(AppStrings.stopSession),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    final String hh = hours.toString().padLeft(2, '0');
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
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
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
