import 'dart:async';

import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/core/services/focus_tracker.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/core/services/notification_service.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_supabase_datasource.dart';
import 'package:chronyx/features/time_tracking/data/repositories/time_tracking_repository_impl.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final focusTrackerProvider = Provider<FocusTracker>((ref) {
  final tracker = FocusTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
});

final timeTrackingRemoteDataSourceProvider =
    Provider<TimeTrackingRemoteDataSource>((ref) {
  return TimeTrackingSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final timeTrackingRepositoryProvider = Provider<TimeTrackingRepository>((ref) {
  return TimeTrackingRepositoryImpl(
    ref.watch(timeTrackingRemoteDataSourceProvider),
  );
});

// ── Focus ratio tracking ──────────────────────────────────────────────────────

final focusStatsProvider = NotifierProvider<FocusStatsNotifier, FocusStats>(
  FocusStatsNotifier.new,
);

class FocusStats {
  const FocusStats({this.focusedSeconds = 0, this.awaySeconds = 0});

  final int focusedSeconds;
  final int awaySeconds;

  int get totalSeconds => focusedSeconds + awaySeconds;

  double get focusRatio =>
      totalSeconds == 0 ? 1.0 : focusedSeconds / totalSeconds;
}

class FocusStatsNotifier extends Notifier<FocusStats> {
  Timer? _tick;
  StreamSubscription<bool>? _focusSub;
  bool _isFocused = true;

  @override
  FocusStats build() {
    final tracker = ref.watch(focusTrackerProvider);
    _isFocused = tracker.isFocused;

    _focusSub = tracker.focusStream.listen((focused) {
      _isFocused = focused;
    });

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (_isFocused) {
        state = FocusStats(
          focusedSeconds: s.focusedSeconds + 1,
          awaySeconds: s.awaySeconds,
        );
      } else {
        state = FocusStats(
          focusedSeconds: s.focusedSeconds,
          awaySeconds: s.awaySeconds + 1,
        );
      }
    });

    ref.onDispose(() {
      _tick?.cancel();
      _focusSub?.cancel();
    });

    return const FocusStats();
  }
}

// ── Time entries ──────────────────────────────────────────────────────────────

final timeEntriesProvider =
    AsyncNotifierProvider<TimeEntriesNotifier, List<TimeEntry>>(
  TimeEntriesNotifier.new,
);

class TimeEntriesNotifier extends AsyncNotifier<List<TimeEntry>> {
  TimeTrackingRepository get _repository =>
      ref.read(timeTrackingRepositoryProvider);

  Timer? _ticker;

