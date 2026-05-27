import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_remote_datasource.dart';
import 'package:chronyx/features/project_planner/data/models/project_model.dart';
import 'package:chronyx/features/project_planner/data/models/project_task_model.dart';
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
    final userId = _currentUserId;
    final insertData = {...data, 'user_id': userId};

    final List<dynamic> rows = await _client
        .from(_projectsTable)
        .insert(insertData)
        .select();

    return ProjectModel.fromJson(rows.first as Map<String, dynamic>);
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
    await _client.from(_tasksTable).insert(tasks);
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
}
