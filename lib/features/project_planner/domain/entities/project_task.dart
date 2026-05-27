/// Status of an individual task within a project.
enum ProjectTaskStatus {
  pending,
  inProgress,
  completed,
  skipped;

  String get jsonKey => switch (this) {
    ProjectTaskStatus.pending => 'pending',
    ProjectTaskStatus.inProgress => 'in_progress',
    ProjectTaskStatus.completed => 'completed',
    ProjectTaskStatus.skipped => 'skipped',
  };

  static ProjectTaskStatus fromJson(String? value) => switch (value) {
    'in_progress' => ProjectTaskStatus.inProgress,
    'completed' => ProjectTaskStatus.completed,
    'skipped' => ProjectTaskStatus.skipped,
    _ => ProjectTaskStatus.pending,
  };
}

/// A task belonging to a project, representing one actionable item
/// within a day of the blueprint roadmap.
class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    this.estimatedMinutes,
    this.completedAt,
  });

  final String id;
  final String projectId;
  final int dayNumber;
  final String title;
  final String description;
  final int sortOrder;
  final int? estimatedMinutes;
  final ProjectTaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
}
