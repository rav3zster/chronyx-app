import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_remote_datasource.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._dataSource);

  final ProjectRemoteDataSource _dataSource;

  @override
  Future<List<Project>> fetchProjects() async {
    try {
      final models = await _dataSource.fetchProjects();
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to fetch projects');
    }
  }

  @override
  Future<Project> fetchProject(String projectId) async {
    try {
      final model = await _dataSource.fetchProject(projectId);
      return model.toEntity();
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to fetch project');
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
    } on Exception {
      throw const UnknownException('Failed to create project');
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
    } on Exception {
      throw const UnknownException('Failed to update project status');
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    try {
      await _dataSource.deleteProject(projectId);
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to delete project');
    }
  }

  @override
  Future<List<ProjectTask>> fetchProjectTasks(String projectId) async {
    try {
      final models = await _dataSource.fetchProjectTasks(projectId);
      return models.map((m) => m.toEntity()).toList();
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to fetch project tasks');
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
            },
          )
          .toList();
      await _dataSource.insertProjectTasks(jsonTasks);
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to insert project tasks');
    }
  }

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
    } on Exception {
      throw const UnknownException('Failed to update task status');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _dataSource.deleteTask(taskId);
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException('Failed to delete task');
    }
  }
}