  void _startTickerIfNeeded(List<TimeEntry> entries) {
    final bool hasActive = entries.any((e) => e.isActive);
    if (hasActive && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
        final current = state.value ?? <TimeEntry>[];
        bool updated = false;

        for (final entry in current) {
          if (entry.isActive &&
              (entry.sessionMode == SessionMode.timer ||
                  entry.sessionMode == SessionMode.pomodoro ||
                  entry.sessionMode == SessionMode.custom)) {
            final remaining = entry.remainingTime;
            if (remaining <= Duration.zero) {
              try {
                await stopSession(
                    sessionId: entry.id, status: SessionStatus.completed);
                _triggerCompletionEffects(entry);
                updated = true;
              } catch (e) {
                print('[AUTO STOP ERROR] failed to stop session: $e');
              }
            }
          }
        }

        if (!updated) {
          state = AsyncData(List<TimeEntry>.from(current));
        }
      });
    } else if (!hasActive) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _triggerCompletionEffects(TimeEntry entry) async {
    try {
      await ref.read(soundServiceProvider).sessionComplete();
    } catch (e) {
      print('[COMPLETION EFFECTS] sound error: $e');
    }

    try {
      await ref.read(hapticServiceProvider).sessionComplete();
    } catch (e) {
      print('[COMPLETION EFFECTS] vibration error: $e');
    }

    try {
      final notifier = ref.read(notificationServiceProvider);
      final sessionName =
          entry.taskName.isEmpty ? 'Timer Session' : entry.taskName;

      await notifier.showAutoStopNotification(sessionName: sessionName);

      await notifier.showSessionComplete(
        sessionName: sessionName,
        duration: entry.duration,
      );

      if (entry.category.isDeepWork ||
          entry.sessionMode == SessionMode.pomodoro) {
        await notifier.showBreakReminder();
      }
    } catch (e) {
      print('[COMPLETION EFFECTS] notification error: $e');
    }
  }

  @override
  Future<List<TimeEntry>> build() async {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    final authState = ref.watch(authProvider);
    print(
        '[PROVIDER] build — hasValue=${authState.hasValue} auth=${authState.value?.id}');
    if (!authState.hasValue || authState.value == null) {
      print('[PROVIDER] build — no auth, returning []');
      return <TimeEntry>[];
    }

    try {
      final entries = await _repository.fetchTimeEntries();
      print('[PROVIDER] build — got ${entries.length} entries');
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      return entries;
    } catch (e, st) {
      print('[PROVIDER ERROR] build threw: ${e.runtimeType}');
      print(e);
      print(st);
      rethrow;
    }
  }

  Future<void> refreshEntries() async {
    final authState = ref.read(authProvider);
    if (!authState.hasValue || authState.value == null) {
      state = const AsyncData(<TimeEntry>[]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      return entries;
    });
  }

  Future<void> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
    List<String>? tags,
    EnergyLevel energyLevel = EnergyLevel.medium,
    int? breakDurationMinutes,
    bool ignoreActiveCheck = false,
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    if (!ignoreActiveCheck) {
      final hasActiveSession = previousEntries.any((entry) => entry.isOngoing);
      if (hasActiveSession) {
        throw const ValidationException(AppStrings.activeSessionExists);
      }
    }

    state = const AsyncLoading();
    try {
      await _repository.startSession(
        taskName: taskName,
        category: category,
        projectTaskId: projectTaskId,
        sessionMode: sessionMode,
        targetDurationMinutes: targetDurationMinutes,
        tags: tags,
        energyLevel: energyLevel,
        breakDurationMinutes: breakDurationMinutes,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] startSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<TimeEntry?> stopSession({
    required String sessionId,
    SessionStatus? status,
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    final entry =
        previousEntries.where((e) => e.id == sessionId).firstOrNull;

    final resolvedStatus = status ??
        ((entry != null &&
                (entry.sessionMode == SessionMode.timer ||
                    entry.sessionMode == SessionMode.pomodoro ||
                    entry.sessionMode == SessionMode.custom) &&
                entry.remainingTime > Duration.zero)
            ? SessionStatus.cancelled
            : SessionStatus.completed);

    TimeEntry? finished;
    state = const AsyncLoading();
    try {
      finished = await _repository.stopSession(
        sessionId: sessionId,
        status: resolvedStatus,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] stopSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
    return finished;
  }

  Future<void> pauseSession({required String sessionId}) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.pauseSession(sessionId: sessionId);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] pauseSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> deleteSession({required String sessionId}) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.deleteSession(sessionId: sessionId);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] deleteSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> updateSession({
    required String sessionId,
    required String taskName,
    required TaskCategory category,
    String? notes,
    List<String>? tags,
    EnergyLevel? energyLevel,
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.updateSession(
        sessionId: sessionId,
        taskName: taskName,
        category: category,
        notes: notes,
        tags: tags,
        energyLevel: energyLevel,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] updateSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> incrementInterruption({required String sessionId}) async {
    try {
      await _repository.incrementInterruption(sessionId: sessionId);
      final entries = state.value ?? <TimeEntry>[];
      state = AsyncData(List<TimeEntry>.from(entries));
    } catch (e) {
      print('[PROVIDER ERROR] incrementInterruption threw: ${e.runtimeType}');
    }
  }

  Future<void> resumeSession({required String sessionId}) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.resumeSession(sessionId: sessionId);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] resumeSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> mergeSessions({
    required String firstSessionId,
    required String secondSessionId,
    required String mergedTaskName,
    required TaskCategory mergedCategory,
    required DateTime mergedStartTime,
    required DateTime? mergedEndTime,
    required int mergedElapsedSeconds,
    required int mergedPausedSeconds,
    required double mergedCompletionPercentage,
    String? mergedNotes,
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.mergeSessions(
        firstSessionId: firstSessionId,
        secondSessionId: secondSessionId,
        mergedTaskName: mergedTaskName,
        mergedCategory: mergedCategory,
        mergedStartTime: mergedStartTime,
        mergedEndTime: mergedEndTime,
        mergedElapsedSeconds: mergedElapsedSeconds,
        mergedPausedSeconds: mergedPausedSeconds,
        mergedCompletionPercentage: mergedCompletionPercentage,
        mergedNotes: mergedNotes,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      _updateNotificationForState(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] mergeSessions threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  void _updateNotificationForState(List<TimeEntry> entries) {
    final ongoing = entries.where((e) => e.isOngoing).firstOrNull;
    if (ongoing == null) {
      ref.read(notificationServiceProvider).cancelActiveSessionNotification();
      return;
    }

    final isTimer = ongoing.sessionMode == SessionMode.timer ||
        ongoing.sessionMode == SessionMode.pomodoro ||
        ongoing.sessionMode == SessionMode.custom;
    ref.read(notificationServiceProvider).showActiveSessionNotification(
          taskName: ongoing.taskName,
          status: ongoing.status,
          duration: ongoing.duration,
          remaining: isTimer ? ongoing.remainingTime : null,
        );
  }
}

// ── Session Filters & Query States ───────────────────────────────────────────

enum DateRangePreset {
  all,
  today,
  week,
  month,
  custom;

  String get label => switch (this) {
    DateRangePreset.all => 'All Time',
    DateRangePreset.today => 'Today',
    DateRangePreset.week => 'This Week',
    DateRangePreset.month => 'This Month',
    DateRangePreset.custom => 'Custom Range',
  };
}

class SessionFilters {
  const SessionFilters({
    this.dateRangePreset = DateRangePreset.all,
    this.customDateRange,
    this.category,
    this.sessionMode,
    this.status,
  });

  final DateRangePreset dateRangePreset;
  final DateTimeRange? customDateRange;
  final TaskCategory? category;
  final SessionMode? sessionMode;
  final SessionStatus? status;

  SessionFilters copyWith({
    DateRangePreset? dateRangePreset,
    DateTimeRange? customDateRange,
    TaskCategory? category,
    SessionMode? sessionMode,
    SessionStatus? status,
    bool clearCustomDateRange = false,
    bool clearCategory = false,
    bool clearSessionMode = false,
    bool clearStatus = false,
  }) {
    return SessionFilters(
      dateRangePreset: dateRangePreset ?? this.dateRangePreset,
      customDateRange:
          clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      category: clearCategory ? null : (category ?? this.category),
      sessionMode:
          clearSessionMode ? null : (sessionMode ?? this.sessionMode),
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

final sessionSearchQueryProvider = StateProvider<String>((ref) => "");

final sessionFiltersProvider =
    StateProvider<SessionFilters>((ref) => const SessionFilters());

final filteredEntriesProvider = Provider<List<TimeEntry>>((ref) {
  final entriesAsync = ref.watch(timeEntriesProvider);
  final entries = entriesAsync.value ?? <TimeEntry>[];
  final search = ref.watch(sessionSearchQueryProvider).trim().toLowerCase();
  final filters = ref.watch(sessionFiltersProvider);

  return entries.where((entry) {
    if (search.isNotEmpty) {
      final taskMatches = entry.taskName.toLowerCase().contains(search);
      final notesMatches = (entry.notes ?? '').toLowerCase().contains(search);
      final categoryMatches =
          entry.category.label.toLowerCase().contains(search);
      final statusMatches = entry.status.label.toLowerCase().contains(search);
      final modeMatches = entry.sessionMode.label.toLowerCase().contains(search);
      final tagMatches =
          entry.tags.any((t) => t.toLowerCase().contains(search));
      if (!taskMatches &&
          !notesMatches &&
          !categoryMatches &&
          !statusMatches &&
          !modeMatches &&
          !tagMatches) {
        return false;
      }
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (filters.dateRangePreset == DateRangePreset.today) {
      if (entry.startedAt.isBefore(todayStart)) return false;
    } else if (filters.dateRangePreset == DateRangePreset.week) {
      final weekday = now.weekday;
      final weekStart = todayStart.subtract(Duration(days: weekday - 1));
      if (entry.startedAt.isBefore(weekStart)) return false;
    } else if (filters.dateRangePreset == DateRangePreset.month) {
      final monthStart = DateTime(now.year, now.month, 1);
      if (entry.startedAt.isBefore(monthStart)) return false;
    } else if (filters.dateRangePreset == DateRangePreset.custom &&
        filters.customDateRange != null) {
      final start = filters.customDateRange!.start;
      final end = filters.customDateRange!.end.add(const Duration(days: 1));
      if (entry.startedAt.isBefore(start) || entry.startedAt.isAfter(end)) {
        return false;
      }
    }

    if (filters.category != null && entry.category != filters.category) {
      return false;
    }
    if (filters.sessionMode != null &&
        entry.sessionMode != filters.sessionMode) {
      return false;
    }
    if (filters.status != null && entry.status != filters.status) return false;

    return true;
  }).toList();
});

// ── Timeline grouping ────────────────────────────────────────────────────────

enum TimelineGroup {
  today,
  yesterday,
  earlierThisWeek,
  earlierThisMonth,
  older;

  String get label => switch (this) {
    TimelineGroup.today => 'Today',
    TimelineGroup.yesterday => 'Yesterday',
    TimelineGroup.earlierThisWeek => 'Earlier this Week',
    TimelineGroup.earlierThisMonth => 'Earlier this Month',
    TimelineGroup.older => 'Older Sessions',
  };
}

final timelineEntriesProvider =
    Provider<Map<TimelineGroup, List<TimeEntry>>>((ref) {
  final entries = ref.watch(filteredEntriesProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final weekday = now.weekday;
  final startOfWeek = todayStart.subtract(Duration(days: weekday - 1));
  final startOfMonth = DateTime(now.year, now.month, 1);

  final Map<TimelineGroup, List<TimeEntry>> grouped = {
    TimelineGroup.today: [],
    TimelineGroup.yesterday: [],
    TimelineGroup.earlierThisWeek: [],
    TimelineGroup.earlierThisMonth: [],
    TimelineGroup.older: [],
  };

  for (final entry in entries) {
    final date = entry.startedAt.toLocal();
    final entryDay = DateTime(date.year, date.month, date.day);

    if (entryDay.isAtSameMomentAs(todayStart)) {
      grouped[TimelineGroup.today]!.add(entry);
    } else if (entryDay.isAtSameMomentAs(yesterdayStart)) {
      grouped[TimelineGroup.yesterday]!.add(entry);
    } else if (entryDay.isAfter(startOfWeek) ||
        entryDay.isAtSameMomentAs(startOfWeek)) {
      grouped[TimelineGroup.earlierThisWeek]!.add(entry);
    } else if (entryDay.isAfter(startOfMonth) ||
        entryDay.isAtSameMomentAs(startOfMonth)) {
      grouped[TimelineGroup.earlierThisMonth]!.add(entry);
    } else {
      grouped[TimelineGroup.older]!.add(entry);
    }
  }

  grouped.removeWhere((key, value) => value.isEmpty);
  return grouped;
});

// ── Derived Statistics ────────────────────────────────────────────────────────

class DerivedStats {
  const DerivedStats({
    required this.deepWorkHours,
    required this.sessionsCompleted,
    required this.averageSessionLengthMinutes,
    required this.focusScore,
    required this.mostUsedCategory,
    required this.weeklyStreak,
    required this.todayFocusMinutes,
    required this.totalInterruptions,
  });

  final double deepWorkHours;
  final int sessionsCompleted;
  final double averageSessionLengthMinutes;
  final int focusScore;
  final TaskCategory? mostUsedCategory;
  final int weeklyStreak;
  final int todayFocusMinutes;
  final int totalInterruptions;
}

final timeTrackingStatsProvider = Provider<DerivedStats>((ref) {
  final entriesAsync = ref.watch(timeEntriesProvider);
  final entries = entriesAsync.value ?? <TimeEntry>[];

  final completed =
      entries.where((e) => e.status == SessionStatus.completed).toList();
  final completedCount = completed.length;

  final deepWorkSeconds = completed
      .where((e) => e.isProductive)
      .fold<int>(0, (sum, e) => sum + e.elapsedSeconds);
  final deepWorkHrs = deepWorkSeconds / 3600.0;

  final totalElapsedSeconds =
      completed.fold<int>(0, (sum, e) => sum + e.elapsedSeconds);
  final avgLength =
      completedCount > 0 ? (totalElapsedSeconds / completedCount) / 60.0 : 0.0;

  // Most Used Category
  TaskCategory? mostUsedCat;
  if (completed.isNotEmpty) {
    final Map<TaskCategory, int> counts = {};
    for (final e in completed) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    var maxCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostUsedCat = entry.key;
      }
    }
  }

  // Weekly streak
  int streak = 0;
  if (completed.isNotEmpty) {
    final uniqueDays = completed.map((e) {
      final local = e.startedAt.toLocal();
      return DateTime(local.year, local.month, local.day);
    }).toSet();

    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    if (!uniqueDays.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (uniqueDays.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  // Focus Score
  double compScore = 100.0;
  final timed = entries
      .where((e) =>
          e.status == SessionStatus.completed ||
          e.status == SessionStatus.cancelled)
      .toList();
  if (timed.isNotEmpty) {
    final totalComp =
        timed.fold<double>(0.0, (sum, e) => sum + e.completionPercentage);
    compScore = totalComp / timed.length;
  }

  final now = DateTime.now();
  final todayLocal = DateTime(now.year, now.month, now.day);
  final last7Days =
      List.generate(7, (i) => todayLocal.subtract(Duration(days: i))).toSet();
  final activeDaysInLast7 = completed
      .map((e) {
        final local = e.startedAt.toLocal();
        return DateTime(local.year, local.month, local.day);
      })
      .toSet()
      .intersection(last7Days)
      .length;
  final consistencyScore = (activeDaysInLast7 / 7.0) * 100.0;

  double deepWorkRatioScore = 0.0;
  if (completed.isNotEmpty && totalElapsedSeconds > 0) {
    deepWorkRatioScore = (deepWorkSeconds / totalElapsedSeconds) * 100.0;
  }

  final double rawFocusScore =
      (compScore * 0.4) + (consistencyScore * 0.35) + (deepWorkRatioScore * 0.25);
  final focusScoreInt =
      completed.isEmpty ? 0 : rawFocusScore.round().clamp(0, 100);

  // Today focus minutes
  final todayEntries = completed.where((e) {
    final local = e.startedAt.toLocal();
    return DateTime(local.year, local.month, local.day)
        .isAtSameMomentAs(todayLocal);
  });
  final todayFocusMins =
      todayEntries.fold<int>(0, (sum, e) => sum + (e.elapsedSeconds ~/ 60));

  // Total interruptions today
  final totalInterruptions =
      todayEntries.fold<int>(0, (sum, e) => sum + e.interruptions);

  return DerivedStats(
    deepWorkHours: deepWorkHrs,
    sessionsCompleted: completedCount,
    averageSessionLengthMinutes: avgLength,
    focusScore: focusScoreInt,
    mostUsedCategory: mostUsedCat,
    weeklyStreak: streak,
    todayFocusMinutes: todayFocusMins,
    totalInterruptions: totalInterruptions,
  );
});

// ── Daily Focus Goal ──────────────────────────────────────────────────────────

class DailyFocusGoal {
  const DailyFocusGoal({this.targetMinutes = 120});
  final int targetMinutes;
}

final dailyFocusGoalProvider =
    AsyncNotifierProvider<DailyFocusGoalNotifier, DailyFocusGoal>(
  DailyFocusGoalNotifier.new,
);

class DailyFocusGoalNotifier extends AsyncNotifier<DailyFocusGoal> {
  static const _key = 'daily_focus_goal_minutes';

  @override
  Future<DailyFocusGoal> build() async {
    final prefs = await SharedPreferences.getInstance();
    final mins = prefs.getInt(_key) ?? 120;
    return DailyFocusGoal(targetMinutes: mins);
  }

  Future<void> setGoal(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, minutes);
    state = AsyncData(DailyFocusGoal(targetMinutes: minutes));
  }
}

/// How far today's focus is toward the daily goal (0.0 – 1.0+)
final dailyFocusProgressProvider = Provider<double>((ref) {
  final stats = ref.watch(timeTrackingStatsProvider);
  final goalAsync = ref.watch(dailyFocusGoalProvider);
  final goal = goalAsync.valueOrNull ?? const DailyFocusGoal();
  if (goal.targetMinutes <= 0) return 0.0;
  return (stats.todayFocusMinutes / goal.targetMinutes).clamp(0.0, 1.2);
});

// ── Category Breakdown ────────────────────────────────────────────────────────

enum BreakdownTimeframe { weekly, monthly }

final breakdownTimeframeProvider =
    StateProvider<BreakdownTimeframe>((ref) => BreakdownTimeframe.weekly);

final categoryBreakdownProvider = Provider<Map<TaskCategory, double>>((ref) {
  final entriesAsync = ref.watch(timeEntriesProvider);
  final entries = entriesAsync.value ?? <TimeEntry>[];
  final timeframe = ref.watch(breakdownTimeframeProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final DateTime limit;

  if (timeframe == BreakdownTimeframe.weekly) {
    limit = todayStart.subtract(const Duration(days: 7));
  } else {
    limit = todayStart.subtract(const Duration(days: 30));
  }

  final completedInTimeframe = entries
      .where((e) =>
          e.status == SessionStatus.completed &&
          e.startedAt.isAfter(limit))
      .toList();

  final Map<TaskCategory, double> breakdown = {};
  double total = 0;

  for (final e in completedInTimeframe) {
    final secs = e.elapsedSeconds.toDouble();
    breakdown[e.category] = (breakdown[e.category] ?? 0.0) + secs;
    total += secs;
  }

  if (total > 0) {
    for (final key in breakdown.keys) {
      breakdown[key] = (breakdown[key]! / total) * 100.0;
    }
  }

  return breakdown;
});

// ── GitHub-style Heatmap ──────────────────────────────────────────────────────

final heatmapDataProvider = Provider<Map<DateTime, int>>((ref) {
  final entriesAsync = ref.watch(timeEntriesProvider);
  final entries = entriesAsync.value ?? <TimeEntry>[];

  final Map<DateTime, int> map = {};
  for (final entry in entries) {
    if (entry.status == SessionStatus.completed) {
      final dateLocal = entry.startedAt.toLocal();
      final day = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
      map[day] = (map[day] ?? 0) + (entry.elapsedSeconds ~/ 60);
    }
  }
  return map;
});
