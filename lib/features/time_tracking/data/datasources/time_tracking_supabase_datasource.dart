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
    print('[TIME] current user=$userId');

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
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
    List<String>? tags,
    EnergyLevel energyLevel = EnergyLevel.medium,
    int? breakDurationMinutes,
  }) async {
    final String userId = _currentUserId;

    final name = taskName.trim();
    if (name.isEmpty) {
      throw const ValidationException('Task name cannot be empty.');
    }

    // Prevent duplicate active sessions.
    final List<dynamic> active = await _supabaseClient
        .from(_tableName)
        .select('id')
        .eq('user_id', userId)
        .inFilter('status', ['active', 'paused']);

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
      'status': SessionStatus.active.jsonKey,
      'session_mode': sessionMode.jsonKey,
      if (targetDurationMinutes != null)
        'target_duration_minutes': targetDurationMinutes,
      'elapsed_seconds': 0,
      'duration_minutes': 0,
      'completion_percentage': 0.0,
      'paused_duration_seconds': 0,
      'interruptions': 0,
      'energy_level': energyLevel.jsonKey,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      if (breakDurationMinutes != null)
        'break_duration_minutes': breakDurationMinutes,
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
      if (e.code == '42703' ||
          e.message.contains('session_mode') ||
          e.message.contains('status')) {
        final fallback = <String, dynamic>{
          'user_id': userId,
          'task_name': name,
          'start_time': now.toIso8601String(),
          'category': category.jsonKey,
          'mode': sessionMode.jsonKey,
          if (projectTaskId != null) 'project_task_id': projectTaskId,
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
  Future<TimeEntryModel> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  }) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();

    final List<dynamic> existing = await _supabaseClient
        .from(_tableName)
        .select(
            'start_time, session_mode, target_duration_minutes, paused_duration_seconds, paused_at')
        .eq('user_id', userId)
        .eq('id', sessionId);

    int elapsedSeconds = 0;
    int durationMinutes = 0;
    double completionPercentage = 0.0;

    if (existing.isNotEmpty) {
      final row = existing.first as Map<String, dynamic>;
      final startRaw = row['start_time'];
      final sessionModeStr = row['session_mode'] as String? ?? 'stopwatch';
      final isTimer = sessionModeStr == 'timer' ||
          sessionModeStr == 'pomodoro' ||
          sessionModeStr == 'custom';
      final targetMins = (row['target_duration_minutes'] as num?)?.toInt();
      final pausedSecs =
          (row['paused_duration_seconds'] as num?)?.toInt() ?? 0;
      final pausedAtRaw = row['paused_at'] as String?;

      if (startRaw != null) {
        final start = _parseDateTimeUtc(startRaw as String);
        final DateTime endPoint =
            pausedAtRaw != null ? _parseDateTimeUtc(pausedAtRaw) : now;

        final totalSeconds = endPoint.difference(start).inSeconds;
        final computed = totalSeconds - pausedSecs;
        elapsedSeconds = computed >= 0 ? computed : 0;
        durationMinutes = elapsedSeconds ~/ 60;

        if (isTimer && targetMins != null && targetMins > 0) {
          final rawPct = (elapsedSeconds / (targetMins * 60)) * 100.0;
          completionPercentage =
              ((rawPct * 10.0).roundToDouble() / 10.0).clamp(0.0, 100.0);
        } else {
          completionPercentage = 100.0;
        }
      }
    }

    final update = <String, dynamic>{
      'end_time': now.toIso8601String(),
      'elapsed_seconds': elapsedSeconds,
      'duration_minutes': durationMinutes,
      'completion_percentage': completionPercentage,
      'status': status.jsonKey,
      'paused_at': null,
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(update)
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();

    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<TimeEntryModel> pauseSession({required String sessionId}) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();
    final update = <String, dynamic>{
      'paused_at': now.toIso8601String(),
      'status': SessionStatus.paused.jsonKey,
    };
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(update)
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();
    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<TimeEntryModel> resumeSession({required String sessionId}) async {
    final String userId = _currentUserId;
    final DateTime now = DateTime.now().toUtc();

    final List<dynamic> existing = await _supabaseClient
        .from(_tableName)
        .select('paused_at, paused_duration_seconds')
        .eq('user_id', userId)
        .eq('id', sessionId);

    int addedPausedSeconds = 0;
    int currentPausedSeconds = 0;
    if (existing.isNotEmpty) {
      final row = existing.first as Map<String, dynamic>;
      currentPausedSeconds =
          (row['paused_duration_seconds'] as num?)?.toInt() ?? 0;
      final pausedAtRaw = row['paused_at'] as String?;
      if (pausedAtRaw != null) {
        final pausedAt = _parseDateTimeUtc(pausedAtRaw);
        addedPausedSeconds = now.difference(pausedAt).inSeconds;
        if (addedPausedSeconds < 0) addedPausedSeconds = 0;
      }
    }

    final update = <String, dynamic>{
      'paused_at': null,
      'paused_duration_seconds': currentPausedSeconds + addedPausedSeconds,
      'status': SessionStatus.active.jsonKey,
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(update)
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();
    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    final String userId = _currentUserId;
    await _supabaseClient
        .from(_tableName)
        .delete()
        .eq('user_id', userId)
        .eq('id', sessionId);
  }

  @override
  Future<TimeEntryModel> updateSession({
    required String sessionId,
    required String taskName,
    required TaskCategory category,
    String? notes,
    List<String>? tags,
    EnergyLevel? energyLevel,
    int? interruptions,
  }) async {
    final String userId = _currentUserId;
    final name = taskName.trim();
    if (name.isEmpty) {
      throw const ValidationException('Task name cannot be empty.');
    }

    final update = <String, dynamic>{
      'task_name': name,
      'category': category.jsonKey,
      'notes': notes,
      if (tags != null) 'tags': tags,
      if (energyLevel != null) 'energy_level': energyLevel.jsonKey,
      if (interruptions != null) 'interruptions': interruptions,
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(update)
        .eq('user_id', userId)
        .eq('id', sessionId)
        .select();
    return TimeEntryModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> incrementInterruption({required String sessionId}) async {
    final String userId = _currentUserId;
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .select('interruptions')
        .eq('user_id', userId)
        .eq('id', sessionId);
    if (rows.isEmpty) return;
    final current = (rows.first['interruptions'] as num?)?.toInt() ?? 0;
    await _supabaseClient
        .from(_tableName)
        .update({'interruptions': current + 1})
        .eq('user_id', userId)
        .eq('id', sessionId);
  }

  @override
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
  }) async {
    final String userId = _currentUserId;

    await _supabaseClient.from(_tableName).update({
      'task_name': mergedTaskName,
      'category': mergedCategory.jsonKey,
      'start_time': mergedStartTime.toIso8601String(),
      'end_time': mergedEndTime?.toIso8601String(),
      'elapsed_seconds': mergedElapsedSeconds,
      'duration_minutes': mergedElapsedSeconds ~/ 60,
      'paused_duration_seconds': mergedPausedSeconds,
      'completion_percentage': mergedCompletionPercentage,
      'notes': mergedNotes,
    }).eq('user_id', userId).eq('id', firstSessionId);

    await _supabaseClient
        .from(_tableName)
        .delete()
        .eq('user_id', userId)
        .eq('id', secondSessionId);
  }

  DateTime _parseDateTimeUtc(String dateStr) {
    final hasTimezone = dateStr.endsWith('Z') ||
        (dateStr.length > 10 &&
            (dateStr.contains('+', 10) || dateStr.contains('-', 10)));
    return DateTime.parse(hasTimezone ? dateStr : '${dateStr}Z').toUtc();
  }
}
