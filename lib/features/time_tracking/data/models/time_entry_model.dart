import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

class TimeEntryModel {
  const TimeEntryModel({
    required this.id,
    required this.userId,
    required this.taskName,
    required this.startTime,
    required this.endTime,
    this.category = TaskCategory.other,
    this.projectTaskId,
    this.elapsedSeconds = 0,
    this.durationMinutes = 0,
    this.targetDurationMinutes,
    this.completionPercentage = 0.0,
    this.pausedDurationSeconds = 0,
    this.pausedAt,
    this.sessionMode = SessionMode.stopwatch,
    this.status = SessionStatus.completed,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;
  final TaskCategory category;
  final String? projectTaskId;
  final int elapsedSeconds;
  final int durationMinutes;
  final int? targetDurationMinutes;
  final double completionPercentage;
  final int pausedDurationSeconds;
  final DateTime? pausedAt;
  final SessionMode sessionMode;
  final SessionStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    final hasTimezone = dateStr.endsWith('Z') || 
                        (dateStr.length > 10 && (dateStr.contains('+', 10) || dateStr.contains('-', 10)));
    return DateTime.parse(hasTimezone ? dateStr : '${dateStr}Z').toLocal();
  }

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    final endTimeStr = json['end_time'] as String?;
    final parsedEndTime = _parseDateTime(endTimeStr);
    
    // Backward compatibility check for status
    final statusStr = json['status'] as String?;
    final status = statusStr != null 
        ? SessionStatus.fromJson(statusStr)
        : (parsedEndTime == null ? SessionStatus.active : SessionStatus.completed);

    // Support both 'session_mode' and 'mode' names
    final modeStr = json['session_mode'] as String? ?? json['mode'] as String?;
    final sessionMode = SessionMode.fromJson(modeStr);

    final pausedAtStr = json['paused_at'] as String?;
    final parsedPausedAt = _parseDateTime(pausedAtStr);

    final createdAtStr = json['created_at'] as String?;
    final parsedCreatedAt = _parseDateTime(createdAtStr);

    final updatedAtStr = json['updated_at'] as String?;
    final parsedUpdatedAt = _parseDateTime(updatedAtStr);

    return TimeEntryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      taskName: (json['task_name'] as String?) ?? '',
      startTime: _parseDateTime(json['start_time'] as String)!,
      endTime: parsedEndTime,
      category: TaskCategory.fromJson(json['category'] as String?),
      projectTaskId: json['project_task_id'] as String?,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      targetDurationMinutes: (json['target_duration_minutes'] as num?)?.toInt(),
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      pausedDurationSeconds: (json['paused_duration_seconds'] as num?)?.toInt() ?? 0,
      pausedAt: parsedPausedAt,
      sessionMode: sessionMode,
      status: status,
      notes: json['notes'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'task_name': taskName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'category': category.jsonKey,
      'project_task_id': projectTaskId,
      'elapsed_seconds': elapsedSeconds,
      'duration_minutes': durationMinutes,
      'target_duration_minutes': targetDurationMinutes,
      'completion_percentage': completionPercentage,
      'paused_duration_seconds': pausedDurationSeconds,
      'paused_at': pausedAt?.toIso8601String(),
      'session_mode': sessionMode.jsonKey,
      'status': status.jsonKey,
      'notes': notes,
    };
  }

  TimeEntry toEntity() {
    return TimeEntry(
      id: id,
      taskName: taskName,
      startedAt: startTime,
      endedAt: endTime,
      category: category,
      projectTaskId: projectTaskId,
      elapsedSeconds: elapsedSeconds,
      durationMinutes: durationMinutes,
      targetDurationMinutes: targetDurationMinutes,
      completionPercentage: completionPercentage,
      pausedDurationSeconds: pausedDurationSeconds,
      pausedAt: pausedAt,
      sessionMode: sessionMode,
      status: status,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
