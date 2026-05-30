import 'package:chronyx/features/project_planner/domain/entities/project.dart';

/// Which view the Project Detail screen should render. Pure function of
/// status + whether tasks/blueprint exist — guarantees no dead-end.
enum ProjectDetailViewKind {
  /// active / paused / draft with tasks → working dashboard.
  dashboard,

  /// status == completed → completion experience.
  completed,

  /// status == archived → read-only history.
  archived,

  /// no tasks but a stored blueprint exists → recoverable.
  noTasksRemaining,

  /// no tasks and no blueprint → must regenerate or delete.
  blueprintMissing,
}

/// Resolves the view kind. Total over every combination — there is no
/// branch that yields a bare "No tasks yet" dead-end.
ProjectDetailViewKind resolveProjectDetailView({
  required ProjectStatus status,
  required bool hasTasks,
  required bool hasBlueprint,
}) {
  if (status == ProjectStatus.completed) return ProjectDetailViewKind.completed;
  if (status == ProjectStatus.archived) return ProjectDetailViewKind.archived;
  if (hasTasks) return ProjectDetailViewKind.dashboard;
  return hasBlueprint
      ? ProjectDetailViewKind.noTasksRemaining
      : ProjectDetailViewKind.blueprintMissing;
}
