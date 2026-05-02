import 'package:chronyx/core/constants/app_spacing.dart';
// strings not required in this file
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/analytics/presentation/pages/wrapped_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: state.when(
          data: (summary) {
            if (summary == null) return const Center(child: Text('No data'));
            return ListView(
              children: <Widget>[
                Card(
                  child: ListTile(
                    title: const Text('Total Today'),
                    subtitle: Text('${(summary.totalMinutesDaily/60).toStringAsFixed(1)} hrs'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: ListTile(
                    title: const Text('Top Task'),
                    subtitle: Text(summary.topTasks.isEmpty ? '—' : '${summary.topTasks.first.key} • ${(summary.topTasks.first.value/60).toStringAsFixed(1)} hrs'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: ListTile(
                    title: const Text('Most Active Day'),
                    subtitle: Text(summary.mostActiveDay),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WrappedPage())),
                  child: const Text('Open Wrapped'),
                ),
              ],
            );
          },
          error: (err, _) => Center(child: Text(ErrorMessageMapper.fromError(err))),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
