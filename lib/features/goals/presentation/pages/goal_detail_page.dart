import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: state.when(
          data: (items) {
            final matches = items.where((g) => g.goal.id == goalId).toList();
            if (matches.isEmpty) return const Center(child: Text('Goal not found'));
            final p = matches.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(p.goal.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Text(p.goal.description),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(value: p.percentCompleted / 100),
                const SizedBox(height: AppSpacing.sm),
                Text('Completed ${p.daysCompleted} / ${p.totalDays} days'),
                const SizedBox(height: AppSpacing.sm),
                Text('Streak: ${p.currentStreak}'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
        ),
      ),
    );
  }
}
