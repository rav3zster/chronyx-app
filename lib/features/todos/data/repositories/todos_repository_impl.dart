import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/todos/data/datasources/todos_remote_datasource.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/domain/entities/todo_attachment.dart';
import 'package:chronyx/features/todos/domain/repositories/todos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodosRepositoryImpl implements TodosRepository {
  TodosRepositoryImpl(this._remoteDataSource);

  final TodosRemoteDataSource _remoteDataSource;

  @override
  Future<List<Todo>> fetchTodos() async {
    try {
      final models = await _remoteDataSource.fetchTodos();
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<Todo> createTodo({
    required String title,
    String? notes,
    TodoStatus status = TodoStatus.pending,
    TodoPriority priority = TodoPriority.medium,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int estimatedMinutes = 0,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel energyLevel = TodoEnergyLevel.medium,
    List<String> tags = const [],
    List<DateTime> reminderTimes = const [],
    List<String> blockedByIds = const [],
  }) async {
    try {
      final model = await _remoteDataSource.createTodo(
        title: title,
        notes: notes,
        status: status,
        priority: priority,
        category: category,
        dueDate: dueDate,
        reminderTime: reminderTime,
        estimatedMinutes: estimatedMinutes,
        projectId: projectId,
        goalId: goalId,
        habitId: habitId,
        recurrence: recurrence,
        parentId: parentId,
        energyLevel: energyLevel,
        tags: tags,
        reminderTimes: reminderTimes,
        blockedByIds: blockedByIds,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<Todo> updateTodo({
    required String id,
    String? title,
    String? notes,
    TodoStatus? status,
    TodoPriority? priority,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? estimatedMinutes,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel? energyLevel,
    List<String>? tags,
    List<DateTime>? reminderTimes,
    List<String>? blockedByIds,
    bool clearDueDate = false,
    bool clearReminderTime = false,
    bool clearParentId = false,
  }) async {
    try {
      final model = await _remoteDataSource.updateTodo(
        id: id,
        title: title,
        notes: notes,
        status: status,
        priority: priority,
        category: category,
        dueDate: dueDate,
        reminderTime: reminderTime,
        estimatedMinutes: estimatedMinutes,
        projectId: projectId,
        goalId: goalId,
        habitId: habitId,
        recurrence: recurrence,
        parentId: parentId,
        energyLevel: energyLevel,
        tags: tags,
        reminderTimes: reminderTimes,
        blockedByIds: blockedByIds,
        clearDueDate: clearDueDate,
        clearReminderTime: clearReminderTime,
        clearParentId: clearParentId,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<void> deleteTodo({required String id}) async {
    try {
      await _remoteDataSource.deleteTodo(id: id);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  // ── Attachments ────────────────────────────────────────────────────────────

  @override
  Future<List<TodoAttachment>> fetchAttachments({required String todoId}) async {
    try {
      final models = await _remoteDataSource.fetchAttachments(todoId: todoId);
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<TodoAttachment> createAttachment({
    required String todoId,
    required String name,
    required String url,
    required TodoAttachmentType type,
    int? sizeBytes,
  }) async {
    try {
      final model = await _remoteDataSource.createAttachment(
        todoId: todoId,
        name: name,
        url: url,
        type: type,
        sizeBytes: sizeBytes,
      );
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  @override
  Future<void> deleteAttachment({required String attachmentId}) async {
    try {
      await _remoteDataSource.deleteAttachment(attachmentId: attachmentId);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      rethrow;
    }
  }

  AppException _mapPostgrest(PostgrestException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    if (code == '42703' || (msg.contains('does not exist') && msg.contains('column'))) {
      return ServerException(
        'Database schema is out of date. Run the latest migration.',
      );
    }
    if (code == '42P01' || (msg.contains('relation') && msg.contains('does not exist'))) {
      return const ServerException(
        'A required table is missing. Run the project migrations.',
      );
    }
    if (code == '42501' || msg.contains('permission denied') || msg.contains('row-level security')) {
      return const ServerException('Access denied by database policy.');
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
