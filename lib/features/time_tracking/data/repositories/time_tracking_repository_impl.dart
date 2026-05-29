import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/time_tracking/data/datasources/time_tracking_remote_datasource.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeTrackingRepositoryImpl implements TimeTrackingRepository {
  TimeTrackingRepositoryImpl(this._remoteDataSource);

  final TimeTrackingRemoteDataSource _remoteDataSource;

  @override
  Future<List<TimeEntry>> fetchTimeEntries() async {
    try {
      final models = await _remoteDataSource.fetchEntries();
      return models.map((model) => model.toEntity()).toList();
    } on PostgrestException catch (e, st) {
      _logPostgres('fetchTimeEntries', e, st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      _logUnknown('fetchTimeEntries', e, st);
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Future<TimeEntry> startSession({
    required String taskName,
    required TaskCategory category,
  }) async {
    try {
      final model = await _remoteDataSource.startSession(
        taskName: taskName,
        category: category,
      );
      return model.toEntity();
    } on PostgrestException catch (e, st) {
      _logPostgres('startSession', e, st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      _logUnknown('startSession', e, st);
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Future<TimeEntry> stopSession({required String sessionId}) async {
    try {
      final model = await _remoteDataSource.stopSession(sessionId: sessionId);
      return model.toEntity();
    } on PostgrestException catch (e, st) {
      _logPostgres('stopSession', e, st);
      throw _mapPostgrest(e);
    } catch (e, st) {
      _logUnknown('stopSession', e, st);
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────

  AppException _mapPostgrest(PostgrestException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    final details = e.details?.toString().toLowerCase() ?? '';

    // Missing column
    if (code == '42703' ||
        msg.contains('does not exist') && msg.contains('column')) {
      final colMatch = RegExp(
        r'column[\s"]+([a-z_]+)',
      ).firstMatch('${e.message} $details');
      final col = colMatch?.group(1) ?? 'a column';
      return ServerException(
        'Database column "$col" missing. Run the latest migration in Supabase SQL editor.',
      );
    }
    // Missing table
    if (code == '42P01' ||
        msg.contains('relation') && msg.contains('does not exist')) {
      return const ServerException(
        'A required table is missing. Run the project migrations in Supabase.',
      );
    }
    // RLS denial
    if (code == '42501' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security')) {
      return const ServerException(
        'Access denied by database policy. Check RLS rules.',
      );
    }
    // Auth issues
    if (msg.contains('jwt') || msg.contains('not authenticated')) {
      return const ServerException('Session expired. Please sign in again.');
    }
    // Not-null violation
    if (code == '23502') {
      return ServerException(
        'Database column has a NOT NULL constraint we don\'t set. ${e.message}',
      );
    }
    // Generic — surface the real Postgres message so user knows what to fix
    return ServerException(e.message);
  }

  void _logPostgres(String op, PostgrestException e, StackTrace st) {
    debugPrint('[time_tracking][$op] PostgrestException');
    debugPrint('  code: ${e.code}');
    debugPrint('  message: ${e.message}');
    debugPrint('  details: ${e.details}');
    debugPrint('  hint: ${e.hint}');
  }

  void _logUnknown(String op, Object e, StackTrace st) {
    debugPrint('[time_tracking][$op] $e');
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup');
  }
}
