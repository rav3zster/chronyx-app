import 'package:chronyx/features/todos/domain/entities/todo.dart';

class TodoModel {
  const TodoModel({
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

  static DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    final hasTimezone = dateStr.endsWith('Z') || 
                        (dateStr.length > 10 && (dateStr.contains('+', 10) || dateStr.contains('-', 10)));
    return DateTime.parse(hasTimezone ? dateStr : '${dateStr}Z').toLocal();
  }

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      status: TodoStatus.fromJson(json['status'] as String?),
      priority: TodoPriority.fromJson(json['priority'] as String?),
      category: json['category'] as String?,
      dueDate: _parseDateTime(json['due_date'] as String?),
      reminderTime: _parseDateTime(json['reminder_time'] as String?),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 0,
      projectId: json['project_id'] as String?,
      goalId: json['goal_id'] as String?,
      habitId: json['habit_id'] as String?,
      recurrence: json['recurrence'] as String?,
      parentId: json['parent_id'] as String?,
      createdAt: _parseDateTime(json['created_at'] as String?),
      updatedAt: _parseDateTime(json['updated_at'] as String?),
      completedAt: _parseDateTime(json['completed_at'] as String?),
      energyLevel: TodoEnergyLevel.fromJson(json['energy_level'] as String?),
      tags: (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? const [],
      reminderTimes: (json['reminder_times'] as List<dynamic>?)?.map((t) => _parseDateTime(t.toString())).whereType<DateTime>().toList() ?? const [],
      blockedByIds: (json['blocked_by_ids'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'notes': notes,
      'status': status.jsonKey,
      'priority': priority.jsonKey,
      'category': category,
      'due_date': dueDate?.toIso8601String(),
      'reminder_time': reminderTime?.toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'project_id': projectId,
      'goal_id': goalId,
      'habit_id': habitId,
      'recurrence': recurrence,
      'parent_id': parentId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'energy_level': energyLevel.jsonKey,
      'tags': tags,
      'reminder_times': reminderTimes.map((t) => t.toIso8601String()).toList(),
      'blocked_by_ids': blockedByIds,
    };
  }

  Todo toEntity({List<Todo> subtasks = const []}) {
    return Todo(
      id: id,
      userId: userId,
      title: title,
      notes: notes,
      status: status,
      priority: priority,
      category: category,
      dueDate: dueDate,
      reminderTime: reminderTime,
      estimatedMinutes: estimatedMinutes,
      projectId: projectId,
      goalId: goalId,
      habitId: habitId,
      recurrence: recurrence,
      parentId: parentId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
      subtasks: subtasks,
      energyLevel: energyLevel,
      tags: tags,
      reminderTimes: reminderTimes,
      blockedByIds: blockedByIds,
    );
  }
}
