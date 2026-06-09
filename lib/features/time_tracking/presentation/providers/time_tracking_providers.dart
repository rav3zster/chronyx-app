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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          if (entry.isActive && entry.sessionMode == SessionMode.timer) {
            final remaining = entry.remainingTime;
            if (remaining <= Duration.zero) {
              try {
                await stopSession(sessionId: entry.id, status: SessionStatus.completed);
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
    // 1. Play session complete sound
    try {
      await ref.read(soundServiceProvider).sessionComplete();
    } catch (e) {
      print('[COMPLETION EFFECTS] sound error: $e');
    }

    // 2. Trigger vibration
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.vibrate();
    } catch (e) {
      print('[COMPLETION EFFECTS] vibration error: $e');
    }

    // 3. Send local notification
    try {
      await ref.read(notificationServiceProvider).showSessionComplete(
        sessionName: entry.taskName.isEmpty ? 'Timer Session' : entry.taskName,
        duration: entry.duration,
      );
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
    print('[PROVIDER] build — hasValue=${authState.hasValue} auth=${authState.value?.id}');
    if (!authState.hasValue || authState.value == null) {
      print('[PROVIDER] build — no auth, returning []');
      return <TimeEntry>[];
    }

    try {
      final entries = await _repository.fetchTimeEntries();
      print('[PROVIDER] build — got ${entries.length} entries');
      _startTickerIfNeeded(entries);
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
    print('[PROVIDER] refreshEntries — hasValue=${authState.hasValue} auth=${authState.value?.id}');
    if (!authState.hasValue || authState.value == null) {
      state = const AsyncData(<TimeEntry>[]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      return entries;
    });
  }

  Future<void> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
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
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] startSession threw: ${e.runtimeType}');
      print(e);
      // Restore previous list so the sessions section stays visible,
      // not stuck in Retry. The page's _startSession() shows a SnackBar.
      state = AsyncData(previousEntries);
      // Re-throw so the page catch block can show the SnackBar.
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<TimeEntry?> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    TimeEntry? finished;
    state = const AsyncLoading();
    try {
      finished = await _repository.stopSession(
        sessionId: sessionId,
        status: status,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
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
  }) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.updateSession(
        sessionId: sessionId,
        taskName: taskName,
        category: category,
      );
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] updateSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> resumeSession({required String sessionId}) async {
    final previousEntries = state.value ?? <TimeEntry>[];
    state = const AsyncLoading();
    try {
      await _repository.resumeSession(sessionId: sessionId);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      state = AsyncData(entries);
    } catch (e, st) {
      print('[PROVIDER ERROR] resumeSession threw: ${e.runtimeType}');
      print(e);
      state = AsyncData(previousEntries);
      Error.throwWithStackTrace(e, st);
    }
  }
}
