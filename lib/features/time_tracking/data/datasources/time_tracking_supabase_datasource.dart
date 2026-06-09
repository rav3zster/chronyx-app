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
    // ── 1. Auth ──────────────────────────────────────────────────────────────
    print('[TIME] query start');
    final String userId;
    try {
      userId = _currentUserId;
    } catch (error, st) {
      print('[TIME ERROR] _currentUserId threw');
      print(error);
      print(st);
      rethrow;
    }
    print('[TIME] current user=${userId}');

    // ── 2. Query ─────────────────────────────────────────────────────────────
    final List<dynamic> rows;
    try {
      rows = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(200);
    } catch (error, st) {
      print('[TIME ERROR] Supabase query threw');
      print(error);
      print(st);
      rethrow;
    }
    print('[TIME] raw response=${rows}');

    // ── 3. Mapping ───────────────────────────────────────────────────────────
    print('[TIME] mapping entries, count=${rows.length}');
    final List<TimeEntryModel> entries = [];
    for (int i = 0; i < rows.length; i++) {
      try {
        entries.add(TimeEntryModel.fromJson(rows[i] as Map<String, dynamic>));
      } catch (error, st) {
        print('[TIME ERROR] fromJson crashed on row $i: ${rows[i]}');
        print(error);
        print(st);
        rethrow;
      }
    }
    print('[TIME] mapped entries count=${entries.length}');
    return entries;
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
