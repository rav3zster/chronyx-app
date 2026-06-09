import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's tasks across all active projects.
class TodaysRoadmap {
  const TodaysRoadmap({
    required this.tasks,
    required this.projectTitle,
    required this.projectId,
    required this.completedCount,
    required this.totalCount,
  });

  final List<ProjectTask> tasks;
  final String projectTitle;
  final String projectId;
  final int completedCount;
  final int totalCount;
}

/// Provides today's roadmap tasks from the most recent active project.
///
/// "Today" is determined by the day number matching days elapsed since
/// project creation.
final todaysRoadmapProvider = FutureProvider<TodaysRoadmap?>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.hasValue || authState.value == null) return null;

  try {
    final repo = ref.watch(projectRepositoryProvider);
    final projects = await repo.fetchProjects();

    // Find the most recent active project
    final activeProjects = projects
        .where((p) => p.status == ProjectStatus.active)
        .toList();
    if (activeProjects.isEmpty) return null;

    final project = activeProjects.first;
    final tasks = await repo.fetchProjectTasks(project.id);
    if (tasks.isEmpty) return null;

    // Calculate today's day number based on calendar dates
    final createdMidnight = DateTime(project.createdAt.year, project.createdAt.month, project.createdAt.day);
    final nowMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysElapsed = nowMidnight.difference(createdMidnight).inDays + 1;
    final todayDayNumber = daysElapsed.clamp(1, project.durationDays);

    // Get today's tasks
    final todayTasks = tasks
        .where((t) => t.dayNumber == todayDayNumber)
        .toList();

    final completedCount = todayTasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .length;

    return TodaysRoadmap(
      tasks: todayTasks,
      projectTitle: project.title,
      projectId: project.id,
      completedCount: completedCount,
      totalCount: todayTasks.length,
    );
  } catch (_) {
    return null;
  }
});
