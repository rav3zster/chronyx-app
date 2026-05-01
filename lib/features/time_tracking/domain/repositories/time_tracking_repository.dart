import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class TimeTrackingRepository {
  Future<List<TimeEntry>> fetchTimeEntries();
  Future<TimeEntry> startSession({required String taskName});
  Future<TimeEntry> stopSession({required String sessionId});
}
