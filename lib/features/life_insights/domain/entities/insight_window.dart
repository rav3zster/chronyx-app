/// The time window the user is examining their life through.
enum InsightWindow {
  today,
  week,
  month,
  year;

  String get label => switch (this) {
    InsightWindow.today => 'Today',
    InsightWindow.week => 'Week',
    InsightWindow.month => 'Month',
    InsightWindow.year => 'Year',
  };

  /// Number of days this window covers (used for "tracked X over Y days").
  int get days => switch (this) {
    InsightWindow.today => 1,
    InsightWindow.week => 7,
    InsightWindow.month => 30,
    InsightWindow.year => 365,
  };
}
