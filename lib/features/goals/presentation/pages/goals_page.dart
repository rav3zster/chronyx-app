import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'create_goal_page.dart';
import 'goal_detail_page.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGoalPage()));
          ref.read(goalsProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: state.when(
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No goals yet'));
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final g = items[index];
                return GoalCard(
                  progress: g,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalDetailPage(progress: g))),
                );
              },
            );
          },
          error: (err, _) => Center(child: Text(ErrorMessageMapper.fromError(err))),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
