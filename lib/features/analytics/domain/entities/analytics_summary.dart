class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalMinutesDaily,
    required this.totalMinutesWeekly,
    required this.totalMinutesMonthly,
    required this.topTasks,
    required this.peakHour,
    required this.mostActiveDay,
    required this.goalPerformance,
    required this.productivityScore,
    required this.categoryBreakdown,
    required this.dailyMinutes,
  });

  final int totalMinutesDaily;
  final int totalMinutesWeekly;
  final int totalMinutesMonthly;
  final List<MapEntry<String, int>> topTasks; // taskName -> minutes
  final int peakHour; // 0-23
  final String mostActiveDay; // weekday name
  final Map<String, dynamic> goalPerformance;

  /// 0–100 productivity score based on category distribution
  final double productivityScore;

  /// Minutes tracked per category this week
  final Map<String, int> categoryBreakdown;

  /// Daily minutes for the last 7 days (key = day offset from today, 0 = today)
  final Map<int, int> dailyMinutes;
}
