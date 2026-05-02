import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/input_field.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/widgets/time_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/core/widgets/app_error_view.dart';

class TimeTrackingPage extends ConsumerStatefulWidget {
  const TimeTrackingPage({super.key});

  @override
  ConsumerState<TimeTrackingPage> createState() => _TimeTrackingPageState();
}

class _TimeTrackingPageState extends ConsumerState<TimeTrackingPage> {
  final TextEditingController _taskController = TextEditingController();
  TaskCategory _selectedCategory = TaskCategory.productive;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final notifier = ref.read(timeEntriesProvider.notifier);
    final taskName = _taskController.text.trim();
    try {
      await notifier.startSession(
        taskName: taskName,
        category: _selectedCategory,
      );
      _taskController.clear();
    } catch (error) {
      if (!mounted) return;
      final message = ErrorMessageMapper.fromError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _stopSession(String id) async {
    await ref.read(timeEntriesProvider.notifier).stopSession(sessionId: id);
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesState = ref.watch(timeEntriesProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timeTrackingTitle),
        actions: const [
          SettingsIconButton(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Focus Ratio Banner ─────────────────────────────────────
            _FocusRatioBanner(stats: focusStats),
            const SizedBox(height: AppSpacing.md),

            // ── Session Starter Card ───────────────────────────────────
            GlassCard(
              useBlur: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Session',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InputField(
                    controller: _taskController,
                    label: 'Task Name',
                    hint: AppStrings.taskHint,
                    prefixIcon: Icon(
                      Icons.label_outline_rounded,
                      color: scheme.onSurfaceVariant,
                      size: AppSpacing.iconMd,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _startSession(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Category',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _CategoryChips(
                    selected: _selectedCategory,
                    onSelected: (c) => setState(() => _selectedCategory = c),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: AppStrings.startSession,
                    onPressed: _startSession,
                    isLoading: timeEntriesState.isLoading,
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: AppSpacing.iconMd,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.sessionsHeader,
              style: textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: timeEntriesState.when(
                data: (entries) => _SessionList(
                  entries: entries,
                  onStopSession: _stopSession,
                ),
                error: (error, _) => AppErrorView(
                  message: ErrorMessageMapper.fromError(error),
                  onRetry: () =>
                      ref.read(timeEntriesProvider.notifier).refreshEntries(),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Focus Ratio Banner ────────────────────────────────────────────────────────

class _FocusRatioBanner extends StatelessWidget {
  const _FocusRatioBanner({required this.stats});
  final FocusStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratio = stats.focusRatio;
    final pct = (ratio * 100).toStringAsFixed(0);
    final color =
        ratio >= 0.8 ? const Color(0xFF22D3A6) : (ratio >= 0.5 ? scheme.primary : scheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.center_focus_strong_rounded,
              color: color, size: AppSpacing.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tab Focus: $pct%',
                  style: textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_fmt(stats.focusedSeconds)} focused · ${_fmt(stats.awaySeconds)} away this session',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

// ── Category Chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onSelected;

  Color _colorForCategory(TaskCategory cat) => switch (cat) {
        TaskCategory.productive => const Color(0xFF22D3A6),
        TaskCategory.learning => const Color(0xFF818CF8),
        TaskCategory.break_ => const Color(0xFFFBBC05),
        TaskCategory.distraction => const Color(0xFFEA4335),
        TaskCategory.other => const Color(0xFF94A3B8),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: TaskCategory.values.map((cat) {
        final isSelected = cat == selected;
        final color = _colorForCategory(cat);
        return GestureDetector(
          onTap: () => onSelected(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(
                color: isSelected ? color : scheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  cat.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected ? color : scheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Session List ──────────────────────────────────────────────────────────────

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.entries,
    required this.onStopSession,
  });

  final List<TimeEntry> entries;
  final Future<void> Function(String id) onStopSession;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: AppSpacing.iconXl * 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.noSessionsYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding:
          const EdgeInsets.only(bottom: AppSpacing.xxxl + AppSpacing.lg),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return TimeEntryCard(
          entry: entry,
          onStopSession:
              entry.isActive ? () => onStopSession(entry.id) : null,
        );
      },
    );
  }
}
