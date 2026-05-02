import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/ai_coach/domain/entities/ai_insight.dart';
import 'package:chronyx/features/ai_coach/domain/repositories/ai_repository.dart';
import 'package:chronyx/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';

class AIRepositoryImpl implements AIRepository {
  AIRepositoryImpl(this._analyticsRepo, this._goalsRepo, this._timeRepo);

  final AnalyticsRepository _analyticsRepo;
  final GoalsRepository _goalsRepo;
  final TimeTrackingRepository _timeRepo;

  @override
  Future<List<AIInsight>> generateInsights() async {
    try {
      final summary = await _analyticsRepo.fetchSummary();
      final goals = await _goalsRepo.fetchGoalsWithProgress();
      final sessions = await _timeRepo.fetchTimeEntries();

      final List<AIInsight> insights = [];

      // ── Productivity score ─────────────────────────────────────────────
      final score = summary.productivityScore;
      if (score >= 70) {
        insights.add(AIInsight(
          id: 'prod_score_high',
          message:
              '🚀 Your productivity score this week is ${score.toStringAsFixed(0)}%! You\'re crushing it.',
          type: AIInsightType.info,
          meta: {'score': score},
        ));
      } else if (score >= 40) {
        insights.add(AIInsight(
          id: 'prod_score_mid',
          message:
              '📊 Productivity score: ${score.toStringAsFixed(0)}%. Good progress — try replacing one distraction session with a productive one.',
          type: AIInsightType.suggestion,
          meta: {'score': score},
        ));
      } else if (sessions.isNotEmpty) {
        insights.add(AIInsight(
          id: 'prod_score_low',
          message:
              '⚠️ Productivity score: ${score.toStringAsFixed(0)}%. Most of your tracked time is not in "Productive" or "Learning" categories.',
          type: AIInsightType.warning,
          meta: {'score': score},
        ));
      }

      // ── Distraction warning ────────────────────────────────────────────
      final distractionMins = summary.categoryBreakdown['distraction'] ?? 0;
      final totalWeekly = summary.totalMinutesWeekly;
      if (totalWeekly > 0 && distractionMins / totalWeekly > 0.25) {
        final pct = (distractionMins / totalWeekly * 100).toStringAsFixed(0);
        insights.add(AIInsight(
          id: 'distraction_warning',
          message:
              '🌀 $pct% of your tracked time this week was tagged as Distraction. Consider using Focus mode to stay on track.',
          type: AIInsightType.warning,
          meta: {'distractionMins': distractionMins},
        ));
      }

      // ── Break balance ──────────────────────────────────────────────────
      final breakMins = summary.categoryBreakdown['break'] ?? 0;
      if (totalWeekly > 60 && breakMins / totalWeekly < 0.08) {
        insights.add(AIInsight(
          id: 'break_suggestion',
          message:
              '☕ You\'re barely taking breaks — only ${breakMins}m this week. Short breaks improve focus. Try the 25/5 Pomodoro rhythm.',
          type: AIInsightType.suggestion,
        ));
      }

      // ── Peak hour ─────────────────────────────────────────────────────
      final peak = summary.peakHour;
      insights.add(AIInsight(
        id: 'peak_hour',
        message:
            '⏰ Your most productive hour is ${_formatHour(peak)}. Schedule your hardest tasks during this time.',
        type: AIInsightType.info,
        meta: {'peakHour': peak},
      ));

      // ── Top task ──────────────────────────────────────────────────────
      if (summary.topTasks.isNotEmpty) {
        final top = summary.topTasks.first;
        final hrs = (top.value / 60).toStringAsFixed(1);
        insights.add(AIInsight(
          id: 'top_task',
          message:
              '📌 You spent ${hrs}h on "${top.key}" this week — your top task.',
          type: AIInsightType.info,
          meta: {'task': top.key, 'minutes': top.value},
        ));
      }

      // ── Goals insights ────────────────────────────────────────────────
      for (final g in goals) {
        final rate = g.percentCompleted;
        if (rate >= 100) {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_success',
            message:
                '🏆 Goal "${g.goal.title}" completed at ${rate.toStringAsFixed(0)}%! Great discipline.',
            type: AIInsightType.info,
            meta: {'goalId': g.goal.id},
          ));
        } else if (rate >= 60) {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_on_track',
            message:
                '✅ "${g.goal.title}" is ${rate.toStringAsFixed(0)}% complete with a ${g.currentStreak}-day streak. Stay consistent!',
            type: AIInsightType.suggestion,
            meta: {'goalId': g.goal.id},
          ));
        } else if (rate > 0) {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_behind',
            message:
                '📉 "${g.goal.title}" is only ${rate.toStringAsFixed(0)}% complete. ${g.goal.dailyTargetMinutes}min/day will get you back on track.',
            type: AIInsightType.warning,
            meta: {'goalId': g.goal.id},
          ));
        }
      }

      // ── Average session length ─────────────────────────────────────────
      final completedSessions = sessions.where((s) => !s.isActive).toList();
      if (completedSessions.isNotEmpty) {
        final totalMins = completedSessions
            .map((s) => s.duration.inMinutes)
            .fold<int>(0, (a, b) => a + b);
        final avg = (totalMins / completedSessions.length).round();
        final tip = avg < 20
            ? 'Consider longer focus blocks for deeper work.'
            : avg > 90
                ? 'Very long sessions! Make sure to take breaks.'
                : 'Great session length for focused work.';
        insights.add(AIInsight(
          id: 'avg_session',
          message: '⌛ Average session: ${avg}min. $tip',
          type: AIInsightType.info,
          meta: {'avgMinutes': avg},
        ));
      }

      // ── No data yet ────────────────────────────────────────────────────
      if (sessions.isEmpty) {
        insights.add(AIInsight(
          id: 'no_data',
          message:
              '👋 Start tracking time to unlock personalized insights. Use the Time Tracking tab to begin your first session.',
          type: AIInsightType.info,
        ));
      }

      return insights;
    } on Exception {
      throw const UnknownException();
    }
  }

  String _formatHour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $suffix';
  }
}
