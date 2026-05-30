import 'package:chronyx/features/project_planner/domain/entities/momentum_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MomentumScore.compute', () {
    test('score is always within 0..100', () {
      for (final active in [0, 3, 7]) {
        for (final mins in [0, 150, 600, 5000]) {
          for (final ratio in [0.0, 0.5, 1.0, 3.0]) {
            final m = MomentumScore.compute(
              activeDaysThisWeek: active,
              minutesThisWeek: mins,
              completedTasks: 5,
              totalTasks: 10,
              recentVsEarlierRatio: ratio,
            );
            expect(m.score, inInclusiveRange(0, 100));
          }
        }
      }
    });

    test('strong, consistent work scores high', () {
      final m = MomentumScore.compute(
        activeDaysThisWeek: 7,
        minutesThisWeek: 400,
        completedTasks: 9,
        totalTasks: 10,
        recentVsEarlierRatio: 1.4,
      );
      expect(m.score, greaterThanOrEqualTo(85));
      expect(m.label, 'Excellent');
    });

    test('no activity scores low with falling-behind label', () {
      final m = MomentumScore.compute(
        activeDaysThisWeek: 0,
        minutesThisWeek: 0,
        completedTasks: 0,
        totalTasks: 10,
        recentVsEarlierRatio: 1.0,
      );
      expect(m.score, lessThan(45));
      expect(m.label, 'Falling Behind');
    });

    test('label thresholds are ordered', () {
      final excellent = MomentumScore.compute(
        activeDaysThisWeek: 7,
        minutesThisWeek: 600,
        completedTasks: 10,
        totalTasks: 10,
        recentVsEarlierRatio: 2.0,
      );
      final mid = MomentumScore.compute(
        activeDaysThisWeek: 4,
        minutesThisWeek: 150,
        completedTasks: 4,
        totalTasks: 10,
        recentVsEarlierRatio: 1.0,
      );
      expect(excellent.score, greaterThan(mid.score));
    });
  });
}
