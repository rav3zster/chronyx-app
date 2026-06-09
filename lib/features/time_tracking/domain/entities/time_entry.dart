/// Task categories for productivity analysis.
enum TaskCategory {
  productive,
  learning,
  break_,
  meeting,
  exercise,
  entertainment,
  distraction, // kept for backward-compat with existing rows; hidden from UI
  other;

  String get label => switch (this) {
    TaskCategory.productive => 'Productive',
    TaskCategory.learning => 'Learning',
    TaskCategory.break_ => 'Break',
    TaskCategory.meeting => 'Meeting',
    TaskCategory.exercise => 'Exercise',
    TaskCategory.entertainment => 'Entertainment',
    TaskCategory.distraction => 'Distraction',
    TaskCategory.other => 'Other',
  };

  String get emoji => switch (this) {
    TaskCategory.productive => '🚀',
    TaskCategory.learning => '📚',
    TaskCategory.break_ => '☕',
    TaskCategory.meeting => '🤝',
    TaskCategory.exercise => '💪',
    TaskCategory.entertainment => '🎮',
    TaskCategory.distraction => '🌀',
    TaskCategory.other => '📌',
  };

  /// JSON column value stored in Supabase.
  String get jsonKey => switch (this) {
    TaskCategory.productive => 'productive',
    TaskCategory.learning => 'learning',
    TaskCategory.break_ => 'break',
    TaskCategory.meeting => 'meeting',
    TaskCategory.exercise => 'exercise',
    TaskCategory.entertainment => 'entertainment',
    TaskCategory.distraction => 'distraction',
    TaskCategory.other => 'other',
  };

  /// Whether this category counts toward productive deep-work time.
  bool get isDeepWork =>
      this == TaskCategory.productive || this == TaskCategory.learning;

  /// Whether this category counts toward health/balance time.
  bool get isBalance =>
      this == TaskCategory.break_ ||
      this == TaskCategory.exercise ||
      this == TaskCategory.entertainment;

  static TaskCategory fromJson(String? value) => switch (value) {
    'productive' => TaskCategory.productive,
    'learning' => TaskCategory.learning,
    'break' => TaskCategory.break_,
    'meeting' => TaskCategory.meeting,
    'exercise' => TaskCategory.exercise,
    'entertainment' => TaskCategory.entertainment,
    'distraction' => TaskCategory.distraction,
    _ => TaskCategory.other,
  };

  /// Categories shown in the new-session UI (excludes distraction).
  static List<TaskCategory> get selectable => [
    TaskCategory.productive,
    TaskCategory.learning,
    TaskCategory.break_,
    TaskCategory.meeting,
    TaskCategory.exercise,
    TaskCategory.entertainment,
    TaskCategory.other,
  ];
}

enum SessionStatus {
  active,
  completed,
  cancelled,
  paused;

  String get jsonKey => name;

  String get label => switch (this) {
    SessionStatus.active => 'Active',
    SessionStatus.completed => 'Completed',
    SessionStatus.cancelled => 'Cancelled',
    SessionStatus.paused => 'Paused',
  };

  static SessionStatus fromJson(String? value) => switch (value) {
    'active' => SessionStatus.active,
    'completed' => SessionStatus.completed,
    'cancelled' => SessionStatus.cancelled,
    'paused' => SessionStatus.paused,
    _ => SessionStatus.completed,
  };
}

enum SessionMode {
  stopwatch,
  timer;

  String get jsonKey => name;

  String get label => switch (this) {
    SessionMode.stopwatch => 'Stopwatch',
    SessionMode.timer => 'Timer',
  };

  static SessionMode fromJson(String? value) => switch (value) {
    'stopwatch' => SessionMode.stopwatch,
    'timer' => SessionMode.timer,
    _ => SessionMode.stopwatch,
  };
}

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.taskName,
    required this.startedAt,
    required this.endedAt,
    this.category = TaskCategory.other,
    this.projectTaskId,
    this.durationMinutes,
    this.status = SessionStatus.completed,
    this.mode = SessionMode.stopwatch,
    this.targetDurationMinutes,
  });

  final String id;
  final String taskName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TaskCategory category;
  final String? projectTaskId;

  /// Stored duration from Supabase (null while session is active).
  /// Falls back to computed value for finished sessions missing this field.
  final int? durationMinutes;
  final SessionStatus status;
  final SessionMode mode;
  final int? targetDurationMinutes;

  Duration get duration {
    if (!isActive && durationMinutes != null) {
      return Duration(minutes: durationMinutes!);
    }
    final DateTime end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  bool get isActive => endedAt == null && (status == SessionStatus.active || status == SessionStatus.paused);

  /// Whether this category counts toward productive time (for analytics).
  bool get isProductive => category.isDeepWork;
}
