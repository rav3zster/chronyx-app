import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:flutter/material.dart';
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
            if (insights.isEmpty) return const Center(child: Text('No insights yet'));
            return ListView.separated(
              itemCount: insights.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final insight = insights[index];
                return Card(
                  child: ListTile(
                    title: Text(insight.message),
                    subtitle: Text(insight.type.toString().split('.').last),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(ErrorMessageMapper.fromError(err))),
        ),
      ),
    );
  }
}
