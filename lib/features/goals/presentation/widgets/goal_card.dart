import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:flutter/material.dart';
import 'package:chronyx/core/widgets/app_card.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({required this.progress, required this.onTap, super.key});

  final GoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        title: Text(progress.goal.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${progress.percentCompleted.toStringAsFixed(0)}% • 🔥 ${progress.currentStreak}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
