import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/core/widgets/state_view.dart';
import 'package:chronyx/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AICoachPage extends ConsumerWidget {
  const AICoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiCoachProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach'),
        actions: const [
          SettingsIconButton(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: state.when(
          data: (insights) {
            if (insights.isEmpty) {
              return StateView.empty(
                icon: Icons.psychology_outlined,
                title: 'Your coach is listening',
                message:
                    'Track a few sessions and your coach will surface insights here.',
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView.separated(
                key: ValueKey('ai_list_${insights.length}'),
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: insights.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final insight = insights[index];
                  final typeLabel = insight.type.toString().split('.').last;

                  return GlassCard(
                    useBlur: false,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            color: scheme.primary,
                            size: AppSpacing.iconMd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.message,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => StateView.error(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(aiCoachProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}
