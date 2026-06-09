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
    this.durationMinutes,
    this.status = SessionStatus.completed,
    this.mode = SessionMode.stopwatch,
    this.targetDurationMinutes,
  });

  final String id;
  final String userId;
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;
  final TaskCategory category;
  final String? projectTaskId;
  final int? durationMinutes;
  final SessionStatus status;
  final SessionMode mode;
  final int? targetDurationMinutes;

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    final endTimeStr = json['end_time'] as String?;
    final parsedEndTime = endTimeStr == null ? null : DateTime.parse(endTimeStr);
    
    // Backward compatibility check for status
    final statusStr = json['status'] as String?;
    final status = statusStr != null 
        ? SessionStatus.fromJson(statusStr)
        : (parsedEndTime == null ? SessionStatus.active : SessionStatus.completed);

    return TimeEntryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      taskName: (json['task_name'] as String?) ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: parsedEndTime,
      category: TaskCategory.fromJson(json['category'] as String?),
      projectTaskId: json['project_task_id'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      status: status,
      mode: SessionMode.fromJson(json['mode'] as String?),
      targetDurationMinutes: (json['target_duration_minutes'] as num?)?.toInt(),
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
      'duration_minutes': durationMinutes,
      'status': status.jsonKey,
      'mode': mode.jsonKey,
      'target_duration_minutes': targetDurationMinutes,
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
      durationMinutes: durationMinutes,
      status: status,
      mode: mode,
      targetDurationMinutes: targetDurationMinutes,
    );
  }
}
