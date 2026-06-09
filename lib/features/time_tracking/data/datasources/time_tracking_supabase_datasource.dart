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

    // Data integrity: prevent empty task names.
    final name = taskName.trim();
    if (name.isEmpty) {
      throw const ValidationException('Task name cannot be empty.');
    }

    // Data integrity: prevent duplicate active sessions.
    final List<dynamic> active = await _supabaseClient
        .from(_tableName)
        .select('id')
        .eq('user_id', userId)
        .isFilter('end_time', null);
    if (active.isNotEmpty) {
      throw const ValidationException(
        'A session is already running. Stop it before starting a new one.',
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final base = <String, dynamic>{
      'user_id': userId,
      'task_name': name,
      'start_time': now.toIso8601String(),
      'category': category.jsonKey,
    };
    if (projectTaskId != null) {
      base['project_task_id'] = projectTaskId;
    }

    try {
      final List<dynamic> rows = await _supabaseClient
          .from(_tableName)
          .insert(base)
          .select();
      return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      // Unknown column fallback (migration not yet run).
      if (e.code == '42703' ||
          e.message.contains('category') ||
          e.message.contains('project_task_id')) {
        final fallback = <String, dynamic>{
          'user_id': userId,
          'task_name': name,
          'start_time': now.toIso8601String(),
        };
        final List<dynamic> rows = await _supabaseClient
            .from(_tableName)
            .insert(fallback)
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

    // Fetch the row first so we can compute duration_minutes accurately.
    final List<dynamic> existing = await _supabaseClient
        .from(_tableName)
        .select('start_time')
        .eq('user_id', userId)
        .eq('id', sessionId)
        .isFilter('end_time', null);

    int? durationMinutes;
    if (existing.isNotEmpty) {
      final startRaw = (existing.first as Map<String, dynamic>)['start_time'];
      if (startRaw != null) {
        final start = DateTime.parse(startRaw as String);
        final computed = now.difference(start).inMinutes;
        // Guard: never store a negative duration.
        durationMinutes = computed >= 0 ? computed : 0;
      }
    }

    final update = <String, dynamic>{
      'end_time': now.toIso8601String(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(update)
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();

    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }
}
