import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chronyx/features/analytics/presentation/pages/analytics_page.dart';
import 'package:chronyx/features/ai_coach/presentation/pages/ai_coach_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
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
            PrimaryButton(
              label: AppStrings.goToTimeTracking,
              onPressed: () => context.go(AppRoutes.timeTracking),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Analytics',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsPage())),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'AI Coach',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AICoachPage())),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: const Text(AppStrings.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
