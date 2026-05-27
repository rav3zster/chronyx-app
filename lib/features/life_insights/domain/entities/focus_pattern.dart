/// Time-of-day buckets for the daily timeline visualization.
///
/// Named [LifePeriod] (not `DayPeriod`) to avoid collision with
/// Flutter Material's built-in `DayPeriod` enum (AM/PM).
enum LifePeriod {
  morning, // 5–12
  afternoon, // 12–17
  evening, // 17–21
  night; // 21–5

  String get label => switch (this) {
    LifePeriod.morning => 'Morning',
    LifePeriod.afternoon => 'Afternoon',
    LifePeriod.evening => 'Evening',
    LifePeriod.night => 'Night',
  };

  String get range => switch (this) {
    LifePeriod.morning => '5 AM – 12 PM',
    LifePeriod.afternoon => '12 PM – 5 PM',
    LifePeriod.evening => '5 PM – 9 PM',
    LifePeriod.night => '9 PM – 5 AM',
  };

  static LifePeriod fromHour(int hour) {
    if (hour >= 5 && hour < 12) return LifePeriod.morning;
    if (hour >= 12 && hour < 17) return LifePeriod.afternoon;
    if (hour >= 17 && hour < 21) return LifePeriod.evening;
    return LifePeriod.night;
  }
}

/// User's productivity rhythm across periods of the day.
class FocusPattern {
  const FocusPattern({
    required this.minutesByPeriod,
    required this.peakPeriod,
    required this.peakHour,
    required this.averageSessionMinutes,
  });

  /// Minutes tracked in each period over the analysis window.
  final Map<LifePeriod, int> minutesByPeriod;
  final LifePeriod peakPeriod;
  final int peakHour; // 0–23
  final int averageSessionMinutes;

  int get totalMinutes => minutesByPeriod.values.fold(0, (a, b) => a + b);

  /// Ratio (0.0–1.0) for a given period.
  double ratioFor(LifePeriod period) {
    final total = totalMinutes;
    if (total == 0) return 0;
    return (minutesByPeriod[period] ?? 0) / total;
  }
}
