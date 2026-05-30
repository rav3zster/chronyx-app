/// A real 0–100 momentum score for a project, with a human label.
///
/// Blends four cheap signals — no ML:
///  - consistency: active days / window days
///  - recent activity: minutes tracked this week (capped)
///  - completion velocity: tasks completed per active day vs expected pace
///  - trend: recent half vs earlier half of the week
class MomentumScore {
  const MomentumScore({required this.score, required this.label});

  final int score; // 0..100
  final String label;

  factory MomentumScore.compute({
    required int activeDaysThisWeek, // 0..7
    required int minutesThisWeek,
    required int completedTasks,
    required int totalTasks,
    required double recentVsEarlierRatio, // >1 improving, <1 slipping
  }) {
    // Consistency (0..40): showing up most days.
    final consistency = (activeDaysThisWeek / 7).clamp(0.0, 1.0) * 40;

    // Effort (0..25): minutes this week, saturating around 5h.
    final effort = (minutesThisWeek / 300).clamp(0.0, 1.0) * 25;

    // Progress (0..20): how far through the roadmap.
    final progress =
        (totalTasks == 0 ? 0.0 : completedTasks / totalTasks).clamp(0.0, 1.0) *
        20;

    // Trend (0..15): improving vs easing.
    final trend = (((recentVsEarlierRatio - 1).clamp(-1.0, 1.0)) + 1) / 2 * 15;

    final raw = (consistency + effort + progress + trend).round().clamp(0, 100);
    return MomentumScore(score: raw, label: _labelFor(raw));
  }

  static String _labelFor(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 65) return 'Strong';
    if (score >= 45) return 'Slipping';
    return 'Falling Behind';
  }
}
