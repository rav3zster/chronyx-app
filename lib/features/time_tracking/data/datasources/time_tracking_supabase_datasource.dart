import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/data/models/time_entry_model.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeTrackingSupabaseDataSource implements TimeTrackingRemoteDataSource {
  TimeTrackingSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;
  static const String _tableName = 'time_logs';

  String get _currentUserId => _supabaseClient.auth.currentUser!.id;

  @override
  Future<List<TimeEntryModel>> fetchEntries() async {
    final String userId = _currentUserId;
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: false)
        .limit(200);

    return rows
        .map((dynamic json) =>
            TimeEntryModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TimeEntryModel> startSession({
    required String taskName,
    required TaskCategory category,
  }) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .insert(<String, dynamic>{
          'user_id': userId,
          'task_name': taskName,
          'start_time': now.toIso8601String(),
          'category': category.jsonKey,
        })
        .select();

    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<TimeEntryModel> stopSession({required String sessionId}) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(<String, dynamic>{
          'end_time': now.toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();

    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }
}
