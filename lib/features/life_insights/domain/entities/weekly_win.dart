/// A celebratory achievement unlocked in the current window.
class WeeklyWin {
  const WeeklyWin({
    required this.id,
    required this.title,
    required this.detail,
    required this.emoji,
  });

  final String id;
  final String title; // e.g. "5-day streak"
  final String detail; // e.g. "You showed up every weekday."
  final String emoji;
}
