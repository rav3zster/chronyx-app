import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// navigation uses GoRouter; no direct page imports required here

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final timeState = ref.watch(timeEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: authState.when(
          data: (user) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.dashboardGreeting,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Active session preview
                timeState.when(
                  data: (entries) {
                    TimeEntry? active;
                    for (final e in entries) {
                      if (e.isActive) {
                        active = e;
                        break;
                      }
                    }
                    if (active != null) {
                      final activeId = active.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active session', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Card(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                            child: ListTile(
                              title: Text(active.taskName.isEmpty ? 'Unknown' : active.taskName),
                              subtitle: Text('${active.startedAt.toLocal()}'),
                              trailing: OutlinedButton(
                                onPressed: timeState.isLoading ? null : () => ref.read(timeEntriesProvider.notifier).stopSession(sessionId: activeId),
                                child: const Text('Stop'),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    }

                    // No active session — show CTA
                    return EmptyState(
                      icon: Icons.timer,
                      title: 'No active session',
                      subtitle: 'Start tracking time to see insights',
                      ctaLabel: 'Open Time Tracking',
                      onCta: timeState.isLoading ? null : () => context.go(AppRoutes.timeTracking),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => ErrorCard(
                    message: err.toString(),
                    onRetry: () => ref.read(timeEntriesProvider.notifier).refreshEntries(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: AppStrings.goToTimeTracking,
                  onPressed: authState.isLoading ? null : () => context.go(AppRoutes.timeTracking),
                  isLoading: authState.isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Analytics',
                  onPressed: authState.isLoading ? null : () => context.push(AppRoutes.analytics),
                  isLoading: authState.isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'AI Coach',
                  onPressed: authState.isLoading ? null : () => context.push(AppRoutes.aiCoach),
                  isLoading: authState.isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: authState.isLoading ? null : () => ref.read(authProvider.notifier).signOut(),
                  child: const Text(AppStrings.signOut),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorCard(
            message: err.toString(),
            onRetry: () => ref.read(authProvider.notifier).getCurrentUser(),
          ),
        ),
      ),
    );
  }
}
