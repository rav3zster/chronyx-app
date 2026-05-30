import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/data/models/time_entry_model.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeTrackingSupabaseDataSource implements TimeTrackingRemoteDataSource {
  TimeTrackingSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;
  static const String _tableName = 'time_logs';

  String get _currentUserId {
    final uid = _supabaseClient.auth.currentUser?.id;
    if (uid == null) throw const UnknownException('Not authenticated');
    return uid;
  }

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
        .map(
          (dynamic json) =>
              TimeEntryModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<TimeEntryModel> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
  }) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();

    final base = <String, dynamic>{
      'user_id': userId,
      'task_name': taskName,
      'start_time': now.toIso8601String(),
    };

    // Try inserting WITH category + project link first. If a column doesn't
    // exist yet (migration not run), fall back to the minimal insert.
    try {
      final fullInsert = <String, dynamic>{
        ...base,
        'category': category.jsonKey,
      };
      if (projectTaskId != null) {
        fullInsert['project_task_id'] = projectTaskId;
      }
      final List<dynamic> rows = await _supabaseClient
          .from(_tableName)
          .insert(fullInsert)
          .select();
      return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      // Unknown column (category or project_task_id) → retry minimal insert.
      if (e.code == '42703' ||
          e.message.contains('category') ||
          e.message.contains('project_task_id')) {
        final List<dynamic> rows = await _supabaseClient
            .from(_tableName)
            .insert(base)
            .select();
        return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  @override
  Future<TimeEntryModel> stopSession({required String sessionId}) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(<String, dynamic>{'end_time': now.toIso8601String()})
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();

    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }
}
