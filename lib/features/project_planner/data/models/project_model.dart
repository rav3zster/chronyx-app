import 'dart:convert';

import 'package:chronyx/features/project_planner/domain/entities/project.dart';

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.goalDescription,
    required this.template,
    required this.durationDays,
    required this.difficulty,
    required this.dailyTimeMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.generatedPrompt,
    this.rawBlueprintResponse,
    this.parsedBlueprint,
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.archivedAt,
    this.deletedAt,
    this.lastActiveAt,
    this.completionPercentage = 0,
    this.completedDays = 0,
    this.completedTasks = 0,
    this.estimatedTotalMinutes = 0,
    this.actualMinutesSpent = 0,
    this.streakDays = 0,
    this.isDeleted = false,
  });

  final String id;
  final String userId;
  final String title;
  final String goalDescription;
  final String template;
  final int durationDays;
  final String difficulty;
  final int dailyTimeMinutes;
  final String? generatedPrompt;
  final String? rawBlueprintResponse;
  final Map<String, dynamic>? parsedBlueprint;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime? lastActiveAt;
  final int completionPercentage;
  final int completedDays;
  final int completedTasks;
  final int estimatedTotalMinutes;
  final int actualMinutesSpent;
  final int streakDays;
  final bool isDeleted;

  static DateTime? _parseTs(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: (json['title'] as String?) ?? '',
      goalDescription: (json['goal_description'] as String?) ?? '',
      template: (json['template'] as String?) ?? 'custom',
      durationDays: (json['duration_days'] as int?) ?? 30,
      difficulty: (json['difficulty'] as String?) ?? 'medium',
      dailyTimeMinutes: (json['daily_time_minutes'] as int?) ?? 120,
      generatedPrompt: json['generated_prompt'] as String?,
      rawBlueprintResponse: json['raw_blueprint_response'] as String?,
      parsedBlueprint: json['parsed_blueprint'] != null
          ? (json['parsed_blueprint'] is String
                ? jsonDecode(json['parsed_blueprint'] as String)
                      as Map<String, dynamic>
                : json['parsed_blueprint'] as Map<String, dynamic>)
          : null,
      status: (json['status'] as String?) ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      startedAt: _parseTs(json['started_at']),
      completedAt: _parseTs(json['completed_at']),
      pausedAt: _parseTs(json['paused_at']),
      archivedAt: _parseTs(json['archived_at']),
      deletedAt: _parseTs(json['deleted_at']),
      lastActiveAt: _parseTs(json['last_active_at']),
      completionPercentage: (json['completion_percentage'] as int?) ?? 0,
      completedDays: (json['completed_days'] as int?) ?? 0,
      completedTasks: (json['completed_tasks'] as int?) ?? 0,
      estimatedTotalMinutes: (json['estimated_total_minutes'] as int?) ?? 0,
      actualMinutesSpent: (json['actual_minutes_spent'] as int?) ?? 0,
      streakDays: (json['streak_days'] as int?) ?? 0,
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'user_id': userId,
      'title': title,
      'goal_description': goalDescription,
      'template': template,
      'duration_days': durationDays,
      'difficulty': difficulty,
      'daily_time_minutes': dailyTimeMinutes,
      'generated_prompt': generatedPrompt,
      'raw_blueprint_response': rawBlueprintResponse,
      'parsed_blueprint': parsedBlueprint,
      'status': status,
    };
  }

  Project toEntity() {
    return Project(
      id: id,
      userId: userId,
      title: title,
      goalDescription: goalDescription,
      template: template,
      durationDays: durationDays,
      difficulty: ProjectDifficulty.fromJson(difficulty),
      dailyTimeMinutes: dailyTimeMinutes,
      generatedPrompt: generatedPrompt,
      rawBlueprintResponse: rawBlueprintResponse,
      parsedBlueprint: parsedBlueprint != null
          ? _parseBlueprintFromJson(parsedBlueprint!)
          : null,
      status: ProjectStatus.fromJson(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      pausedAt: pausedAt,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      lastActiveAt: lastActiveAt,
      completionPercentage: completionPercentage,
      completedDays: completedDays,
      completedTasks: completedTasks,
      estimatedTotalMinutes: estimatedTotalMinutes,
      actualMinutesSpent: actualMinutesSpent,
      streakDays: streakDays,
      isDeleted: isDeleted,
    );
  }

  static ParsedBlueprint? _parseBlueprintFromJson(Map<String, dynamic> json) {
    try {
      final title = (json['title'] as String?) ?? 'Untitled';
      final rawDays = json['days'] as List<dynamic>?;
      if (rawDays == null) return null;

      final days = rawDays.map((d) {
        final dayJson = d as Map<String, dynamic>;
        final rawTasks = dayJson['tasks'] as List<dynamic>? ?? [];
        return DayPlan(
          dayNumber: (dayJson['day_number'] as int?) ?? 1,
          title: (dayJson['title'] as String?) ?? '',
          estimatedMinutes: (dayJson['estimated_minutes'] as int?) ?? 0,
          tasks: rawTasks.map((t) {
            final taskJson = t as Map<String, dynamic>;
            final rawTodos = taskJson['todos'] as List<dynamic>? ?? [];
            return BlueprintTask(
              title: (taskJson['title'] as String?) ?? '',
              description: (taskJson['description'] as String?) ?? '',
              estimatedMinutes: (taskJson['estimated_minutes'] as int?) ?? 30,
              todos: rawTodos.map((e) => e.toString()).toList(),
            );
          }).toList(),
        );
      }).toList();

      return ParsedBlueprint(title: title, days: days);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> blueprintToJson(ParsedBlueprint blueprint) {
    return {
      'title': blueprint.title,
      'days': blueprint.days
          .map(
            (day) => {
              'day_number': day.dayNumber,
              'title': day.title,
              'estimated_minutes': day.estimatedMinutes,
              'tasks': day.tasks
                  .map(
                    (task) => {
                      'title': task.title,
                      'description': task.description,
                      'estimated_minutes': task.estimatedMinutes,
                      'todos': task.todos,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }
}
