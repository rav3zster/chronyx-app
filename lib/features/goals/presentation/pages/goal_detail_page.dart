import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:flutter/material.dart';

class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({required this.progress, super.key});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Scaffold(
      appBar: AppBar(title: Text(p.goal.title)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(p.goal.description),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: p.percentCompleted / 100),
            const SizedBox(height: AppSpacing.sm),
            Text('Completed ${p.daysCompleted} / ${p.totalDays} days'),
            const SizedBox(height: AppSpacing.sm),
            Text('Streak: ${p.currentStreak}'),
          ],
        ),
      ),
    );
  }
}
