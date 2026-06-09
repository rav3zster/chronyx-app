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
    } on PostgrestException catch (e, st) {
      // Expose the FULL Postgrest error — do not hide it.
      print('[REPO ERROR] PostgrestException in fetchTimeEntries');
      print('  code=${e.code}');
      print('  message=${e.message}');
      print('  details=${e.details}');
      print('  hint=${e.hint}');
      print(st);
      throw Exception(
        'POSTGREST ERROR\n'
        'code=${e.code}\n'
        'message=${e.message}\n'
        'details=${e.details}\n'
        'hint=${e.hint}',
      );
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
  }) async {
    try {
      final model = await _remoteDataSource.startSession(
        taskName: taskName,
        category: category,
        projectTaskId: projectTaskId,
      );
      return model.toEntity();
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in startSession');
      print('  code=${e.code}');
      print('  message=${e.message}');
      print('  details=${e.details}');
      print('  hint=${e.hint}');
      print(st);
      throw Exception(
        'POSTGREST ERROR\n'
        'code=${e.code}\n'
        'message=${e.message}\n'
        'details=${e.details}\n'
        'hint=${e.hint}',
      );
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in startSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TimeEntry> stopSession({required String sessionId}) async {
    try {
      final model = await _remoteDataSource.stopSession(sessionId: sessionId);
      return model.toEntity();
    } on PostgrestException catch (e, st) {
      print('[REPO ERROR] PostgrestException in stopSession');
      print('  code=${e.code}');
      print('  message=${e.message}');
      print('  details=${e.details}');
      print('  hint=${e.hint}');
      print(st);
      throw Exception(
        'POSTGREST ERROR\n'
        'code=${e.code}\n'
        'message=${e.message}\n'
        'details=${e.details}\n'
        'hint=${e.hint}',
      );
    } catch (e, st) {
      print('[REPO ERROR] non-Postgrest in stopSession: ${e.runtimeType}');
      print(e);
      print(st);
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup');
  }
}
