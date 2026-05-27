import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';

/// Repository interface for project CRUD and task management.
abstract class ProjectRepository {
  /// Fetch all projects for the current user.
  Future<List<Project>> fetchProjects();

  /// Fetch a single project by ID.
  Future<Project> fetchProject(String projectId);

  /// Create a new project and return it.
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
  });

  /// Update project status.
  Future<void> updateProjectStatus(String projectId, ProjectStatus status);

  /// Delete a project and all associated tasks (cascade).
  Future<void> deleteProject(String projectId);

  /// Fetch all tasks for a given project, ordered by day and sort order.
  Future<List<ProjectTask>> fetchProjectTasks(String projectId);

  /// Batch-insert tasks for a project (used after blueprint parsing).
  Future<void> insertProjectTasks(String projectId, List<ProjectTask> tasks);

  /// Update a single task's status.
  Future<void> updateTaskStatus(String taskId, ProjectTaskStatus status);

  /// Delete a single task.
  Future<void> deleteTask(String taskId);
}
