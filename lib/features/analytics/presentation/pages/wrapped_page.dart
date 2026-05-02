import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WrappedPage extends ConsumerWidget {
  const WrappedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wrapped')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: state.when(
          data: (s) {
            if (s == null) return const Center(child: Text('No data'));
            final topTask = s.topTasks.isNotEmpty ? s.topTasks.first.key : '—';
            final totalWeekHrs = (s.totalMinutesWeekly / 60).toStringAsFixed(1);
            final insight = 'You spent $totalWeekHrs hrs this week. Top task: $topTask.';
            return ListView(
              children: <Widget>[
                Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(insight))),
                const SizedBox(height: AppSpacing.sm),
                Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('Peak hour: ${s.peakHour}:00'))),
                const SizedBox(height: AppSpacing.sm),
                Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('Goal success rate: ${s.goalPerformance['successRate'].toStringAsFixed(0)}%'))),
              ],
            );
          },
          error: (err, _) => Center(child: Text(err.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
