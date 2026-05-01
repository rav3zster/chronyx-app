import 'package:chronyx/features/time_tracking/data/models/time_entry_model.dart';

abstract class TimeTrackingRemoteDataSource {
  Future<List<TimeEntryModel>> fetchEntries();
  Future<TimeEntryModel> startSession({required String taskName});
  Future<TimeEntryModel> stopSession({required String sessionId});
}
