import 'dart:async';
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
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kRadius = 24.0;
const _kPad = 20.0;

class TimeTrackingPage extends ConsumerStatefulWidget {
  const TimeTrackingPage({super.key});

  @override
  ConsumerState<TimeTrackingPage> createState() => _TimeTrackingPageState();
}

class _TimeTrackingPageState extends ConsumerState<TimeTrackingPage> {
  int _selectedTab = 0; // 0 = Focus, 1 = Timeline, 2 = Stats
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocus = FocusNode();
  TaskCategory _selectedCategory = TaskCategory.productive;
  SessionMode _selectedMode = SessionMode.stopwatch;
  int? _targetDurationMinutes;
  String? _pendingProjectTaskId;

  // Search & Filter UI controllers
  final TextEditingController _searchController = TextEditingController();
  final Set<TimelineGroup> _collapsedGroups = {};

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefill = ref.read(sessionPrefillProvider);
      if (prefill != null) {
        _taskController.text = prefill.taskName;
        _pendingProjectTaskId = prefill.projectTaskId;
        setState(() {
          _selectedCategory = prefill.category;
          _selectedTab = 0; // force tab back to Focus
        });
        ref.read(sessionPrefillProvider.notifier).state = null;
      }
    });

    _searchController.addListener(() {
      ref.read(sessionSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  Future<void> _startSession() async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final notifier = ref.read(timeEntriesProvider.notifier);
    final taskName = _taskController.text.trim();
    final linkedTaskId = _pendingProjectTaskId;

    final entries = ref.read(timeEntriesProvider).value ?? <TimeEntry>[];
    TimeEntry? activeSession = entries.where((e) => e.isActive || e.isPaused).firstOrNull;

    if (activeSession != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => _ActiveSessionDialog(activeSession: activeSession),
      );
      if (choice == null || choice == 'resume') return;
      try {
        if (choice == 'pause') {
          await notifier.pauseSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'stop') {
          await _stopSession(activeSession.id);
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
        targetDurationMinutes: (_selectedMode == SessionMode.timer || _selectedMode == SessionMode.pomodoro) ? _targetDurationMinutes : null,
        ignoreActiveCheck: true,
      );
      _taskController.clear();
      _taskFocus.unfocus();
      _pendingProjectTaskId = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessageMapper.fromError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopSession(String id) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final finished = await ref
        .read(timeEntriesProvider.notifier)
        .stopSession(sessionId: id);
    if (!mounted || finished == null) return;

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
          ref.read(projectsProvider.notifier).refresh();
          ref.read(analyticsProvider.notifier).refresh();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    await showSessionCelebration(context, justFinished: finished);
  }

  Future<void> _pauseSession(String id) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
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
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final notifier = ref.read(timeEntriesProvider.notifier);
    final entries = ref.read(timeEntriesProvider).value ?? <TimeEntry>[];
    TimeEntry? activeSession = entries.where((e) => e.isActive && e.id != entry.id).firstOrNull;

    if (activeSession != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => _ActiveSessionDialog(activeSession: activeSession),
      );
      if (choice == null || choice == 'resume') return;
      try {
        if (choice == 'pause') {
          await notifier.pauseSession(sessionId: activeSession.id);
          return;
        } else if (choice == 'stop') {
          await _stopSession(activeSession.id);
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
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final nameController = TextEditingController(text: entry.taskName);
    final notesController = TextEditingController(text: entry.notes ?? '');
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Task Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskCategory>(
                      initialValue: category,
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
                    const SizedBox(height: 16),
                    const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: 'Add notes about your session...',
                      ),
                    ),
                  ],
                ),
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
      final notesVal = notesController.text.trim();
      if (name.isNotEmpty) {
        try {
          await ref.read(timeEntriesProvider.notifier).updateSession(
            sessionId: entry.id,
            taskName: name,
            category: category,
            notes: notesVal.isEmpty ? null : notesVal,
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
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
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

  Future<void> _showMergeDialog(TimeEntry laterEntry, TimeEntry earlierEntry) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final nameController = TextEditingController(text: laterEntry.taskName);
    TaskCategory selectedCategory = laterEntry.category;

    final notesBuffer = StringBuffer();
    if (laterEntry.notes != null && laterEntry.notes!.trim().isNotEmpty) {
      notesBuffer.write(laterEntry.notes!.trim());
    }
    if (earlierEntry.notes != null && earlierEntry.notes!.trim().isNotEmpty) {
      if (notesBuffer.isNotEmpty) notesBuffer.write('\n\n');
      notesBuffer.write(earlierEntry.notes!.trim());
    }
    final notesController = TextEditingController(text: notesBuffer.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Merge Consecutive Sessions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Merge details:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${laterEntry.taskName} (${laterEntry.duration.inMinutes}m)', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('• ${earlierEntry.taskName} (${earlierEntry.duration.inMinutes}m)', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Merged Task Name', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<TaskCategory>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: TaskCategory.selectable.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Combined Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'Notes combined from both sessions...',
                  ),
                ),
              ],
            ),
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
              child: const Text('Merge'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      final startTime = earlierEntry.startedAt;
      final endTime = laterEntry.endedAt;
      final elapsedSecs = laterEntry.elapsedSeconds + earlierEntry.elapsedSeconds;
      final pausedSecs = laterEntry.pausedDurationSeconds + earlierEntry.pausedDurationSeconds;
      final totalSecs = laterEntry.elapsedSeconds + earlierEntry.elapsedSeconds;

      final double completionPercentage;
      if (totalSecs > 0) {
        completionPercentage = ((laterEntry.elapsedSeconds * laterEntry.completionPercentage) +
            (earlierEntry.elapsedSeconds * earlierEntry.completionPercentage)) / totalSecs;
      } else {
        completionPercentage = 100.0;
      }

      try {
        await ref.read(timeEntriesProvider.notifier).mergeSessions(
          firstSessionId: laterEntry.id,
          secondSessionId: earlierEntry.id,
          mergedTaskName: name,
          mergedCategory: selectedCategory,
          mergedStartTime: startTime,
          mergedEndTime: endTime,
          mergedElapsedSeconds: elapsedSecs,
          mergedPausedSeconds: pausedSecs,
          mergedCompletionPercentage: completionPercentage,
          mergedNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessions merged successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    }
  }

  void _showFiltersBottomSheet() {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kRadius)),
      ),
      builder: (context) => _FilterBottomSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;
    final timeEntriesState = ref.watch(timeEntriesProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    ref.listen<SessionPrefill?>(sessionPrefillProvider, (_, prefill) {
      if (prefill == null) return;
      _taskController.text = prefill.taskName;
      _pendingProjectTaskId = prefill.projectTaskId;
      setState(() {
        _selectedCategory = prefill.category;
        _selectedTab = 0; // Switch to focus
      });
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header ────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(_kPad, 12, _kPad, 0),
                child: PageHeader(title: AppStrings.timeTrackingTitle),
              ),
              const SizedBox(height: 12),

              // ── Tab Bar Navigation ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPad),
                child: _CustomSegmentedTabBar(
                  selectedIndex: _selectedTab,
                  onTabSelected: (index) {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    setState(() => _selectedTab = index);
                  },
                ),
              ),
              const SizedBox(height: 18),

              // ── Active Tab View ───────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.05),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildSelectedTabContent(isCompact, timeEntriesState, focusStats, bottomInset),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(
    bool isCompact,
    AsyncValue<List<TimeEntry>> timeEntriesState,
    FocusStats focusStats,
    double bottomInset,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildFocusTab(isCompact, timeEntriesState, focusStats, bottomInset);
      case 1:
        return _buildTimelineTab(timeEntriesState, bottomInset);
      case 2:
        return _buildStatsTab(bottomInset);
      default:
        return const SizedBox();
    }
  }

  // ── Tab 1: Focus Timer Mode ────────────────────────────────────────────────
  Widget _buildFocusTab(
    bool isCompact,
    AsyncValue<List<TimeEntry>> timeEntriesState,
    FocusStats focusStats,
    double bottomInset,
  ) {
    final entries = timeEntriesState.value ?? <TimeEntry>[];
    final activeEntry = entries.where((e) => e.isOngoing).firstOrNull;

    return CustomScrollView(
      key: const ValueKey('focus_scroll'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _FocusBanner(stats: focusStats),
                const SizedBox(height: 16),
                if (activeEntry != null) ...[
                  // Ongoing Session Card in Focus tab
                  Text(
                    'ONGOING TRACKING',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TimeEntryCard(
                    entry: activeEntry,
                    onStopSession: () => _stopSession(activeEntry.id),
                    onPauseSession: () => _pauseSession(activeEntry.id),
                    onResumeSession: () => _resumeSession(activeEntry),
                    onEditSession: () => _editSession(activeEntry),
                    onDeleteSession: () => _deleteSession(activeEntry.id),
                  ),
                  const SizedBox(height: 32),
                ],
                _NewSessionCard(
                  controller: _taskController,
                  focusNode: _taskFocus,
                  selected: _selectedCategory,
                  mode: _selectedMode,
                  targetDurationMinutes: _targetDurationMinutes,
                  isLoading: timeEntriesState.isLoading,
                  onSelectCategory: (c) => setState(() => _selectedCategory = c),
                  onSelectMode: (m) => setState(() => _selectedMode = m),
                  onSelectTargetDuration: (mins) => setState(() => _targetDurationMinutes = mins),
                  onStart: _startSession,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: 120 + bottomInset),
        ),
      ],
    );
  }

  // ── Tab 2: Timeline View ───────────────────────────────────────────────────
  Widget _buildTimelineTab(
    AsyncValue<List<TimeEntry>> timeEntriesState,
    double bottomInset,
  ) {
    final groupedTimeline = ref.watch(timelineEntriesProvider);
    final search = ref.watch(sessionSearchQueryProvider);
    final filters = ref.watch(sessionFiltersProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Count active filters
    int activeFiltersCount = 0;
    if (filters.dateRangePreset != DateRangePreset.all) activeFiltersCount++;
    if (filters.category != null) activeFiltersCount++;
    if (filters.sessionMode != null) activeFiltersCount++;
    if (filters.status != null) activeFiltersCount++;

    return Column(
      key: const ValueKey('timeline_layout'),
      children: [
        // Search & Filter Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.search, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Search sessions...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 4),
                          ),
                        ),
                      ),
                      if (search.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _showFiltersBottomSheet,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: activeFiltersCount > 0
                            ? scheme.primary.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: activeFiltersCount > 0 ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.filter_list_rounded,
                        color: activeFiltersCount > 0 ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (activeFiltersCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$activeFiltersCount',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Timeline Scroll list
        Expanded(
          child: timeEntriesState.when(
            data: (entries) {
              if (groupedTimeline.isEmpty) {
                return const Center(child: _NoSessionsView());
              }

              // Calculate flat list items including headers
              final List<dynamic> listItems = [];
              for (final group in TimelineGroup.values) {
                if (groupedTimeline.containsKey(group)) {
                  listItems.add(group);
                  if (!_collapsedGroups.contains(group)) {
                    listItems.addAll(groupedTimeline[group]!);
                  }
                }
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(_kPad, 8, _kPad, 120 + bottomInset),
                physics: const BouncingScrollPhysics(),
                itemCount: listItems.length,
                itemBuilder: (context, index) {
                  final item = listItems[index];
                  if (item is TimelineGroup) {
                    final groupEntries = groupedTimeline[item] ?? [];
                    final totalSeconds = groupEntries.fold<int>(0, (sum, e) => sum + e.elapsedSeconds);
                    final isCollapsed = _collapsedGroups.contains(item);

                    return _TimelineHeader(
                      group: item,
                      totalSeconds: totalSeconds,
                      isCollapsed: isCollapsed,
                      onToggle: () {
                        ref.read(soundServiceProvider).buttonPress();
                        ref.read(hapticServiceProvider).buttonPress();
                        setState(() {
                          if (isCollapsed) {
                            _collapsedGroups.remove(item);
                          } else {
                            _collapsedGroups.add(item);
                          }
                        });
                      },
                    );
                  } else if (item is TimeEntry) {
                    // Find indices in global entries list to check for consecutive merging
                    final group = groupedTimeline.entries.firstWhere((g) => g.value.contains(item)).key;
                    final groupList = groupedTimeline[group] ?? [];
                    final itemIdx = groupList.indexOf(item);
                    
                    VoidCallback? onMerge;
                    if (itemIdx < groupList.length - 1) {
                      final previousItem = groupList[itemIdx + 1];
                      if (!item.isOngoing && !previousItem.isOngoing) {
                        onMerge = () => _showMergeDialog(item, previousItem);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TimeEntryCard(
                        entry: item,
                        onStopSession: item.isActive ? () => _stopSession(item.id) : null,
                        onPauseSession: () => _pauseSession(item.id),
                        onResumeSession: () => _resumeSession(item),
                        onEditSession: () => _editSession(item),
                        onDeleteSession: () => _deleteSession(item.id),
                        onMergeWithPrevious: onMerge,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => AppErrorView(
              message: ErrorMessageMapper.fromError(err),
              onRetry: () => ref.read(timeEntriesProvider.notifier).refreshEntries(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Statistics Dashboard ────────────────────────────────────────────
  Widget _buildStatsTab(double bottomInset) {
    final stats = ref.watch(timeTrackingStatsProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final heatmap = ref.watch(heatmapDataProvider);
    final timeframe = ref.watch(breakdownTimeframeProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      key: const ValueKey('stats_scroll'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(_kPad, 0, _kPad, 120 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Derived Stats Grid Cards (Apple Fitness inspired)
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _StatsCard(
                    title: 'FOCUS SCORE',
                    value: '${stats.focusScore}',
                    subtitle: 'Consistency & Depth',
                    icon: Icons.auto_awesome,
                    accentColor: const Color(0xFF818CF8),
                    ringProgress: stats.focusScore / 100.0,
                  ),
                  _StatsCard(
                    title: 'DEEP WORK',
                    value: '${stats.deepWorkHours.toStringAsFixed(1)} hrs',
                    subtitle: 'Productive hours',
                    icon: Icons.psychology,
                    accentColor: const Color(0xFF22D3A6),
                  ),
                  _StatsCard(
                    title: 'STREAK',
                    value: '${stats.weeklyStreak} days',
                    subtitle: 'Active focus streak',
                    icon: Icons.local_fire_department,
                    accentColor: Colors.orange,
                  ),
                  _StatsCard(
                    title: 'AVERAGE SESSION',
                    value: '${stats.averageSessionLengthMinutes.round()}m',
                    subtitle: 'Minutes per session',
                    icon: Icons.timelapse,
                    accentColor: Colors.teal,
                  ),
                  _StatsCard(
                    title: 'COMPLETED',
                    value: '${stats.sessionsCompleted}',
                    subtitle: 'Total finished logs',
                    icon: Icons.check_circle_outline,
                    accentColor: const Color(0xFF4ADE80),
                  ),
                  _StatsCard(
                    title: 'TOP CATEGORY',
                    value: stats.mostUsedCategory?.label ?? 'None',
                    subtitle: 'Most active context',
                    icon: Icons.category_outlined,
                    accentColor: scheme.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Heatmap View
          FocusHeatmap(heatmapData: heatmap),
          const SizedBox(height: 20),

          // Breakdown View with Toggle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CATEGORY RATIO',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TimeframeButton(
                          label: 'WEEK',
                          isSelected: timeframe == BreakdownTimeframe.weekly,
                          onTap: () {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            ref.read(breakdownTimeframeProvider.notifier).state = BreakdownTimeframe.weekly;
                          },
                        ),
                        const SizedBox(width: 8),
                        _TimeframeButton(
                          label: 'MONTH',
                          isSelected: timeframe == BreakdownTimeframe.monthly,
                          onTap: () {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            ref.read(breakdownTimeframeProvider.notifier).state = BreakdownTimeframe.monthly;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CategoryPieChart(breakdown: breakdown),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segmented Tab Selector ───────────────────────────────────────────────────
class _CustomSegmentedTabBar extends StatelessWidget {
  const _CustomSegmentedTabBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = ['Focus', 'Timeline', 'Stats'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 8) / 3;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(3, (index) {
                  final isSelected = selectedIndex == index;
                  return SizedBox(
                    width: width,
                    child: GestureDetector(
                      onTap: () => onTabSelected(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          tabs[index],
                          style: TextStyle(
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Focus Tab Banner ─────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAB FOCUS RATIO · $pct%',
                  style: textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
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

// ── New Session Input Card ───────────────────────────────────────────────────
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW FOCUS SESSION',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TASK NAME',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onStart(),
              style: textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: AppStrings.taskHint,
                hintStyle: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'CATEGORY',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          _CategoryChips(selected: selected, onSelected: onSelectCategory),
          const SizedBox(height: 18),
          Text(
            'TRACKING MODE',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
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
              const SizedBox(width: 10),
              _ModeChip(
                label: 'Timer',
                icon: Icons.hourglass_top_outlined,
                isSelected: mode == SessionMode.timer,
                onTap: () {
                  onSelectMode(SessionMode.timer);
                  onSelectTargetDuration(25);
                },
              ),
              const SizedBox(width: 10),
              _ModeChip(
                label: 'Pomodoro',
                icon: Icons.av_timer_outlined,
                isSelected: mode == SessionMode.pomodoro,
                onTap: () {
                  onSelectMode(SessionMode.pomodoro);
                  onSelectTargetDuration(25);
                },
              ),
            ],
          ),
          if (mode == SessionMode.timer || mode == SessionMode.pomodoro) ...[
            const SizedBox(height: 18),
            Text(
              'TARGET DURATION',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
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
                      color: isPresetSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${mins}M',
                    style: textTheme.labelMedium?.copyWith(
                      color: isPresetSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
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
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TaskCategory.selectable.map((cat) {
        final isSelected = cat == selected;
        return GestureDetector(
          onTap: () => onSelected(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? scheme.primary.withValues(alpha: 0.15) : scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  cat.label.toUpperCase(),
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 10,
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

// ── Timeline Group Header ────────────────────────────────────────────────────
class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.group,
    required this.totalSeconds,
    required this.isCollapsed,
    required this.onToggle,
  });

  final TimelineGroup group;
  final int totalSeconds;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    group.label.toUpperCase(),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTotalTime(totalSeconds),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTotalTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

// ── Empty State View ──────────────────────────────────────────────────────────
class _NoSessionsView extends StatelessWidget {
  const _NoSessionsView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 52,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noSessionsYet,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Focus Heatmap Widget ─────────────────────────────────────────────────────
class FocusHeatmap extends StatelessWidget {
  const FocusHeatmap({required this.heatmapData, super.key});
  final Map<DateTime, int> heatmapData;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final int daysSinceSunday = now.weekday % 7; 
    final startDate = today.subtract(Duration(days: 15 * 7 + daysSinceSunday));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FOCUS HEATMAP',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    _weekdayLabel('Sun', textTheme, scheme),
                    _weekdayLabel('Mon', textTheme, scheme),
                    _weekdayLabel('Tue', textTheme, scheme),
                    _weekdayLabel('Wed', textTheme, scheme),
                    _weekdayLabel('Thu', textTheme, scheme),
                    _weekdayLabel('Fri', textTheme, scheme),
                    _weekdayLabel('Sat', textTheme, scheme),
                  ],
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(16, (c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 18,
                            child: _monthLabelForWeek(startDate.add(Duration(days: c * 7)), textTheme, scheme),
                          ),
                          ...List.generate(7, (r) {
                            final cellDate = startDate.add(Duration(days: c * 7 + r));
                            final isFuture = cellDate.isAfter(today);
                            final mins = isFuture ? 0 : (heatmapData[cellDate] ?? 0);
                            
                            Color cellColor;
                            if (isFuture) {
                              cellColor = Colors.transparent;
                            } else if (mins == 0) {
                              cellColor = scheme.surfaceContainer.withValues(alpha: 0.4);
                            } else if (mins < 20) {
                              cellColor = scheme.primary.withValues(alpha: 0.2);
                            } else if (mins < 60) {
                              cellColor = scheme.primary.withValues(alpha: 0.45);
                            } else if (mins < 120) {
                              cellColor = scheme.primary.withValues(alpha: 0.7);
                            } else {
                              cellColor = scheme.primary;
                            }

                            return Tooltip(
                              message: isFuture 
                                  ? 'Future'
                                  : '${cellDate.day} ${_monthName(cellDate.month)}: $mins mins focused',
                              child: Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: cellColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: textTheme.bodySmall?.copyWith(fontSize: 10, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              _legendBox(scheme.surfaceContainer.withValues(alpha: 0.4)),
              const SizedBox(width: 3),
              _legendBox(scheme.primary.withValues(alpha: 0.2)),
              const SizedBox(width: 3),
              _legendBox(scheme.primary.withValues(alpha: 0.45)),
              const SizedBox(width: 3),
              _legendBox(scheme.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              _legendBox(scheme.primary),
              const SizedBox(width: 4),
              Text('More', style: textTheme.bodySmall?.copyWith(fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdayLabel(String label, TextTheme textTheme, ColorScheme scheme) {
    return SizedBox(
      height: 18,
      child: Center(
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _monthLabelForWeek(DateTime weekDate, TextTheme textTheme, ColorScheme scheme) {
    final prevWeekDate = weekDate.subtract(const Duration(days: 7));
    if (weekDate.month != prevWeekDate.month || weekDate.day <= 7) {
      return Text(
        _monthName(weekDate.month).substring(0, 3),
        style: textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return const SizedBox();
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _monthName(int month) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  }
}

// ── Statistics Grid Card Widget ──────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.ringProgress,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final double? ringProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const Spacer(),
          if (ringProgress != null)
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: ringProgress,
                        strokeWidth: 4.5,
                        backgroundColor: scheme.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                      Center(
                        child: Icon(Icons.flash_on, size: 12, color: accentColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Timeframe Selection Toggle Button ────────────────────────────────────────
class _TimeframeButton extends StatelessWidget {
  const _TimeframeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Category Breakdown custom pie chart ──────────────────────────────────────
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({required this.breakdown, super.key});
  final Map<TaskCategory, double> breakdown;

  static Color _colorForCategory(TaskCategory cat) => switch (cat) {
    TaskCategory.productive => const Color(0xFF22D3A6),
    TaskCategory.learning => const Color(0xFF818CF8),
    TaskCategory.break_ => const Color(0xFFFBBC05),
    TaskCategory.meeting => const Color(0xFFFB923C),
    TaskCategory.exercise => const Color(0xFF4ADE80),
    TaskCategory.entertainment => const Color(0xFFF472B6),
    TaskCategory.distraction => const Color(0xFFEA4335),
    TaskCategory.other => const Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final colorMap = Map.fromEntries(
      TaskCategory.values.map((cat) => MapEntry(cat, _colorForCategory(cat))),
    );

    if (breakdown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No completed sessions in this period.')),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return CustomPaint(
                    painter: _DonutChartPainter(
                      values: breakdown,
                      colors: colorMap,
                      animationValue: value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: breakdown.entries.map((entry) {
              final cat = entry.key;
              final pct = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _colorForCategory(cat),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.animationValue,
  });

  final Map<TaskCategory, double> values;
  final Map<TaskCategory, Color> colors;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.35;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    var startAngle = -3.14159265 / 2;

    for (final entry in values.entries) {
      final sweepAngle = (entry.value / 100.0) * 2 * 3.14159265 * animationValue;
      if (sweepAngle > 0.02) {
        paint.color = colors[entry.key] ?? Colors.grey;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.values != values;
  }
}

// ── Active Session / Multi Session Dialog ──────────────────────────────────────
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
          Text('What would you like to do?', style: textTheme.bodyMedium),
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
              child: const Text('Keep Active & Resume'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'pause'),
              child: const Text('Pause Running Session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context, 'stop'),
              child: const Text('Stop & Complete Session'),
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
              child: const Text('Discard Session'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, 'startAnyway'),
              child: const Text('Stop Session & Start New'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Filters Bottom Sheet ──────────────────────────────────────────────────────
class _FilterBottomSheet extends ConsumerWidget {
  const _FilterBottomSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(sessionFiltersProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILTER SESSIONS',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              TextButton(
                onPressed: () {
                  ref.read(soundServiceProvider).buttonPress();
                  ref.read(hapticServiceProvider).buttonPress();
                  ref.read(sessionFiltersProvider.notifier).state = const SessionFilters();
                  Navigator.pop(context);
                },
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range Preset
          Text('DATE RANGE', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DateRangePreset.values.map((preset) {
              final isSel = filters.dateRangePreset == preset;
              return GestureDetector(
                onTap: () async {
                  ref.read(soundServiceProvider).buttonPress();
                  ref.read(hapticServiceProvider).buttonPress();
                  if (preset == DateRangePreset.custom) {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now(),
                      initialDateRange: filters.customDateRange,
                    );
                    if (range != null) {
                      ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(
                        dateRangePreset: DateRangePreset.custom,
                        customDateRange: range,
                      );
                    }
                  } else {
                    ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(
                      dateRangePreset: preset,
                      clearCustomDateRange: true,
                    );
                  }
                },
                child: Chip(
                  label: Text(preset.label),
                  backgroundColor: isSel ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Category
          Text('CATEGORY', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(clearCategory: true);
                },
                child: Chip(
                  label: const Text('All Categories'),
                  backgroundColor: filters.category == null ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: filters.category == null ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: filters.category == null ? scheme.primary : scheme.outlineVariant),
                ),
              ),
              ...TaskCategory.selectable.map((cat) {
                final isSel = filters.category == cat;
                return GestureDetector(
                  onTap: () {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(category: cat);
                  },
                  child: Chip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    backgroundColor: isSel ? scheme.primary : Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                    side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Session Mode
          Text('SESSION MODE', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(clearSessionMode: true);
                },
                child: Chip(
                  label: const Text('All Modes'),
                  backgroundColor: filters.sessionMode == null ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: filters.sessionMode == null ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: filters.sessionMode == null ? scheme.primary : scheme.outlineVariant),
                ),
              ),
              ...SessionMode.values.map((mode) {
                final isSel = filters.sessionMode == mode;
                return GestureDetector(
                  onTap: () {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(sessionMode: mode);
                  },
                  child: Chip(
                    label: Text(mode.label),
                    backgroundColor: isSel ? scheme.primary : Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                    side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Status
          Text('STATUS', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(clearStatus: true);
                },
                child: Chip(
                  label: const Text('All Statuses'),
                  backgroundColor: filters.status == null ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: filters.status == null ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: filters.status == null ? scheme.primary : scheme.outlineVariant),
                ),
              ),
              ...SessionStatus.values.map((status) {
                final isSel = filters.status == status;
                return GestureDetector(
                  onTap: () {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    ref.read(sessionFiltersProvider.notifier).state = filters.copyWith(status: status);
                  },
                  child: Chip(
                    label: Text(status.label),
                    backgroundColor: isSel ? scheme.primary : Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                    side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('APPLY FILTERS'),
          ),
        ],
      ),
    );
  }
}
