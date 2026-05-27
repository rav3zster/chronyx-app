import 'package:chronyx/features/project_planner/data/models/project_model.dart';
import 'package:chronyx/features/project_planner/data/models/project_task_model.dart';

/// Remote datasource interface for project planner persistence.
abstract class ProjectRemoteDataSource {
  /// Fetch all projects for the current user.
  Future<List<ProjectModel>> fetchProjects();

  /// Fetch a single project by ID.
  Future<ProjectModel> fetchProject(String projectId);

  /// Create a new project and return it.
  Future<ProjectModel> createProject(Map<String, dynamic> data);

  /// Update project status.
  Future<void> updateProjectStatus(String projectId, String status);

  /// Delete a project (cascade deletes tasks via DB constraint).
  Future<void> deleteProject(String projectId);

  /// Fetch all tasks for a project, ordered by day and sort order.
  Future<List<ProjectTaskModel>> fetchProjectTasks(String projectId);

  /// Batch-insert tasks for a project.
  Future<void> insertProjectTasks(List<Map<String, dynamic>> tasks);

  /// Update a single task's status and optionally set completed_at.
  Future<void> updateTaskStatus(
    String taskId,
    String status, {
    DateTime? completedAt,
  });

  /// Delete a single task.
  Future<void> deleteTask(String taskId);
}
