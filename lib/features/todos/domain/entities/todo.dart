enum TodoStatus {
  pending,
  inProgress,
  completed,
  archived;

  String get jsonKey => switch (this) {
    TodoStatus.pending => 'pending',
    TodoStatus.inProgress => 'in_progress',
    TodoStatus.completed => 'completed',
    TodoStatus.archived => 'archived',
  };

  String get label => switch (this) {
    TodoStatus.pending => 'Pending',
    TodoStatus.inProgress => 'In Progress',
    TodoStatus.completed => 'Completed',
    TodoStatus.archived => 'Archived',
  };

  static TodoStatus fromJson(String? value) => switch (value) {
    'pending' => TodoStatus.pending,
    'in_progress' => TodoStatus.inProgress,
    'completed' => TodoStatus.completed,
    'archived' => TodoStatus.archived,
    _ => TodoStatus.pending,
  };
}

enum TodoPriority {
  low,
  medium,
  high,
  critical;

  String get jsonKey => name;

  String get label => switch (this) {
    TodoPriority.low => 'Low',
    TodoPriority.medium => 'Medium',
    TodoPriority.high => 'High',
    TodoPriority.critical => 'Critical',
  };

  static TodoPriority fromJson(String? value) => switch (value) {
    'low' => TodoPriority.low,
    'medium' => TodoPriority.medium,
    'high' => TodoPriority.high,
    'critical' => TodoPriority.critical,
    _ => TodoPriority.medium,
  };
}

enum TodoEnergyLevel {
  low,
  medium,
  high;

  String get jsonKey => name;

  String get label => switch (this) {
    TodoEnergyLevel.low => 'Low Energy',
    TodoEnergyLevel.medium => 'Medium Energy',
    TodoEnergyLevel.high => 'High Energy',
  };

  static TodoEnergyLevel fromJson(String? value) => switch (value) {
    'low' => TodoEnergyLevel.low,
    'medium' => TodoEnergyLevel.medium,
    'high' => TodoEnergyLevel.high,
    _ => TodoEnergyLevel.medium,
  };
}

class Todo {
  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    this.status = TodoStatus.pending,
    this.priority = TodoPriority.medium,
    this.category,
    this.dueDate,
    this.reminderTime,
    this.estimatedMinutes = 0,
    this.projectId,
    this.goalId,
    this.habitId,
    this.recurrence,
    this.parentId,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.subtasks = const [],
    this.energyLevel = TodoEnergyLevel.medium,
    this.tags = const [],
    this.reminderTimes = const [],
    this.blockedByIds = const [],
  });

  final String id;
  final String userId;
  final String title;
  final String? notes;
  final TodoStatus status;
  final TodoPriority priority;
  final String? category;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final int estimatedMinutes;
  final String? projectId;
  final String? goalId;
  final String? habitId;
  final String? recurrence;
  final String? parentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final TodoEnergyLevel energyLevel;
  final List<String> tags;
  final List<DateTime> reminderTimes;
  final List<String> blockedByIds;

  // In-memory tree representation of nested subtasks
  final List<Todo> subtasks;

  bool get isCompleted => status == TodoStatus.completed;

  Todo copyWith({
    String? title,
    String? notes,
    TodoStatus? status,
    TodoPriority? priority,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? estimatedMinutes,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    List<Todo>? subtasks,
    TodoEnergyLevel? energyLevel,
    List<String>? tags,
    List<DateTime>? reminderTimes,
    List<String>? blockedByIds,
    bool clearDueDate = false,
    bool clearReminderTime = false,
  }) {
    return Todo(
      id: id,
      userId: userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      projectId: projectId ?? this.projectId,
      goalId: goalId ?? this.goalId,
      habitId: habitId ?? this.habitId,
      recurrence: recurrence ?? this.recurrence,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      subtasks: subtasks ?? this.subtasks,
      energyLevel: energyLevel ?? this.energyLevel,
      tags: tags ?? this.tags,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      blockedByIds: blockedByIds ?? this.blockedByIds,
    );
  }
}
