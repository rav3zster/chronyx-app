import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

class TimeEntryModel {
  const TimeEntryModel({
    required this.id,
    required this.userId,
    required this.taskName,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String userId;
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      taskName: (json['task_name'] as String?) ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'task_name': taskName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
    };
  }

  TimeEntry toEntity() {
    return TimeEntry(
      id: id,
      taskName: taskName,
      startedAt: startTime,
      endedAt: endTime,
    );
  }
}
