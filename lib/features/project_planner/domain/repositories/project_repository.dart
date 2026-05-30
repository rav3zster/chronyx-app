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

  /// Persist a lifecycle transition: status + the relevant timestamp(s) and
  /// `last_active_at`. Use [extraFields] for progress counters.
  Future<void> applyLifecycle(
    String projectId,
    ProjectStatus status, {
    Map<String, dynamic> extraFields = const {},
  });

  /// Persist derived progress counters (completion %, completed tasks/days,
  /// streak, last_active_at) without changing status.
  Future<void> saveProgress(
    String projectId, {
    required int completionPercentage,
    required int completedTasks,
    required int completedDays,
    required int streakDays,
  });

  /// Delete a project and all associated tasks (cascade).
  Future<void> deleteProject(String projectId);

  /// Fetch all tasks for a given project, ordered by day and sort order.
  Future<List<ProjectTask>> fetchProjectTasks(String projectId);

  /// Batch-insert tasks for a project (used after blueprint parsing).
  Future<void> insertProjectTasks(String projectId, List<ProjectTask> tasks);

  /// Rebuild tasks from the project's stored `parsed_blueprint`.
  ///
  /// [replaceAll] = true wipes existing tasks and rebuilds the full roadmap.
  /// [replaceAll] = false (default) inserts only the days/tasks that are
  /// missing, preserving existing task progress.
  ///
  /// Returns the number of tasks created. Throws if the project has no
  /// stored blueprint.
  Future<int> restoreTasksFromBlueprint(
    String projectId, {
    bool replaceAll = false,
  });

  /// Update a single task's status.
  Future<void> updateTaskStatus(String taskId, ProjectTaskStatus status);

  /// Add tracked [minutes] to a task's actual_minutes and the parent
  /// project's actual_minutes_spent. Used when a focus session linked to a
  /// project task finishes. No-op for minutes <= 0.
  Future<void> attributeSessionMinutes({
    required String projectTaskId,
    required int minutes,
  });

  /// Delete a single task.
  Future<void> deleteTask(String taskId);
}
