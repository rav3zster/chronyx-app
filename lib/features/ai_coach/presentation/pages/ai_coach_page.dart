import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:chronyx/core/widgets/app_card.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AICoachPage extends ConsumerWidget {
  const AICoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiCoachProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Coach')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: state.when(
          data: (insights) {
            if (insights.isEmpty) return const EmptyState(title: 'No insights yet', subtitle: 'Check back after more activity');
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView.separated(
                key: ValueKey('ai_list_${insights.length}'),
                itemCount: insights.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final insight = insights[index];
                  return AppCard(
                    child: ListTile(
                      title: Text(insight.message, style: Theme.of(context).textTheme.bodyLarge),
                      subtitle: Text(insight.type.toString().split('.').last),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorCard(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(aiCoachProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}
