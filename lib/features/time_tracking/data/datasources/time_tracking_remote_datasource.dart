import 'package:chronyx/features/time_tracking/data/models/time_entry_model.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class TimeTrackingRemoteDataSource {
  Future<List<TimeEntryModel>> fetchEntries();
  Future<TimeEntryModel> startSession({
    required String taskName,
    required TaskCategory category,
  });
  Future<TimeEntryModel> stopSession({required String sessionId});
}
