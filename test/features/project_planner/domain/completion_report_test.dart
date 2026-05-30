import 'package:chronyx/features/project_planner/domain/entities/completion_report.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:flutter_test/flutter_test.dart';

Project _project({
  int duration = 30,
  int actualMinutes = 0,
  int streak = 0,
  DateTime? started,
  DateTime? completed,
}) {
  final created = DateTime(2024, 1, 1);
  return Project(
    id: 'p1',
    userId: 'u1',
    title: 'Flutter Mastery',
    goalDescription: 'Learn Flutter',
    template: 'custom',
    durationDays: duration,
    difficulty: ProjectDifficulty.medium,
    dailyTimeMinutes: 60,
    status: ProjectStatus.completed,
    createdAt: created,
    updatedAt: created,
    startedAt: started ?? created,
    completedAt: completed,
    actualMinutesSpent: actualMinutes,
    streakDays: streak,
  );
}

ProjectTask _task({
  required int day,
  required ProjectTaskStatus status,
  int minutes = 30,
  DateTime? completedAt,
}) {
  return ProjectTask(
    id: 'd$day',
    projectId: 'p1',
    dayNumber: day,
    title: 'Task $day',
    description: '',
    sortOrder: 0,
    estimatedMinutes: minutes,
    status: status,
    createdAt: DateTime(2024, 1, 1),
    completedAt: completedAt,
  );
}

void main() {
  group('CompletionReport.from', () {
    test('uses persisted actual minutes when present', () {
      final report = CompletionReport.from(
        project: _project(actualMinutes: 600),
        tasks: [_task(day: 1, status: ProjectTaskStatus.completed)],
      );
      expect(report.focusHours, 10.0);
    });

    test('falls back to estimated minutes when no actual minutes', () {
      final report = CompletionReport.from(
        project: _project(actualMinutes: 0),
        tasks: [
          _task(day: 1, status: ProjectTaskStatus.completed, minutes: 60),
          _task(day: 2, status: ProjectTaskStatus.completed, minutes: 60),
        ],
      );
      expect(report.focusHours, 2.0);
    });

    test('always produces at least one insight', () {
      final report = CompletionReport.from(
        project: _project(),
        tasks: [_task(day: 1, status: ProjectTaskStatus.completed)],
      );
      expect(report.insights, isNotEmpty);
    });

    test('streak insight appears when streak >= 3', () {
      final report = CompletionReport.from(
        project: _project(streak: 14),
        tasks: [_task(day: 1, status: ProjectTaskStatus.completed)],
      );
      expect(report.insights.any((i) => i.contains('14-day streak')), isTrue);
    });

    test('timeline empty when too few completions', () {
      final report = CompletionReport.from(
        project: _project(),
        tasks: [_task(day: 1, status: ProjectTaskStatus.completed)],
      );
      expect(report.timeline, isEmpty);
    });

    test('timeline has beats across multiple weeks', () {
      final tasks = [
        for (var d = 1; d <= 14; d++)
          _task(
            day: d,
            status: ProjectTaskStatus.completed,
            completedAt: DateTime(2024, 1, d),
          ),
      ];
      final report = CompletionReport.from(project: _project(), tasks: tasks);
      expect(report.timeline.length, greaterThanOrEqualTo(2));
      expect(report.timeline.last.label, 'Finished strong');
    });
  });
}
