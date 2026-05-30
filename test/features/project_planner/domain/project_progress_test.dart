import 'package:chronyx/features/project_planner/domain/entities/project_progress.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectTask _task({
  required String id,
  required int day,
  required ProjectTaskStatus status,
  DateTime? completedAt,
}) {
  return ProjectTask(
    id: id,
    projectId: 'p1',
    dayNumber: day,
    title: 'Task $id',
    description: '',
    sortOrder: 0,
    status: status,
    createdAt: DateTime(2024, 1, 1),
    completedAt: completedAt,
  );
}

void main() {
  group('ProjectProgress.fromTasks', () {
    test('empty task list yields zeroed progress', () {
      final p = ProjectProgress.fromTasks(const []);
      expect(p.totalTasks, 0);
      expect(p.completionPercentage, 0);
      expect(p.allComplete, false);
      expect(p.currentStreak, 0);
    });

    test('completion percentage is bounded 0..100 and exact', () {
      final tasks = [
        _task(id: '1', day: 1, status: ProjectTaskStatus.completed),
        _task(id: '2', day: 1, status: ProjectTaskStatus.pending),
        _task(id: '3', day: 2, status: ProjectTaskStatus.pending),
        _task(id: '4', day: 2, status: ProjectTaskStatus.pending),
      ];
      final p = ProjectProgress.fromTasks(tasks);
      expect(p.completionPercentage, 25);
      expect(p.completedTasks, 1);
      expect(p.allComplete, false);
    });

    test('allComplete true only when every task done', () {
      final tasks = [
        _task(id: '1', day: 1, status: ProjectTaskStatus.completed),
        _task(id: '2', day: 1, status: ProjectTaskStatus.completed),
      ];
      final p = ProjectProgress.fromTasks(tasks);
      expect(p.allComplete, true);
      expect(p.completionPercentage, 100);
      expect(p.completedDays, 1);
    });

    test('completedDays counts only fully completed days', () {
      final tasks = [
        _task(id: '1', day: 1, status: ProjectTaskStatus.completed),
        _task(id: '2', day: 1, status: ProjectTaskStatus.completed),
        _task(id: '3', day: 2, status: ProjectTaskStatus.completed),
        _task(id: '4', day: 2, status: ProjectTaskStatus.pending),
      ];
      final p = ProjectProgress.fromTasks(tasks);
      expect(p.completedDays, 1);
    });

    test('streak counts consecutive days ending today', () {
      final now = DateTime(2024, 3, 10, 12);
      final tasks = [
        _task(
          id: '1',
          day: 1,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 8, 9),
        ),
        _task(
          id: '2',
          day: 2,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 9, 9),
        ),
        _task(
          id: '3',
          day: 3,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 10, 9),
        ),
      ];
      final p = ProjectProgress.fromTasks(tasks, now: now);
      expect(p.currentStreak, 3);
    });

    test('streak breaks on a missed day', () {
      final now = DateTime(2024, 3, 10, 12);
      final tasks = [
        _task(
          id: '1',
          day: 1,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 7, 9),
        ),
        // gap on the 8th
        _task(
          id: '2',
          day: 2,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 9, 9),
        ),
        _task(
          id: '3',
          day: 3,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 10, 9),
        ),
      ];
      final p = ProjectProgress.fromTasks(tasks, now: now);
      expect(p.currentStreak, 2); // only 9th + 10th
    });

    test('streak is 0 when last activity is older than yesterday', () {
      final now = DateTime(2024, 3, 10, 12);
      final tasks = [
        _task(
          id: '1',
          day: 1,
          status: ProjectTaskStatus.completed,
          completedAt: DateTime(2024, 3, 5, 9),
        ),
      ];
      final p = ProjectProgress.fromTasks(tasks, now: now);
      expect(p.currentStreak, 0);
    });
  });
}
