import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeTrackingRepositoryImpl implements TimeTrackingRepository {
  TimeTrackingRepositoryImpl(this._remoteDataSource);

  final TimeTrackingRemoteDataSource _remoteDataSource;

  @override
  Future<List<TimeEntry>> fetchTimeEntries() async {
    print('[REPO] fetchTimeEntries');
    try {
      final models = await _remoteDataSource.fetchEntries();
      print('[REPO] fetchEntries ok, count=${models.length}');
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in fetchTimeEntries');
      print('  code=${e.code}');
      print('  message=${e.message}');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in fetchTimeEntries: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> startSession({
    required String taskName,
    required TaskCategory category,
    String? projectTaskId,
    SessionMode sessionMode = SessionMode.stopwatch,
    int? targetDurationMinutes,
    List<String>? tags,
    EnergyLevel energyLevel = EnergyLevel.medium,
    int? breakDurationMinutes,
  }) async {
    try {
      final model = await _remoteDataSource.startSession(
        taskName: taskName,
        category: category,
        projectTaskId: projectTaskId,
        sessionMode: sessionMode,
        targetDurationMinutes: targetDurationMinutes,
        tags: tags,
        energyLevel: energyLevel,
        breakDurationMinutes: breakDurationMinutes,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in startSession');
      print('  code=${e.code}');
      print('  message=${e.message}');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in startSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> stopSession({
    required String sessionId,
    SessionStatus status = SessionStatus.completed,
  }) async {
    try {
      final model = await _remoteDataSource.stopSession(
        sessionId: sessionId,
        status: status,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in stopSession');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in stopSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> pauseSession({required String sessionId}) async {
    try {
      final model = await _remoteDataSource.pauseSession(sessionId: sessionId);
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in pauseSession');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in pauseSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> resumeSession({required String sessionId}) async {
    try {
      final model =
          await _remoteDataSource.resumeSession(sessionId: sessionId);
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in resumeSession');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in resumeSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    try {
      await _remoteDataSource.deleteSession(sessionId: sessionId);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in deleteSession');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in deleteSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> updateSession({
    required String sessionId,
    required String taskName,
    required TaskCategory category,
    String? notes,
    List<String>? tags,
    EnergyLevel? energyLevel,
    int? interruptions,
  }) async {
    try {
      final model = await _remoteDataSource.updateSession(
        sessionId: sessionId,
        taskName: taskName,
        category: category,
        notes: notes,
        tags: tags,
        energyLevel: energyLevel,
        interruptions: interruptions,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in updateSession');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in updateSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<void> incrementInterruption({required String sessionId}) async {
    try {
      await _remoteDataSource.incrementInterruption(sessionId: sessionId);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in incrementInterruption');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print(
          '[REPO ERROR] non-Postgrest in incrementInterruption: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
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
    try {
      await _remoteDataSource.mergeSessions(
        firstSessionId: firstSessionId,
        secondSessionId: secondSessionId,
        mergedTaskName: mergedTaskName,
        mergedCategory: mergedCategory,
        mergedStartTime: mergedStartTime,
        mergedEndTime: mergedEndTime,
        mergedElapsedSeconds: mergedElapsedSeconds,
        mergedPausedSeconds: mergedPausedSeconds,
        mergedCompletionPercentage: mergedCompletionPercentage,
        mergedNotes: mergedNotes,
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in mergeSessions');
      print(st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in mergeSessions: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AppException _mapPostgrest(PostgrestException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    if (code == '42703' ||
        (msg.contains('does not exist') && msg.contains('column'))) {
      return ServerException(
        'Database schema is out of date. Run the latest migration.',
      );
    }
    if (code == '42P01' ||
        (msg.contains('relation') && msg.contains('does not exist'))) {
      return const ServerException(
        'A required table is missing. Run the project migrations.',
      );
    }
    if (code == '42501' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security')) {
      return const ServerException('Access denied by database policy.');
    }
    if (msg.contains('jwt') || msg.contains('not authenticated')) {
      return const ServerException('Session expired. Please sign in again.');
    }
    if (code == '23502') {
      return ServerException('Missing required field: ${e.message}');
    }
    if (code == '23503') {
      return ServerException(
        'Database FK violation: ${e.message}.',
      );
    }
    return ServerException(e.message);
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup');
  }
}
