import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_supabase_datasource.dart';
import 'package:chronyx/features/time_tracking/data/repositories/time_tracking_repository_impl.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timeTrackingRemoteDataSourceProvider =
    Provider<TimeTrackingRemoteDataSource>((ref) {
  return TimeTrackingSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final timeTrackingRepositoryProvider = Provider<TimeTrackingRepository>((ref) {
  return TimeTrackingRepositoryImpl(ref.watch(timeTrackingRemoteDataSourceProvider));
});

final timeEntriesProvider =
    AsyncNotifierProvider<TimeEntriesNotifier, List<TimeEntry>>(
  TimeEntriesNotifier.new,
);

class TimeEntriesNotifier extends AsyncNotifier<List<TimeEntry>> {
  TimeTrackingRepository get _repository =>
      ref.read(timeTrackingRepositoryProvider);

  @override
  Future<List<TimeEntry>> build() async {
    return _repository.fetchTimeEntries();
  }

  Future<void> refreshEntries() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchTimeEntries);
  }

  Future<void> startSession({required String taskName}) async {
    final currentEntries = state.value ?? <TimeEntry>[];
    final hasActiveSession = currentEntries.any((entry) => entry.isActive);
    if (hasActiveSession) {
      throw const ValidationException(AppStrings.activeSessionExists);
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.startSession(taskName: taskName);
      return _repository.fetchTimeEntries();
    });
  }

  Future<void> stopSession({required String sessionId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.stopSession(sessionId: sessionId);
      return _repository.fetchTimeEntries();
    });
  }
}
