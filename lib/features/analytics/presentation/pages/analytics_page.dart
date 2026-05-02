import 'package:chronyx/core/constants/app_spacing.dart';
// strings not required in this file
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/core/widgets/app_card.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
// wrapped route is registered; no direct import needed
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chronyx/core/routing/app_routes.dart';
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
            if (summary == null) {
              return EmptyState(
                icon: Icons.analytics_outlined,
                title: 'No analytics yet',
                subtitle: 'Start tracking time to generate insights',
                ctaLabel: 'Open Time Tracking',
                onCta: () => context.go(AppRoutes.timeTracking),
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView(
                key: const ValueKey('analytics_list'),
                children: <Widget>[
                  AppCard(
                    child: ListTile(
                      title: const Text('Total Today'),
                      subtitle: Text(
                        '${(summary.totalMinutesDaily / 60).toStringAsFixed(1)} hrs',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: ListTile(
                      title: const Text('Top Task'),
                      subtitle: Text(
                        summary.topTasks.isEmpty
                            ? '—'
                            : '${summary.topTasks.first.key} • ${(summary.topTasks.first.value / 60).toStringAsFixed(1)} hrs',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: ListTile(
                      title: const Text('Most Active Day'),
                      subtitle: Text(summary.mostActiveDay),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.wrapped),
                      child: const Text('Open Wrapped'),
                    ),
                  ),
                ],
              ),
            );
          },
          error: (err, _) => ErrorCard(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(analyticsProvider.notifier).refresh(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
