import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/todos/data/datasources/todos_remote_datasource.dart';
import 'package:chronyx/features/todos/data/models/todo_model.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/data/models/todo_attachment_model.dart';
import 'package:chronyx/features/todos/domain/entities/todo_attachment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodosSupabaseDataSource implements TodosRemoteDataSource {
  TodosSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;
  static const String _tableName = 'todos';
  static const String _attachmentsTableName = 'todo_attachments';

  String get _currentUserId {
    final uid = _supabaseClient.auth.currentUser?.id;
    if (uid == null) throw const UnknownException('Not authenticated');
    return uid;
  }

  @override
  Future<List<TodoModel>> fetchTodos() async {
    final String userId = _currentUserId;
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.map((row) => TodoModel.fromJson(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<TodoModel> createTodo({
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
    final String userId = _currentUserId;
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Title cannot be empty');
    }

    final DateTime now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      'user_id': userId,
      'title': trimmed,
      'notes': notes?.trim().isEmpty == true ? null : notes,
      'status': status.jsonKey,
      'priority': priority.jsonKey,
      'category': category?.trim().isEmpty == true ? null : category,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'reminder_time': reminderTime?.toUtc().toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'project_id': projectId,
      'goal_id': goalId,
      'habit_id': habitId,
      'recurrence': recurrence,
      'parent_id': parentId,
      'energy_level': energyLevel.jsonKey,
      'tags': tags,
      'reminder_times': reminderTimes.map((t) => t.toUtc().toIso8601String()).toList(),
      'blocked_by_ids': blockedByIds,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .insert(data)
        .select();

    return TodoModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<TodoModel> updateTodo({
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
    final String userId = _currentUserId;
    if (title != null && title.trim().isEmpty) {
      throw const ValidationException('Title cannot be empty');
    }

    final DateTime now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes,
      if (status != null) 'status': status.jsonKey,
      if (status == TodoStatus.completed) 'completed_at': now.toIso8601String(),
      if (status != null && status != TodoStatus.completed) 'completed_at': null,
      if (priority != null) 'priority': priority.jsonKey,
      if (category != null) 'category': category.trim().isEmpty ? null : category,
      if (clearDueDate) 'due_date': null else if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
      if (clearReminderTime) 'reminder_time': null else if (reminderTime != null) 'reminder_time': reminderTime.toUtc().toIso8601String(),
      if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      if (projectId != null) 'project_id': projectId,
      if (goalId != null) 'goal_id': goalId,
      if (habitId != null) 'habit_id': habitId,
      if (recurrence != null) 'recurrence': recurrence,
      if (clearParentId) 'parent_id': null else if (parentId != null) 'parent_id': parentId,
      if (energyLevel != null) 'energy_level': energyLevel.jsonKey,
      if (tags != null) 'tags': tags,
      if (reminderTimes != null) 'reminder_times': reminderTimes.map((t) => t.toUtc().toIso8601String()).toList(),
      if (blockedByIds != null) 'blocked_by_ids': blockedByIds,
      'updated_at': now.toIso8601String(),
    };

    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .update(data)
        .eq('user_id', userId)
        .eq('id', id)
        .select();

    return TodoModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTodo({required String id}) async {
    final String userId = _currentUserId;
    await _supabaseClient
        .from(_tableName)
        .delete()
        .eq('user_id', userId)
        .eq('id', id);
  }

  // ── Attachments ────────────────────────────────────────────────────────────

  @override
  Future<List<TodoAttachmentModel>> fetchAttachments({required String todoId}) async {
    final List<dynamic> rows = await _supabaseClient
        .from(_attachmentsTableName)
        .select()
        .eq('todo_id', todoId)
        .order('created_at', ascending: true);
    return rows.map((row) => TodoAttachmentModel.fromJson(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<TodoAttachmentModel> createAttachment({
    required String todoId,
    required String name,
    required String url,
    required TodoAttachmentType type,
    int? sizeBytes,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      'todo_id': todoId,
      'name': name.trim(),
      'url': url.trim(),
      'type': type.jsonKey,
      'size_bytes': sizeBytes,
      'created_at': now.toIso8601String(),
    };
    final List<dynamic> rows = await _supabaseClient
        .from(_attachmentsTableName)
        .insert(data)
        .select();
    return TodoAttachmentModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAttachment({required String attachmentId}) async {
    await _supabaseClient
        .from(_attachmentsTableName)
        .delete()
        .eq('id', attachmentId);
  }
}
