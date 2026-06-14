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
  paused,
  completed,
  cancelled;

  String get jsonKey => name;

  String get label => switch (this) {
    SessionStatus.active => 'Active',
    SessionStatus.paused => 'Paused',
    SessionStatus.completed => 'Completed',
    SessionStatus.cancelled => 'Cancelled',
  };

  static SessionStatus fromJson(String? value) => switch (value) {
    'active' => SessionStatus.active,
    'paused' => SessionStatus.paused,
    'completed' => SessionStatus.completed,
    'cancelled' => SessionStatus.cancelled,
    _ => SessionStatus.completed,
  };
}

enum SessionMode {
  stopwatch,
  timer,
  pomodoro;

  String get jsonKey => name;

  String get label => switch (this) {
    SessionMode.stopwatch => 'Stopwatch',
    SessionMode.timer => 'Timer',
    SessionMode.pomodoro => 'Pomodoro',
  };

  static SessionMode fromJson(String? value) => switch (value) {
    'stopwatch' => SessionMode.stopwatch,
    'timer' => SessionMode.timer,
    'pomodoro' => SessionMode.pomodoro,
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
  final String taskName;
  final DateTime startedAt;
  final DateTime? endedAt;
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

  Duration get duration {
    if (status == SessionStatus.paused) {
      final DateTime pTime = pausedAt ?? DateTime.now();
      final dur = pTime.difference(startedAt) - Duration(seconds: pausedDurationSeconds);
      return dur.inSeconds >= 0 ? dur : Duration.zero;
    }
    if (endedAt != null) {
      final dur = endedAt!.difference(startedAt) - Duration(seconds: pausedDurationSeconds);
      return dur.inSeconds >= 0 ? dur : Duration.zero;
    }
    // active session
    final dur = DateTime.now().difference(startedAt) - Duration(seconds: pausedDurationSeconds);
    return dur.inSeconds >= 0 ? dur : Duration.zero;
  }

  Duration get remainingTime {
    if ((sessionMode == SessionMode.timer || sessionMode == SessionMode.pomodoro) && targetDurationMinutes != null) {
      final target = Duration(minutes: targetDurationMinutes!);
      final elapsed = duration;
      final rem = target - elapsed;
      return rem.inSeconds >= 0 ? rem : Duration.zero;
    }
    return Duration.zero;
  }

  bool get isActive => status == SessionStatus.active;
  bool get isPaused => status == SessionStatus.paused;
  bool get isOngoing => status == SessionStatus.active || status == SessionStatus.paused;

  /// Whether this category counts toward productive time (for analytics).
  bool get isProductive => category.isDeepWork;
}
