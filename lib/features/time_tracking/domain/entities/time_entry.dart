/// Task categories for productivity analysis.
enum TaskCategory {
  productive,
  learning,
  break_,
  distraction,
  other;

  String get label => switch (this) {
        TaskCategory.productive => 'Productive',
        TaskCategory.learning => 'Learning',
        TaskCategory.break_ => 'Break',
        TaskCategory.distraction => 'Distraction',
        TaskCategory.other => 'Other',
      };

  String get emoji => switch (this) {
        TaskCategory.productive => '🚀',
        TaskCategory.learning => '📚',
        TaskCategory.break_ => '☕',
        TaskCategory.distraction => '🌀',
        TaskCategory.other => '📌',
      };

  /// JSON column value stored in Supabase
  String get jsonKey => switch (this) {
        TaskCategory.productive => 'productive',
        TaskCategory.learning => 'learning',
        TaskCategory.break_ => 'break',
        TaskCategory.distraction => 'distraction',
        TaskCategory.other => 'other',
      };

  static TaskCategory fromJson(String? value) => switch (value) {
        'productive' => TaskCategory.productive,
        'learning' => TaskCategory.learning,
        'break' => TaskCategory.break_,
        'distraction' => TaskCategory.distraction,
        _ => TaskCategory.other,
      };
}

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.taskName,
    required this.startedAt,
    required this.endedAt,
    this.category = TaskCategory.other,
  });

  final String id;
  final String taskName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TaskCategory category;

  Duration get duration {
    final DateTime end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  bool get isActive => endedAt == null;

  /// Whether this category counts toward productive time.
  bool get isProductive =>
      category == TaskCategory.productive || category == TaskCategory.learning;
}
