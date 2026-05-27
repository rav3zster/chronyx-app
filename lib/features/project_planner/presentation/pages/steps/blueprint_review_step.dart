import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlueprintReviewStep extends ConsumerWidget {
  const BlueprintReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(blueprintWizardProvider);
    final blueprint = wizardState.parsedBlueprint;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (blueprint == null) {
      return Center(
        child: Text(
          'No blueprint parsed yet.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        // ── Header Summary ─────────────────────────────────────────────
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.map_rounded,
                    color: scheme.primary,
                    size: AppSpacing.iconLg,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blueprint.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${blueprint.days.length} days • '
                        '${_totalTasks(blueprint)} tasks',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Day List ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxxl,
            ),
            itemCount: blueprint.days.length,
            itemBuilder: (context, dayIndex) {
              final day = blueprint.days[dayIndex];
              return _DayCard(
                day: day,
                dayIndex: dayIndex,
                onRemoveTask: (taskIndex) {
                  ref
                      .read(blueprintWizardProvider.notifier)
                      .removeTask(dayIndex, taskIndex);
                },
                onEditTaskTitle: (taskIndex, newTitle) {
                  ref
                      .read(blueprintWizardProvider.notifier)
                      .updateTaskTitle(dayIndex, taskIndex, newTitle);
                },
                onEditTodo: (taskIndex, todoIndex, newTodo) {
                  ref
                      .read(blueprintWizardProvider.notifier)
                      .updateTodo(dayIndex, taskIndex, todoIndex, newTodo);
                },
              );
            },
          ),
        ),

        // ── Save Button ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: 'Save Blueprint',
            isLoading: wizardState.isGenerating,
            onPressed: wizardState.isGenerating
                ? null
                : () async {
                    final notifier = ref.read(blueprintWizardProvider.notifier);
                    final projectId = await notifier.saveBlueprint();
                    if (!context.mounted) return;
                    if (projectId != null) {
                      notifier.reset();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Blueprint saved successfully!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).pop();
                    } else {
                      final error = ref
                          .read(blueprintWizardProvider)
                          .errorMessage;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error ?? 'Failed to save blueprint'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            icon: const Icon(
              Icons.save_rounded,
              color: Colors.white,
              size: AppSpacing.iconMd,
            ),
          ),
        ),
      ],
    );
  }

  int _totalTasks(ParsedBlueprint blueprint) {
    return blueprint.days.fold<int>(0, (sum, day) => sum + day.tasks.length);
  }
}

// ── Day Card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.dayIndex,
    required this.onRemoveTask,
    required this.onEditTaskTitle,
    required this.onEditTodo,
  });

  final DayPlan day;
  final int dayIndex;
  final void Function(int taskIndex) onRemoveTask;
  final void Function(int taskIndex, String newTitle) onEditTaskTitle;
  final void Function(int taskIndex, int todoIndex, String newTodo) onEditTodo;

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
            // Day header
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
                    'Day ${day.dayNumber}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    day.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${day.estimatedMinutes} min',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Tasks
            ...List.generate(day.tasks.length, (taskIndex) {
              final task = day.tasks[taskIndex];
              return _TaskTile(
                task: task,
                onRemove: () => onRemoveTask(taskIndex),
                onEditTitle: (t) => onEditTaskTitle(taskIndex, t),
                onEditTodo: (todoIndex, newTodo) =>
                    onEditTodo(taskIndex, todoIndex, newTodo),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Task Tile ─────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onRemove,
    required this.onEditTitle,
    required this.onEditTodo,
  });

  final BlueprintTask task;
  final VoidCallback onRemove;
  final ValueChanged<String> onEditTitle;
  final void Function(int todoIndex, String newTodo) onEditTodo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task header
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showEditDialog(context),
                    child: Text(
                      task.title,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${task.estimatedMinutes}m',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: scheme.error.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            // Todos
            if (task.todos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              ...List.generate(task.todos.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showTodoEditDialog(context, i),
                          child: Text(
                            task.todos[i],
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Task Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onEditTitle(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTodoEditDialog(BuildContext context, int todoIndex) {
    final controller = TextEditingController(text: task.todos[todoIndex]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Todo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Todo step'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onEditTodo(todoIndex, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
