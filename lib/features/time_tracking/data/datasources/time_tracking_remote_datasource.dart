import 'package:chronyx/features/time_tracking/data/models/time_entry_model.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class TimeTrackingRemoteDataSource {
  Future<List<TimeEntryModel>> fetchEntries();

  Future<TimeEntryModel> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
    List<String>? tags,
    EnergyLevel energyLevel = EnergyLevel.medium,
    int? breakDurationMinutes,
  });

  Future<TimeEntryModel> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  });

  Future<TimeEntryModel> pauseSession({required String sessionId});

  Future<TimeEntryModel> resumeSession({required String sessionId});

  Future<void> deleteSession({required String sessionId});

  Future<TimeEntryModel> updateSession({
    required String sessionId,
    required String taskName,
    required TaskCategory category,
    String? notes,
    List<String>? tags,
    EnergyLevel? energyLevel,
    int? interruptions,
  });

  Future<void> incrementInterruption({required String sessionId});

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
  });
}
