import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/project_planner/domain/entities/completion_report.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/blueprint_recovery_sheet.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/project_completion_view.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/project_dashboard_view.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/project_detail_state.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/project_smart_actions_sheet.dart';
import 'package:chronyx/features/project_planner/presentation/widgets/project_state_scaffold.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/session_prefill_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider that fetches a single project + its tasks.
final projectDetailProvider = FutureProvider.family<ProjectDetail, String>((
  ref,
  projectId,
) async {
  final repo = ref.watch(projectRepositoryProvider);
  final project = await repo.fetchProject(projectId);
  final tasks = await repo.fetchProjectTasks(projectId);
  return ProjectDetail(project: project, tasks: tasks);
});

class ProjectDetail {
  const ProjectDetail({required this.project, required this.tasks});
  final Project project;
  final List<ProjectTask> tasks;
}

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  bool _busy = false;

  void _refresh() => ref.invalidate(projectDetailProvider(widget.projectId));

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(ErrorMessageMapper.fromError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Recovery ────────────────────────────────────────────────────────────

  Future<void> _restoreBlueprint({required int existingTaskCount}) async {
    final repo = ref.read(projectRepositoryProvider);

    // 0 tasks → restore the full roadmap automatically, no prompt needed.
    if (existingTaskCount == 0) {
      await _run(() async {
        final n = await repo.restoreTasksFromBlueprint(
          widget.projectId,
          replaceAll: true,
        );
        _toast('Restored $n task${n == 1 ? '' : 's'} from your blueprint.');
        _refresh();
      });
      return;
    }

    // Some tasks remain → ask how to merge so we never wipe progress.
    final choice = await showBlueprintRecoverySheet(
      context,
      existingTaskCount: existingTaskCount,
    );
    if (choice == null) return;

    await _run(() async {
      final n = await repo.restoreTasksFromBlueprint(
        widget.projectId,
        replaceAll: choice == RecoveryChoice.replaceAll,
      );
      final verb = choice == RecoveryChoice.replaceAll ? 'Rebuilt' : 'Added';
      _toast('$verb $n task${n == 1 ? '' : 's'}.');
      _refresh();
    });
  }

  Future<void> _deleteProject() async {
    final confirmed = await _confirmDelete();
    if (!confirmed) return;
    await _run(() async {
      await ref.read(projectRepositoryProvider).deleteProject(widget.projectId);
      ref.read(projectsProvider.notifier).refresh();
      if (mounted) context.pop();
    });
  }

  Future<bool> _confirmDelete() async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
          'This removes the project and its tasks. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _regenerate() => context.push(AppRoutes.blueprint);

  /// Start a focus session from Today's Focus: mark the project started if it's
  /// still a draft, pre-fill the tracking screen with today's next task, and
  /// jump to the Track tab.
  void _startSession(Project project) {
    final today = project.currentDayNumber;
    final detail = ref
        .read(projectDetailProvider(widget.projectId))
        .valueOrNull;
    final todayTasks =
        (detail?.tasks ?? const []).where((t) => t.dayNumber == today).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final nextTask = todayTasks
        .where((t) => t.status != ProjectTaskStatus.completed)
        .firstOrNull;

    ref.read(sessionPrefillProvider.notifier).state = SessionPrefill(
      taskName: nextTask?.title ?? project.title,
      category: TaskCategory.productive,
      projectId: project.id,
      projectTaskId: nextTask?.id,
    );

    // Fire-and-forget: draft → active the moment work begins.
    if (project.status == ProjectStatus.draft) {
      ref
          .read(projectLifecycleControllerProvider)
          .markStartedIfDraft(project)
          .then((_) {
            if (mounted) {
              ref.read(projectsProvider.notifier).refresh();
              _refresh();
            }
          });
    }

    context.go(AppRoutes.timeTracking);
  }

  Future<void> _openSmartActions(Project project) async {
    final action = await showProjectSmartActions(
      context,
      status: project.status,
    );
    if (action == null) return;
    final repo = ref.read(projectRepositoryProvider);

    switch (action) {
      case SmartAction.edit:
      case SmartAction.regenerateRemaining:
      case SmartAction.duplicate:
        // These route into the wizard flow (Phase 6 wires full behavior).
        _regenerate();
      case SmartAction.pause:
        await _run(() async {
          await repo.updateProjectStatus(project.id, ProjectStatus.paused);
          ref.read(projectsProvider.notifier).refresh();
          _refresh();
          _toast('Blueprint paused.');
        });
      case SmartAction.resume:
        await _run(() async {
          await repo.updateProjectStatus(project.id, ProjectStatus.active);
          ref.read(projectsProvider.notifier).refresh();
          _refresh();
          _toast('Blueprint resumed.');
        });
      case SmartAction.archive:
        await _run(() async {
          await repo.updateProjectStatus(project.id, ProjectStatus.archived);
          ref.read(projectsProvider.notifier).refresh();
          _refresh();
          _toast('Blueprint archived.');
        });
      case SmartAction.delete:
        await _deleteProject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(projectDetailProvider(widget.projectId));
    final project = detailAsync.valueOrNull?.project;
    final showActions =
        project != null &&
        (project.status == ProjectStatus.active ||
            project.status == ProjectStatus.paused ||
            project.status == ProjectStatus.draft);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (showActions)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => _openSmartActions(project),
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (err, _) => _ErrorState(
          message: ErrorMessageMapper.fromError(err),
          onRetry: _refresh,
          onBack: () => context.pop(),
        ),
        data: (detail) => _buildForState(detail),
      ),
    );
  }

  Widget _buildForState(ProjectDetail detail) {
    final kind = resolveProjectDetailView(
      status: detail.project.status,
      hasTasks: detail.tasks.isNotEmpty,
      hasBlueprint: detail.project.hasBlueprint,
    );

    switch (kind) {
      case ProjectDetailViewKind.dashboard:
        return ProjectDashboardView(
          project: detail.project,
          tasks: detail.tasks,
          analytics: ref.watch(analyticsProvider).valueOrNull,
          onToggleTask: (task) => _run(() async {
            await ref
                .read(projectLifecycleControllerProvider)
                .toggleTask(
                  project: detail.project,
                  tasks: detail.tasks,
                  task: task,
                );
            ref.read(projectsProvider.notifier).refresh();
            _refresh();
          }),
          onStartSession: () => _startSession(detail.project),
          onRegenerateDay: _regenerate,
        );

      case ProjectDetailViewKind.completed:
        return ProjectCompletionView(
          project: detail.project,
          report: CompletionReport.from(
            project: detail.project,
            tasks: detail.tasks,
          ),
          onCreateNew: _regenerate,
          onRegenerateSimilar: _regenerate,
          onDuplicate: _regenerate,
          onViewAnalytics: () => context.go(AppRoutes.analytics),
          onArchive: () => _run(() async {
            await ref
                .read(projectRepositoryProvider)
                .updateProjectStatus(detail.project.id, ProjectStatus.archived);
            ref.read(projectsProvider.notifier).refresh();
            _refresh();
            _toast('Blueprint archived.');
          }),
        );

      case ProjectDetailViewKind.archived:
        return ProjectStateScaffold(
          icon: Icons.inventory_2_outlined,
          eyebrow: 'Archived',
          title: detail.project.title,
          message:
              'This blueprint is archived and read-only. Duplicate it to '
              'start fresh, or delete it permanently.',
          actions: [
            ProjectStateAction(
              label: 'Delete permanently',
              icon: Icons.delete_forever_outlined,
              kind: ProjectActionKind.destructive,
              loading: _busy,
              onTap: _deleteProject,
            ),
          ],
        );

      case ProjectDetailViewKind.noTasksRemaining:
        return ProjectStateScaffold(
          icon: Icons.restore_rounded,
          eyebrow: 'Recoverable',
          title: 'No tasks remaining',
          message:
              'Your roadmap tasks are gone, but your blueprint is safe. '
              'Restore it to pick up where you left off.',
          actions: [
            ProjectStateAction(
              label: 'Restore from blueprint',
              icon: Icons.auto_fix_high_rounded,
              kind: ProjectActionKind.primary,
              loading: _busy,
              onTap: () =>
                  _restoreBlueprint(existingTaskCount: detail.tasks.length),
            ),
            ProjectStateAction(
              label: 'Regenerate tasks',
              icon: Icons.refresh_rounded,
              onTap: _regenerate,
            ),
            ProjectStateAction(
              label: 'Delete project',
              icon: Icons.delete_outline_rounded,
              kind: ProjectActionKind.destructive,
              loading: _busy,
              onTap: _deleteProject,
            ),
          ],
        );

      case ProjectDetailViewKind.blueprintMissing:
        return ProjectStateScaffold(
          icon: Icons.broken_image_outlined,
          eyebrow: 'Needs attention',
          title: 'Blueprint data missing',
          message:
              "This project doesn't have a saved blueprint to restore from. "
              'Generate a new one, or remove the project.',
          actions: [
            ProjectStateAction(
              label: 'Regenerate Blueprint',
              icon: Icons.auto_awesome_rounded,
              kind: ProjectActionKind.primary,
              onTap: _regenerate,
            ),
            ProjectStateAction(
              label: 'Delete project',
              icon: Icons.delete_outline_rounded,
              kind: ProjectActionKind.destructive,
              loading: _busy,
              onTap: _deleteProject,
            ),
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error + skeleton states (never blank)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ProjectStateScaffold(
      icon: Icons.cloud_off_rounded,
      eyebrow: "Couldn't load",
      title: 'Something went wrong',
      message: message,
      actions: [
        ProjectStateAction(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          kind: ProjectActionKind.primary,
          onTap: onRetry,
        ),
        ProjectStateAction(
          label: 'Go back',
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double h, [double? w]) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(28, 220),
          const SizedBox(height: 20),
          bar(120),
          const SizedBox(height: 16),
          bar(80),
          const SizedBox(height: 12),
          bar(80),
        ],
      ),
    );
  }
}
