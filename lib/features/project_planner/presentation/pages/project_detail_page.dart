import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_health.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that fetches a single project + its tasks.
final projectDetailProvider = FutureProvider.family<_ProjectDetail, String>((
  ref,
  projectId,
) async {
  final repo = ref.watch(projectRepositoryProvider);
  final project = await repo.fetchProject(projectId);
  final tasks = await repo.fetchProjectTasks(projectId);
  return _ProjectDetail(project: project, tasks: tasks);
});

class _ProjectDetail {
  const _ProjectDetail({required this.project, required this.tasks});
  final Project project;
  final List<ProjectTask> tasks;
}

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(projectDetailProvider(projectId));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: AppSpacing.iconXl,
                  color: scheme.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  ErrorMessageMapper.fromError(err),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(projectDetailProvider(projectId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) {
          if (detail.tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: AppSpacing.iconXl,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No tasks yet',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This project has no tasks. It may have been saved without a parsed blueprint.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return _ProjectDetailBody(
            detail: detail,
            onTaskStatusChanged: (taskId, status) async {
              final repo = ref.read(projectRepositoryProvider);
              await repo.updateTaskStatus(taskId, status);
              ref.invalidate(projectDetailProvider(projectId));
            },
            onDeleteTask: (taskId) async {
              final repo = ref.read(projectRepositoryProvider);
              await repo.deleteTask(taskId);
              ref.invalidate(projectDetailProvider(projectId));
            },
          );
        },
      ),
    );
  }
}

class _ProjectDetailBody extends StatelessWidget {
  const _ProjectDetailBody({
    required this.detail,
    required this.onTaskStatusChanged,
    required this.onDeleteTask,
  });

  final _ProjectDetail detail;
  final Future<void> Function(String taskId, ProjectTaskStatus status)
  onTaskStatusChanged;
  final Future<void> Function(String taskId) onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final project = detail.project;
    final tasks = detail.tasks;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final completedCount = tasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .length;
    final totalCount = tasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Compute project health
    final health = ProjectHealth.calculate(
      createdAt: project.createdAt,
      durationDays: project.durationDays,
      completedTasks: completedCount,
      totalTasks: totalCount,
    );

    // Group tasks by day
    final dayMap = <int, List<ProjectTask>>{};
    for (final task in tasks) {
      dayMap.putIfAbsent(task.dayNumber, () => []).add(task);
    }
    final sortedDays = dayMap.keys.toList()..sort();

    return Column(
      children: [
        // ── Progress Header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: GlassCard(
            useBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: scheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completedCount / $totalCount tasks completed',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _healthColor(
                          health.status,
                          scheme,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${health.status.emoji} ${health.status.label}',
                        style: textTheme.labelSmall?.copyWith(
                          color: _healthColor(health.status, scheme),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Task List by Day ───────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxxl,
            ),
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final dayNumber = sortedDays[index];
              final dayTasks = dayMap[dayNumber]!;
              return _DaySection(
                dayNumber: dayNumber,
                tasks: dayTasks,
                onStatusChanged: onTaskStatusChanged,
                onDelete: onDeleteTask,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.dayNumber,
    required this.tasks,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final int dayNumber;
  final List<ProjectTask> tasks;
  final Future<void> Function(String taskId, ProjectTaskStatus status)
  onStatusChanged;
  final Future<void> Function(String taskId) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GlassCard(
        useBlur: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'Day $dayNumber',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.where((t) => t.status == ProjectTaskStatus.completed).length}/${tasks.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...tasks.map(
              (task) => _TaskRow(
                task: task,
                onToggle: () {
                  final newStatus = task.status == ProjectTaskStatus.completed
                      ? ProjectTaskStatus.pending
                      : ProjectTaskStatus.completed;
                  onStatusChanged(task.id, newStatus);
                },
                onDelete: () => onDelete(task.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final ProjectTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = task.status == ProjectTaskStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isCompleted ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isCompleted
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (task.estimatedMinutes != null)
                  Text(
                    '${task.estimatedMinutes} min',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: scheme.error.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

Color _healthColor(ProjectHealthStatus status, ColorScheme scheme) {
  return switch (status) {
    ProjectHealthStatus.ahead => scheme.primary,
    ProjectHealthStatus.onTrack => const Color(0xFF22D3A6),
    ProjectHealthStatus.slightlyBehind => const Color(0xFFF59E0B),
    ProjectHealthStatus.behind => scheme.error,
  };
}
