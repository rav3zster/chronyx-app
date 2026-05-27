import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';

class ProjectTaskModel {
  const ProjectTaskModel({
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
    this.todos = const [],
  });

  final String id;
  final String projectId;
  final int dayNumber;
  final String title;
  final String description;
  final int sortOrder;
  final int? estimatedMinutes;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> todos;

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
    final rawTodos = json['todos'];
    List<String> todos = [];
    if (rawTodos is List) {
      todos = rawTodos.map((e) => e.toString()).toList();
    }

    return ProjectTaskModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      dayNumber: (json['day_number'] as int?) ?? 1,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      estimatedMinutes: json['estimated_minutes'] as int?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      todos: todos,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'project_id': projectId,
      'day_number': dayNumber,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
      'estimated_minutes': estimatedMinutes,
      'status': status,
      'todos': todos,
    };
  }

  ProjectTask toEntity() {
    return ProjectTask(
      id: id,
      projectId: projectId,
      dayNumber: dayNumber,
      title: title,
      description: description,
      sortOrder: sortOrder,
      estimatedMinutes: estimatedMinutes,
      status: ProjectTaskStatus.fromJson(status),
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }
}
