import 'dart:async';

import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/core/services/focus_tracker.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_supabase_datasource.dart';
import 'package:chronyx/features/time_tracking/data/repositories/time_tracking_repository_impl.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
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

/// Tracks today's focused vs away seconds since the app was opened.
final focusStatsProvider = NotifierProvider<FocusStatsNotifier, FocusStats>(
  FocusStatsNotifier.new,
);

class FocusStats {
  const FocusStats({
    this.focusedSeconds = 0,
    this.awaySeconds = 0,
  });

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
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final current = state.value ?? <TimeEntry>[];
        state = AsyncData(List<TimeEntry>.from(current));
      });
      ref.onDispose(() {
        _ticker?.cancel();
        _ticker = null;
      });
    } else if (!hasActive) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Future<List<TimeEntry>> build() async {
    final entries = await _repository.fetchTimeEntries();
    _startTickerIfNeeded(entries);
    return entries;
  }

  Future<void> refreshEntries() async {
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
  }) async {
    final currentEntries = state.value ?? <TimeEntry>[];
    final hasActiveSession = currentEntries.any((entry) => entry.isActive);
    if (hasActiveSession) {
      throw const ValidationException(AppStrings.activeSessionExists);
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.startSession(taskName: taskName, category: category);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      return entries;
    });
  }

  Future<void> stopSession({required String sessionId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.stopSession(sessionId: sessionId);
      final entries = await _repository.fetchTimeEntries();
      _startTickerIfNeeded(entries);
      return entries;
    });
  }
}
