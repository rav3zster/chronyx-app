import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class TimeTrackingRepository {
  Future<List<TimeEntry>> fetchTimeEntries();
  Future<TimeEntry> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode mode = SessionMode.stopwatch,
    int? targetDurationMinutes,
  });
  Future<TimeEntry> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  });
  Future<void> deleteSession({required String sessionId});
  Future<TimeEntry> updateSession({
    required String sessionId,
    required String taskName,
    required TaskCategory category,
  });
  Future<TimeEntry> resumeSession({required String sessionId});
}
