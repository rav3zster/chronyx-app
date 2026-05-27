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
    try {
      final models = await _remoteDataSource.fetchEntries();
      return models.map((model) => model.toEntity()).toList();
    } on PostgrestException {
      throw const ServerException();
    } catch (e) {
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
    } on PostgrestException {
      throw const ServerException();
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Future<TimeEntry> stopSession({required String sessionId}) async {
    try {
      final model = await _remoteDataSource.stopSession(sessionId: sessionId);
      return model.toEntity();
    } on PostgrestException {
      throw const ServerException();
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
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
