import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class TimeTrackingRepository {
  Future<List<TimeEntry>> fetchTimeEntries();

  Future<TimeEntry> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
    List<String>? tags,
    EnergyLevel energyLevel = EnergyLevel.medium,
    int? breakDurationMinutes,
  });

  Future<TimeEntry> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  });

  Future<TimeEntry> pauseSession({required String sessionId});

  Future<TimeEntry> resumeSession({required String sessionId});

  Future<void> deleteSession({required String sessionId});

  Future<TimeEntry> updateSession({
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
