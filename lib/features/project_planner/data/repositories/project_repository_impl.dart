import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_remote_datasource.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/domain/repositories/blueprint_parser.dart';
import 'package:chronyx/features/project_planner/domain/repositories/project_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._dataSource, this._parser);

  final ProjectRemoteDataSource _dataSource;
  final BlueprintParser _parser;

  @override
  Future<List<Project>> fetchProjects() async {
    try {
      final models = await _dataSource.fetchProjects();
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      // Datasource already logged this — just rethrow as ServerException
      // so the UI gets a readable message.
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to fetch projects: $e');
    }
  }

  @override
  Future<Project> fetchProject(String projectId) async {
    try {
      final model = await _dataSource.fetchProject(projectId);
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to fetch project: $e');
    }
  }

  @override
  Future<Project> createProject({
    required String title,
    required String goalDescription,
    required String template,
    required int durationDays,
    required ProjectDifficulty difficulty,
    required int dailyTimeMinutes,
    String? generatedPrompt,
    String? rawBlueprintResponse,
    Map<String, dynamic>? parsedBlueprint,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'goal_description': goalDescription,
        'template': template,
        'duration_days': durationDays,
        'difficulty': difficulty.jsonKey,
        'daily_time_minutes': dailyTimeMinutes,
        'generated_prompt': generatedPrompt,
        'raw_blueprint_response': rawBlueprintResponse,
        'parsed_blueprint': parsedBlueprint,
        'status': 'active',
      };
      final model = await _dataSource.createProject(data);
      return model.toEntity();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to create project: $e');
    }
  }

  @override
  Future<void> updateProjectStatus(
    String projectId,
    ProjectStatus status,
  ) async {
    try {
      await _dataSource.updateProjectStatus(projectId, status.jsonKey);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to update project status: $e');
    }
  }

  @override
  Future<void> applyLifecycle(
    String projectId,
    ProjectStatus status, {
    Map<String, dynamic> extraFields = const {},
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final fields = <String, dynamic>{
      'status': status.jsonKey,
      'last_active_at': now,
      ...extraFields,
    };
    // Stamp the timestamp that matches this transition.
    switch (status) {
      case ProjectStatus.active:
        // started_at is set on first activation (handled by caller via extra).
        fields['paused_at'] = null;
        fields['archived_at'] = null;
      case ProjectStatus.paused:
        fields['paused_at'] = now;
      case ProjectStatus.completed:
        fields['completed_at'] = now;
      case ProjectStatus.archived:
        fields['archived_at'] = now;
      case ProjectStatus.deleted:
        fields['is_deleted'] = true;
        fields['deleted_at'] = now;
      case ProjectStatus.draft:
        break;
    }
    try {
      await _dataSource.updateProjectFields(projectId, fields);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to apply lifecycle: $e');
    }
  }

  @override
  Future<void> saveProgress(
    String projectId, {
    required int completionPercentage,
    required int completedTasks,
    required int completedDays,
    required int streakDays,
  }) async {
    try {
      await _dataSource.updateProjectFields(projectId, {
        'completion_percentage': completionPercentage,
        'completed_tasks': completedTasks,
        'completed_days': completedDays,
        'streak_days': streakDays,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to save progress: $e');
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    try {
      await _dataSource.deleteProject(projectId);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to delete project: $e');
    }
  }

  @override
  Future<List<ProjectTask>> fetchProjectTasks(String projectId) async {
    try {
      final models = await _dataSource.fetchProjectTasks(projectId);
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to fetch project tasks: $e');
    }
  }

  @override
  Future<void> insertProjectTasks(
    String projectId,
    List<ProjectTask> tasks,
  ) async {
    try {
      final jsonTasks = tasks
          .map(
            (task) => <String, dynamic>{
              'project_id': projectId,
              'day_number': task.dayNumber,
              'title': task.title,
              'description': task.description,
              'sort_order': task.sortOrder,
              'estimated_minutes': task.estimatedMinutes,
              'status': task.status.jsonKey,
              // todos is not in ProjectTask entity — omit here.
              // The task model includes it when reading back from DB.
            },
          )
          .toList();
      await _dataSource.insertProjectTasks(jsonTasks);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to insert project tasks: $e');
    }
  }

  @override
  Future<int> restoreTasksFromBlueprint(
    String projectId, {
    bool replaceAll = false,
  }) async {
    try {
      final project = await fetchProject(projectId);
      final blueprint = project.parsedBlueprint;
      if (blueprint == null) {
        throw const ServerException(
          'No saved blueprint to restore from for this project.',
        );
      }

      // Full roadmap rebuilt from the blueprint (always pending).
      final fullTasks = _parser.blueprintToTasks(projectId, blueprint);

      if (replaceAll) {
        final json = fullTasks.map(_taskToJson).toList();
        await _dataSource.replaceProjectTasks(projectId, json);
        return fullTasks.length;
      }

      // Merge mode: only insert tasks for (day, title) pairs not already present.
      final existing = await _dataSource.fetchProjectTasks(projectId);
      final existingKeys = existing
          .map((t) => _taskKey(t.dayNumber, t.title))
          .toSet();

      final missing = fullTasks
          .where((t) => !existingKeys.contains(_taskKey(t.dayNumber, t.title)))
          .toList();

      if (missing.isEmpty) return 0;

      await _dataSource.insertProjectTasks(missing.map(_taskToJson).toList());
      return missing.length;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to restore blueprint: $e');
    }
  }

  String _taskKey(int dayNumber, String title) =>
      '$dayNumber::${title.trim().toLowerCase()}';

  Map<String, dynamic> _taskToJson(ProjectTask task) => <String, dynamic>{
    'project_id': task.projectId,
    'day_number': task.dayNumber,
    'title': task.title,
    'description': task.description,
    'sort_order': task.sortOrder,
    'estimated_minutes': task.estimatedMinutes,
    'status': task.status.jsonKey,
  };

  @override
  Future<void> updateTaskStatus(String taskId, ProjectTaskStatus status) async {
    try {
      await _dataSource.updateTaskStatus(
        taskId,
        status.jsonKey,
        completedAt: status == ProjectTaskStatus.completed
            ? DateTime.now()
            : null,
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to update task status: $e');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _dataSource.deleteTask(taskId);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to delete task: $e');
    }
  }

  @override
  Future<void> attributeSessionMinutes({
    required String projectTaskId,
    required int minutes,
  }) async {
    if (minutes <= 0) return;
    try {
      await _dataSource.attributeSessionMinutes(
        projectTaskId: projectTaskId,
        minutes: minutes,
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on Exception catch (e) {
      throw UnknownException('Failed to attribute session minutes: $e');
    }
  }
}
