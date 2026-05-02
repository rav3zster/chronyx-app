import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: state.isLoading
            ? null
            : () async {
                await context.push(AppRoutes.goalsCreate);
                ref.read(goalsProvider.notifier).refresh();
              },
        child: const Icon(Icons.add_rounded),
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
              return EmptyState(
                icon: Icons.flag_outlined,
                title: 'No goals yet',
                subtitle: 'Create a goal to stay on track',
                ctaLabel: 'Create Goal',
                onCta: () async {
                  await context.push(AppRoutes.goalsCreate);
                  ref.read(goalsProvider.notifier).refresh();
                },
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView.separated(
                key: ValueKey('goals_list_${items.length}'),
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.xxxl + AppSpacing.lg,
                ),
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
          error: (err, _) => ErrorCard(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(goalsProvider.notifier).refresh(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
