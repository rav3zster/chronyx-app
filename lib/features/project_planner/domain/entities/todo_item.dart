/// A lightweight checklist item within a project task.
///
/// Represents a sub-step the user can tick off while working
/// through a [ProjectTask].
class TodoItem {
  const TodoItem({
    required this.id,
    required this.projectTaskId,
    required this.title,
    required this.sortOrder,
    required this.isCompleted,
  });

  final String id;
  final String projectTaskId;
  final String title;
  final int sortOrder;
  final bool isCompleted;
}
