class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalMinutesDaily,
    required this.totalMinutesWeekly,
    required this.totalMinutesMonthly,
    required this.topTasks,
    required this.peakHour,
    required this.mostActiveDay,
    required this.goalPerformance,
  });

  final int totalMinutesDaily;
  final int totalMinutesWeekly;
  final int totalMinutesMonthly;
  final List<MapEntry<String, int>> topTasks; // taskName -> minutes
  final int peakHour; // 0-23
  final String mostActiveDay; // weekday name
  final Map<String, dynamic> goalPerformance; // summary data
}
