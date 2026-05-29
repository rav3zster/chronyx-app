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

  void _logSave(String table, Map<String, dynamic> payload) {
    debugPrint('[Blueprint][save] table: $table');
    debugPrint('[Blueprint][save] user_id: ${payload['user_id']}');
    // Log payload without large fields to keep output readable
    final preview = Map<String, dynamic>.from(payload)
      ..remove('raw_blueprint_response')
      ..remove('parsed_blueprint')
      ..remove('generated_prompt');
    debugPrint('[Blueprint][save] payload: $preview');
  }

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
    // ── Diagnostic: verify auth state before insert ──────────────────────
    final currentUser = _client.auth.currentUser;
    final session = _client.auth.currentSession;
    debugPrint('[Blueprint] === createProject diagnostics ===');
    debugPrint('[Blueprint] auth.currentUser?.id : ${currentUser?.id}');
    debugPrint('[Blueprint] auth.currentUser?.email: ${currentUser?.email}');
    debugPrint('[Blueprint] session is null       : ${session == null}');
    if (session != null) {
      debugPrint(
        '[Blueprint] session?.accessToken  : ${session.accessToken.substring(0, 20)}...',
      );
      debugPrint('[Blueprint] session?.expiresAt    : ${session.expiresAt}');
      final isExpired =
          session.expiresAt != null &&
          DateTime.fromMillisecondsSinceEpoch(
            session.expiresAt! * 1000,
          ).isBefore(DateTime.now());
      debugPrint('[Blueprint] session expired       : $isExpired');
    }
    // ─────────────────────────────────────────────────────────────────────

    // Guard: no session means the JWT won't be sent → RLS will reject insert.
    if (session == null) {
      debugPrint('[Blueprint] ABORT: no active session — RLS will deny insert');
      throw const UnknownException(
        'No active session. Please sign in again before saving.',
      );
    }

    final userId = _currentUserId;
    final insertData = {...data, 'user_id': userId};

    // ── Diagnostic: verify user_id is in payload ─────────────────────────
    debugPrint('[Blueprint] userId resolved       : $userId');
    debugPrint('[Blueprint] payload user_id       : ${insertData['user_id']}');
    debugPrint(
      '[Blueprint] user_id match         : ${insertData['user_id'] == currentUser?.id}',
    );
    // ─────────────────────────────────────────────────────────────────────

    _logSave(_projectsTable, insertData);

    try {
      final List<dynamic> rows = await _client
          .from(_projectsTable)
          .insert(insertData)
          .select();

      final model = ProjectModel.fromJson(rows.first as Map<String, dynamic>);
      _logSuccess(_projectsTable, model.id);
      return model;
    } on PostgrestException catch (e, st) {
      _logError(_projectsTable, e, st);
      throw _mapPostgrest(e, _projectsTable);
    } catch (e, st) {
      _logError(_projectsTable, e, st);
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
  Future<void> deleteProject(String projectId) async {
    final userId = _currentUserId;
    await _client
        .from(_projectsTable)
        .delete()
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
