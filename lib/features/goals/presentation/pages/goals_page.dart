import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/core/widgets/state_view.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: const [
          SettingsIconButton(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      // Lift FAB above the floating bottom nav (height 64 + 12 margin + safe area).
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 76 + MediaQuery.of(context).padding.bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: state.isLoading
              ? null
              : () async {
                  await context.push(AppRoutes.goalsCreate);
                  ref.read(goalsProvider.notifier).refresh();
                },
          icon: const Icon(Icons.add_rounded),
          label: const Text('New goal'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: state.when(
          data: (items) {
            if (items.isEmpty) {
              return StateView.empty(
                icon: Icons.flag_outlined,
                title: 'No goals yet',
                message:
                    'Create a goal to build a streak and stay accountable.',
                actionLabel: 'Create goal',
                onAction: () async {
                  await context.push(AppRoutes.goalsCreate);
                  ref.read(goalsProvider.notifier).refresh();
                },
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView.separated(
                key: ValueKey('goals_list_${items.length}'),
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final g = items[index];
                  return GoalCard(
                    progress: g,
                    onTap: () => context.push('/goals/${g.goal.id}'),
                  );
                },
              ),
            );
          },
          error: (err, _) => StateView.error(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(goalsProvider.notifier).refresh(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
