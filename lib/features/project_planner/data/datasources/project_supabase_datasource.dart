import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_remote_datasource.dart';
import 'package:chronyx/features/project_planner/data/models/project_model.dart';
import 'package:chronyx/features/project_planner/data/models/project_task_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectSupabaseDataSource implements ProjectRemoteDataSource {
  ProjectSupabaseDataSource(this._client);

  final SupabaseClient _client;
  static const String _projectsTable = 'projects';
  static const String _tasksTable = 'project_tasks';

  String get _currentUserId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const UnknownException('Not authenticated');
    return uid;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Logging helpers
  // ─────────────────────────────────────────────────────────────────────

  void _logSuccess(String table, dynamic id) {
    debugPrint('[Blueprint][success] table: $table | id: $id');
  }

  void _logError(String table, Object error, [StackTrace? st]) {
    if (error is PostgrestException) {
      debugPrint('[Blueprint][error] table: $table');
      debugPrint('[Blueprint][error]   code: ${error.code}');
      debugPrint('[Blueprint][error]   message: ${error.message}');
      debugPrint('[Blueprint][error]   details: ${error.details}');
      debugPrint('[Blueprint][error]   hint: ${error.hint}');
    } else {
      debugPrint('[Blueprint][error] table: $table | $error');
    }
    if (st != null) debugPrintStack(stackTrace: st, label: '[Blueprint]');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Projects
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<List<ProjectModel>> fetchProjects() async {
    final userId = _currentUserId;
    final List<dynamic> rows = await _client
        .from(_projectsTable)
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return rows
        .map((json) => ProjectModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProjectModel> fetchProject(String projectId) async {
    final userId = _currentUserId;
    final json = await _client
        .from(_projectsTable)
        .select()
        .eq('id', projectId)
        .eq('user_id', userId)
        .single();

    return ProjectModel.fromJson(json);
  }

  @override
  Future<ProjectModel> createProject(Map<String, dynamic> data) async {
    final userId = _currentUserId;
    final insertData = {...data, 'user_id': userId};

    // ── Exact diagnostics as requested ───────────────────────────────────
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;

    debugPrint('====================');
    debugPrint('[BLUEPRINT SAVE]');
    debugPrint('Current user id: ${user?.id}');
    debugPrint('Current user email: ${user?.email}');
    debugPrint('Session exists: ${session != null}');
    debugPrint('Access token exists: ${session?.accessToken != null}');
    debugPrint('Refresh token exists: ${session?.refreshToken != null}');
    debugPrint('JWT expired?: ${session?.isExpired}');
    debugPrint('Payload before insert: $insertData');
    debugPrint('Contains user_id: ${insertData['user_id']}');
    debugPrint('====================');
    // ─────────────────────────────────────────────────────────────────────

    try {
      final response = await _client
          .from('projects')
          .insert(insertData)
          .select()
          .single();

      debugPrint('[Blueprint] INSERT SUCCESS');
      debugPrint(response.toString());

      return ProjectModel.fromJson(response);
    } on PostgrestException catch (e, st) {
      debugPrint('[Blueprint][PostgrestException]');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrint('details: ${e.details}');
      debugPrint('hint: ${e.hint}');
      debugPrintStack(stackTrace: st);
      throw _mapPostgrest(e, _projectsTable);
    } catch (e, st) {
      debugPrint('[Blueprint][Unknown]');
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> updateProjectStatus(String projectId, String status) async {
    final userId = _currentUserId;
    await _client
        .from(_projectsTable)
        .update({'status': status})
        .eq('id', projectId)
        .eq('user_id', userId);
  }

  @override
  Future<void> updateProjectFields(
    String projectId,
    Map<String, dynamic> fields,
  ) async {
    if (fields.isEmpty) return;
    final userId = _currentUserId;
    try {
      await _client
          .from(_projectsTable)
          .update(fields)
          .eq('id', projectId)
          .eq('user_id', userId);
    } on PostgrestException catch (e, st) {
      _logError(_projectsTable, e, st);
      throw _mapPostgrest(e, _projectsTable);
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    // Soft delete — never hard-delete. Reads filter on is_deleted = false.
    final userId = _currentUserId;
    await _client
        .from(_projectsTable)
        .update({
          'is_deleted': true,
          'status': 'deleted',
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', projectId)
        .eq('user_id', userId);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tasks
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<List<ProjectTaskModel>> fetchProjectTasks(String projectId) async {
    final List<dynamic> rows = await _client
        .from(_tasksTable)
        .select()
        .eq('project_id', projectId)
        .order('day_number', ascending: true)
        .order('sort_order', ascending: true);

    return rows
        .map((json) => ProjectTaskModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> insertProjectTasks(List<Map<String, dynamic>> tasks) async {
    if (tasks.isEmpty) return;

    // Log first task as representative sample
    debugPrint(
      '[Blueprint][save] table: $_tasksTable | count: ${tasks.length}',
    );
    debugPrint(
      '[Blueprint][save] sample task: ${_safeTaskPreview(tasks.first)}',
    );

    try {
      await _client.from(_tasksTable).insert(tasks);
      _logSuccess(_tasksTable, '${tasks.length} rows');
    } on PostgrestException catch (e, st) {
      _logError(_tasksTable, e, st);
      throw _mapPostgrest(e, _tasksTable);
    } catch (e, st) {
      _logError(_tasksTable, e, st);
      rethrow;
    }
  }

  @override
  Future<void> replaceProjectTasks(
    String projectId,
    List<Map<String, dynamic>> tasks,
  ) async {
    // Delete any existing rows for this project first so recovery never
    // creates duplicates, then insert the rebuilt set.
    try {
      await _client.from(_tasksTable).delete().eq('project_id', projectId);
      if (tasks.isEmpty) return;
      await _client.from(_tasksTable).insert(tasks);
      _logSuccess(_tasksTable, 'replaced ${tasks.length} rows');
    } on PostgrestException catch (e, st) {
      _logError(_tasksTable, e, st);
      throw _mapPostgrest(e, _tasksTable);
    } catch (e, st) {
      _logError(_tasksTable, e, st);
      rethrow;
    }
  }

  @override
  Future<void> updateTaskStatus(
    String taskId,
    String status, {
    DateTime? completedAt,
  }) async {
    final update = <String, dynamic>{'status': status};
    if (completedAt != null) {
      update['completed_at'] = completedAt.toIso8601String();
    } else if (status != 'completed') {
      update['completed_at'] = null;
    }
    await _client.from(_tasksTable).update(update).eq('id', taskId);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _client.from(_tasksTable).delete().eq('id', taskId);
  }

  @override
  Future<void> attributeSessionMinutes({
    required String projectTaskId,
    required int minutes,
  }) async {
    if (minutes <= 0) return;
    try {
      // Read the task to get its project + current actual_minutes.
      final task = await _client
          .from(_tasksTable)
          .select('project_id, actual_minutes')
          .eq('id', projectTaskId)
          .maybeSingle();
      if (task == null) return; // task was deleted; nothing to attribute.

      final projectId = task['project_id'] as String?;
      final taskMinutes = (task['actual_minutes'] as int?) ?? 0;

      await _client
          .from(_tasksTable)
          .update({'actual_minutes': taskMinutes + minutes})
          .eq('id', projectTaskId);

      if (projectId == null) return;
      final project = await _client
          .from(_projectsTable)
          .select('actual_minutes_spent')
          .eq('id', projectId)
          .maybeSingle();
      final projMinutes = (project?['actual_minutes_spent'] as int?) ?? 0;
      await _client
          .from(_projectsTable)
          .update({
            'actual_minutes_spent': projMinutes + minutes,
            'last_active_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', projectId);
    } on PostgrestException catch (e, st) {
      _logError(_tasksTable, e, st);
      throw _mapPostgrest(e, _tasksTable);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Error mapping
  // ─────────────────────────────────────────────────────────────────────

  AppException _mapPostgrest(PostgrestException e, String table) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    // 42P01 — table does not exist
    if (code == '42P01' ||
        (msg.contains('relation') && msg.contains('does not exist'))) {
      return ServerException(
        'Table "$table" does not exist. Run the project migrations in Supabase.',
      );
    }
    // 42703 — column does not exist
    if (code == '42703' ||
        (msg.contains('column') && msg.contains('does not exist'))) {
      return ServerException(
        'A required column is missing in "$table". '
        'Run the latest migration: ${e.message}',
      );
    }
    // 23502 — not-null violation
    if (code == '23502') {
      return ServerException(
        'Required field missing for "$table": ${e.message}',
      );
    }
    // 23503 — foreign key violation
    if (code == '23503') {
      return ServerException(
        'Foreign key constraint failed for "$table": ${e.message}',
      );
    }
    // 23505 — unique violation
    if (code == '23505') {
      return ServerException('Duplicate entry in "$table": ${e.message}');
    }
    // 42501 / RLS
    if (code == '42501' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security') ||
        msg.contains('rls')) {
      return ServerException(
        'Access denied for "$table". Check RLS policies in Supabase.',
      );
    }
    // JWT / auth
    if (msg.contains('jwt') || msg.contains('not authenticated')) {
      return const ServerException('Session expired. Please sign in again.');
    }
    // Generic — surface the real message
    return ServerException('Database error on "$table": ${e.message}');
  }

  Map<String, dynamic> _safeTaskPreview(Map<String, dynamic> task) {
    final preview = Map<String, dynamic>.from(task);
    // Truncate todos for readability
    if (preview['todos'] is List) {
      final todos = preview['todos'] as List;
      preview['todos'] = todos.length > 2
          ? [...todos.take(2), '...+${todos.length - 2} more']
          : todos;
    }
    return preview;
  }
}
