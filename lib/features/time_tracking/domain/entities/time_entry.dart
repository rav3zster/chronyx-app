class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.taskName,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String taskName;
  final DateTime startedAt;
  final DateTime? endedAt;

  Duration get duration {
    final DateTime end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  bool get isActive => endedAt == null;
}
