import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/core/widgets/app_error_view.dart';
import 'package:chronyx/core/widgets/page_header.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/life_insights/presentation/pages/session_celebration_sheet.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/session_prefill_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/widgets/time_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout tokens (sizing only — all colors come from the active theme so the
// screen reacts to theme switching like the rest of the app).
// ─────────────────────────────────────────────────────────────────────────────
const _kRadius = 20.0;
const _kPad = 20.0;

class TimeTrackingPage extends ConsumerStatefulWidget {
  const TimeTrackingPage({super.key});

  @override
  ConsumerState<TimeTrackingPage> createState() => _TimeTrackingPageState();
}

class _TimeTrackingPageState extends ConsumerState<TimeTrackingPage> {
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocus = FocusNode();
  TaskCategory _selectedCategory = TaskCategory.productive;
  SessionMode _selectedMode = SessionMode.stopwatch;
  int? _targetDurationMinutes;

  /// Project task this next session should be attributed to (from a prefill).
  String? _pendingProjectTaskId;

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Apply a prefill that was set before this page was first built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefill = ref.read(sessionPrefillProvider);
      if (prefill != null) {
        _taskController.text = prefill.taskName;
        _pendingProjectTaskId = prefill.projectTaskId;
        setState(() => _selectedCategory = prefill.category);
        ref.read(sessionPrefillProvider.notifier).state = null;
      }
    });
  }

  Future<void> _startSession() async {
    final notifier = ref.read(timeEntriesProvider.notifier);
    final taskName = _taskController.text.trim();
    final linkedTaskId = _pendingProjectTaskId;

    // Check for existing active session
    final entries = ref.read(timeEntriesProvider).value ?? <TimeEntry>[];
    TimeEntry? activeSession;
    for (final e in entries) {
      if (e.isActive) {
        activeSession = e;
        break;
      }
    }

    if (activeSession != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => _ActiveSessionDialog(activeSession: activeSession!),
      );
      if (choice == null || choice == 'resume') {
        // Resume / dismiss does not start a new session
        return;
      }
      try {
        if (choice == 'pause') {
          await notifier.pauseSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'stop') {
          await notifier.stopSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'delete') {
          await notifier.deleteSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'startAnyway') {
          await notifier.stopSession(sessionId: activeSession.id);
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
        );
        return;
      }
    }

    try {
      await notifier.startSession(
        taskName: taskName,
        category: _selectedCategory,
        projectTaskId: linkedTaskId,
        sessionMode: _selectedMode,
        targetDurationMinutes: _selectedMode == SessionMode.timer ? _targetDurationMinutes : null,
        ignoreActiveCheck: true,
      );
      _taskController.clear();
      _taskFocus.unfocus();
      _pendingProjectTaskId = null; // consumed by this session
    } catch (error) {
      if (!mounted) return;
      final message = ErrorMessageMapper.fromError(error);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _stopSession(String id) async {
    final finished = await ref
        .read(timeEntriesProvider.notifier)
        .stopSession(sessionId: id);
    if (!mounted || finished == null) return;

    // Close the execution loop: attribute the session to its project task.
    final linkedTaskId = finished.projectTaskId;
    if (linkedTaskId != null) {
      final minutes = finished.duration.inMinutes;
      if (minutes > 0) {
        try {
          await ref
              .read(projectRepositoryProvider)
              .attributeSessionMinutes(
                projectTaskId: linkedTaskId,
                minutes: minutes,
              );
          // Refresh the intelligence layer so the dashboard feels alive.
          ref.read(projectsProvider.notifier).refresh();
          ref.read(analyticsProvider.notifier).refresh();
        } catch (_) {
          // Attribution is best-effort; never block the celebration.
        }
      }
    }

    if (!mounted) return;
    await showSessionCelebration(context, justFinished: finished);
  }

  Future<void> _pauseSession(String id) async {
    try {
      await ref.read(timeEntriesProvider.notifier).pauseSession(sessionId: id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
      );
    }
  }

  Future<void> _resumeSession(TimeEntry entry) async {
    final notifier = ref.read(timeEntriesProvider.notifier);
    final entries = ref.read(timeEntriesProvider).value ?? <TimeEntry>[];

    TimeEntry? activeSession;
    for (final e in entries) {
      if (e.isActive && e.id != entry.id) {
        activeSession = e;
        break;
      }
    }

    if (activeSession != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => _ActiveSessionDialog(activeSession: activeSession!),
      );
      if (choice == null || choice == 'resume') {
        return;
      }
      try {
        if (choice == 'pause') {
          await notifier.pauseSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'stop') {
          await notifier.stopSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'delete') {
          await notifier.deleteSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'startAnyway') {
          await notifier.stopSession(sessionId: activeSession.id);
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
        );
        return;
      }
    }

    try {
      await notifier.resumeSession(sessionId: entry.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
      );
    }
  }

  Future<void> _editSession(TimeEntry entry) async {
    final nameController = TextEditingController(text: entry.taskName);
    TaskCategory category = entry.category;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Edit Session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Task Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskCategory>(
                    value: category,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: TaskCategory.selectable.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => category = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        try {
          await ref.read(timeEntriesProvider.notifier).updateSession(
            sessionId: entry.id,
            taskName: name,
            category: category,
          );
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
          );
        }
      }
    }
  }

  Future<void> _deleteSession(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(timeEntriesProvider.notifier).deleteSession(sessionId: id);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessageMapper.fromError(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesState = ref.watch(timeEntriesProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isCompact = context.isCompact;

    // Consume a one-shot prefill handed off from a project's Today's Focus.
    ref.listen<SessionPrefill?>(sessionPrefillProvider, (_, prefill) {
      if (prefill == null) return;
      _taskController.text = prefill.taskName;
      _pendingProjectTaskId = prefill.projectTaskId;
      setState(() => _selectedCategory = prefill.category);
      // Clear so it doesn't re-apply on the next rebuild.
      ref.read(sessionPrefillProvider.notifier).state = null;
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: context.responsiveValue(
            compact: Breakpoints.maxContent,
            medium: Breakpoints.maxContent,
            expanded: Breakpoints.maxDoubleContent,
          ),
          child: isCompact
              ? CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 0),
                      sliver: const SliverToBoxAdapter(child: _Header()),
                    ),
                    // Focus ratio banner
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(_kPad, 18, _kPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _FocusBanner(stats: focusStats),
                      ),
                    ),
                    // New session card
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(_kPad, 16, _kPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _NewSessionCard(
                          controller: _taskController,
                          focusNode: _taskFocus,
                          selected: _selectedCategory,
                          mode: _selectedMode,
                          targetDurationMinutes: _targetDurationMinutes,
                          isLoading: timeEntriesState.isLoading,
                          onSelectCategory: (c) =>
                              setState(() => _selectedCategory = c),
                          onSelectMode: (m) =>
                              setState(() => _selectedMode = m),
                          onSelectTargetDuration: (mins) =>
                              setState(() => _targetDurationMinutes = mins),
                          onStart: _startSession,
                        ),
                      ),
                    ),
                    // Sessions header
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(_kPad, 28, _kPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _Label(AppStrings.sessionsHeader),
                      ),
                    ),
                    // Sessions list
                    timeEntriesState.when(
                      data: (entries) => _SessionSliver(
                        entries: entries,
                        onStopSession: _stopSession,
                        onPauseSession: _pauseSession,
                        onResumeSession: _resumeSession,
                        onEditSession: _editSession,
                        onDeleteSession: _deleteSession,
                        bottomInset: bottomInset,
                      ),
                      error: (error, _) => SliverPadding(
                        padding: const EdgeInsets.fromLTRB(_kPad, 40, _kPad, 0),
                        sliver: SliverToBoxAdapter(
                          child: AppErrorView(
                            message: ErrorMessageMapper.fromError(error),
                            onRetry: () => ref
                                .read(timeEntriesProvider.notifier)
                                .refreshEntries(),
                          ),
                        ),
                      ),
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 0),
                      sliver: const SliverToBoxAdapter(child: _Header()),
                    ),
                    // Side-by-side layout for wide screens
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(_kPad, 18, _kPad, 120 + bottomInset),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Focus Banner + New Session Card)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FocusBanner(stats: focusStats),
                                  const SizedBox(height: 16),
                                  _NewSessionCard(
                                    controller: _taskController,
                                    focusNode: _taskFocus,
                                    selected: _selectedCategory,
                                    mode: _selectedMode,
                                    targetDurationMinutes: _targetDurationMinutes,
                                    isLoading: timeEntriesState.isLoading,
                                    onSelectCategory: (c) =>
                                        setState(() => _selectedCategory = c),
                                    onSelectMode: (m) =>
                                        setState(() => _selectedMode = m),
                                    onSelectTargetDuration: (mins) =>
                                        setState(() => _targetDurationMinutes = mins),
                                    onStart: _startSession,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Column (Sessions Header + Sessions List)
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label(AppStrings.sessionsHeader),
                                  const SizedBox(height: 12),
                                  timeEntriesState.when(
                                    data: (entries) {
                                      if (entries.isEmpty) {
                                        return const _NoSessionsView();
                                      }
                                      return Column(
                                        children: entries.map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: TimeEntryCard(
                                              entry: entry,
                                              onStopSession: entry.isActive
                                                  ? () => _stopSession(entry.id)
                                                  : null,
                                              onPauseSession: () => _pauseSession(entry.id),
                                              onResumeSession: () => _resumeSession(entry),
                                              onEditSession: () => _editSession(entry),
                                              onDeleteSession: () => _deleteSession(entry.id),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                    error: (error, _) => AppErrorView(
                                      message: ErrorMessageMapper.fromError(error),
                                      onRetry: () => ref
                                          .read(timeEntriesProvider.notifier)
                                          .refreshEntries(),
                                    ),
                                    loading: () => const Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 48),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — large title + settings
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const PageHeader(title: AppStrings.timeTrackingTitle);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus ratio banner — left accent bar, percentage, focused/away
// ─────────────────────────────────────────────────────────────────────────────

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({required this.stats});
  final FocusStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratio = stats.focusRatio;
    final pct = (ratio * 100).toStringAsFixed(0);
    final accent = ratio >= 0.8
        ? const Color(0xFF22D3A6)
        : (ratio >= 0.5 ? scheme.primary : scheme.error);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAB FOCUS · $pct%',
                  style: textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmt(stats.focusedSeconds)} focused · ${_fmt(stats.awaySeconds)} away',
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

// ─────────────────────────────────────────────────────────────────────────────
// New session card — task input, category chips, gold start button
// ─────────────────────────────────────────────────────────────────────────────

class _NewSessionCard extends StatelessWidget {
  const _NewSessionCard({
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.mode,
    required this.targetDurationMinutes,
    required this.isLoading,
    required this.onSelectCategory,
    required this.onSelectMode,
    required this.onSelectTargetDuration,
    required this.onStart,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TaskCategory selected;
  final SessionMode mode;
  final int? targetDurationMinutes;
  final bool isLoading;
  final ValueChanged<TaskCategory> onSelectCategory;
  final ValueChanged<SessionMode> onSelectMode;
  final ValueChanged<int?> onSelectTargetDuration;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW SESSION',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TASK',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Task input
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onStart(),
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: AppStrings.taskHint,
                hintStyle: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'CATEGORY',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _CategoryChips(selected: selected, onSelected: onSelectCategory),
          const SizedBox(height: 18),
          Text(
            'MODE',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ModeChip(
                label: 'Stopwatch',
                icon: Icons.timer_outlined,
                isSelected: mode == SessionMode.stopwatch,
                onTap: () {
                  onSelectMode(SessionMode.stopwatch);
                  onSelectTargetDuration(null);
                },
              ),
              const SizedBox(width: 12),
              _ModeChip(
                label: 'Timer',
                icon: Icons.hourglass_top_outlined,
                isSelected: mode == SessionMode.timer,
                onTap: () {
                  onSelectMode(SessionMode.timer);
                  onSelectTargetDuration(25); // default to 25 mins
                },
              ),
            ],
          ),
          if (mode == SessionMode.timer) ...[
            const SizedBox(height: 18),
            Text(
              'TARGET DURATION',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            _TargetDurationSelector(
              selectedMinutes: targetDurationMinutes ?? 25,
              onChanged: (mins) => onSelectTargetDuration(mins),
            ),
          ],
          const SizedBox(height: 20),
          _StartButton(isLoading: isLoading, onTap: onStart),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? scheme.inverseSurface : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.inverseSurface : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? scheme.onInverseSurface : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? scheme.onInverseSurface : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetDurationSelector extends StatelessWidget {
  const _TargetDurationSelector({
    required this.selectedMinutes,
    required this.onChanged,
  });

  final int selectedMinutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final presets = [15, 25, 45, 60];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: presets.map((mins) {
            final isPresetSelected = selectedMinutes == mins;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(mins),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPresetSelected ? scheme.primary : scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPresetSelected ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '${mins}M',
                    style: textTheme.labelMedium?.copyWith(
                      color: isPresetSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: scheme.onSurfaceVariant),
              onPressed: selectedMinutes > 5 ? () => onChanged(selectedMinutes - 5) : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                '$selectedMinutes mins',
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: scheme.onSurfaceVariant),
              onPressed: () => onChanged(selectedMinutes + 5),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start button — full-width gold pill
// ─────────────────────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                  ),
                )
              : Text(
                  AppStrings.startSession,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chips — selected = solid hero pill, unselected = subtle fill
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: TaskCategory.selectable.map((cat) {
            final isSelected = cat == selected;
            return GestureDetector(
              onTap: () => onSelected(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.inverseSurface : scheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? scheme.inverseSurface
                        : scheme.outlineVariant,
                  ),
                ),
                child: Text(
                  cat.label.toUpperCase(),
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? scheme.onInverseSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          })
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label — small caps, muted
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session list (sliver)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionSliver extends StatelessWidget {
  const _SessionSliver({
    required this.entries,
    required this.onStopSession,
    required this.onPauseSession,
    required this.onResumeSession,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.bottomInset,
  });

  final List<TimeEntry> entries;
  final Future<void> Function(String id) onStopSession;
  final Future<void> Function(String id) onPauseSession;
  final Future<void> Function(TimeEntry entry) onResumeSession;
  final Future<void> Function(TimeEntry entry) onEditSession;
  final Future<void> Function(String id) onDeleteSession;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SliverToBoxAdapter(
        child: _NoSessionsView(),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(_kPad, 12, _kPad, 120 + bottomInset),
      sliver: SliverList.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return TimeEntryCard(
            entry: entry,
            onStopSession: entry.isActive
                ? () => onStopSession(entry.id)
                : null,
            onPauseSession: () => onPauseSession(entry.id),
            onResumeSession: () => onResumeSession(entry),
            onEditSession: () => onEditSession(entry),
            onDeleteSession: () => onDeleteSession(entry.id),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable empty sessions state view
// ─────────────────────────────────────────────────────────────────────────────

class _NoSessionsView extends StatelessWidget {
  const _NoSessionsView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              AppStrings.noSessionsYet,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionDialog extends StatelessWidget {
  const _ActiveSessionDialog({required this.activeSession});
  final TimeEntry activeSession;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surface,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text('Active Session Running'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are currently tracking:',
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeSession.taskName.isEmpty ? 'Unnamed' : activeSession.taskName,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeSession.category.label,
                        style: textTheme.bodySmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What would you like to do?',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'resume'),
              child: const Text('Resume Session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'pause'),
              child: const Text('Pause Session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'stop'),
              child: const Text('Stop Session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete Session'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'startAnyway'),
              child: const Text('Start New Session Anyway'),
            ),
          ],
        ),
      ],
    );
  }
}
