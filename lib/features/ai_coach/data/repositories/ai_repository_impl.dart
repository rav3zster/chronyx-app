import 'dart:io';

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

      // Productivity insight based on peak hour
      if (summary.peakHour >= 0) {
        insights.add(AIInsight(
          id: 'peak_hour',
          message: 'You are most productive around ${summary.peakHour}:00.',
          type: AIInsightType.info,
          meta: {'peakHour': summary.peakHour},
        ));
      }

      // Top task insight
      if (summary.topTasks.isNotEmpty) {
        final top = summary.topTasks.first;
        final percent = ((top.value / (summary.totalMinutesWeekly == 0 ? 1 : summary.totalMinutesWeekly)) * 100).toStringAsFixed(0);
        insights.add(AIInsight(
          id: 'top_task',
          message: 'You spent $percent% of this week on "${top.key}".',
          type: AIInsightType.info,
          meta: {'task': top.key, 'minutes': top.value},
        ));
      }

      // Goal insights
      for (final g in goals) {
        final rate = g.percentCompleted;
        if (rate >= 100) {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_success',
            message: 'Goal "${g.goal.title}" completed at ${rate.toStringAsFixed(0)}%. Great job!',
            type: AIInsightType.info,
            meta: {'goalId': g.goal.id},
          ));
        } else if (rate >= 50) {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_on_track',
            message: 'Goal "${g.goal.title}" is ${rate.toStringAsFixed(0)}% complete. Keep going!',
            type: AIInsightType.suggestion,
            meta: {'goalId': g.goal.id},
          ));
        } else {
          insights.add(AIInsight(
            id: 'goal_${g.goal.id}_behind',
            message: 'Goal "${g.goal.title}" is only ${rate.toStringAsFixed(0)}% complete. Consider focusing more time.',
            type: AIInsightType.warning,
            meta: {'goalId': g.goal.id},
          ));
        }
      }

      // Session insights
      if (sessions.isNotEmpty) {
        final totalSessionMinutes = sessions.map((s) => s.duration.inMinutes).fold<int>(0, (a, b) => a + b);
        final avg = (totalSessionMinutes / sessions.length).round();
        insights.add(AIInsight(
          id: 'avg_session',
          message: 'You average $avg minutes per session.',
          type: AIInsightType.info,
          meta: {'avgMinutes': avg},
        ));
      }

      // Suggestion: shift work to peak hour
      insights.add(AIInsight(
        id: 'suggest_shift',
        message: 'Consider shifting focused work to your peak hour (${summary.peakHour}:00) to increase productivity.',
        type: AIInsightType.suggestion,
      ));

      return insights;
    } on SocketException {
      throw const NetworkException();
    } catch (_) {
      throw const UnknownException();
    }
  }
}
