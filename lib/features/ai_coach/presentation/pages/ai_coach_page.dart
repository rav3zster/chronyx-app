import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/page_header.dart';
import 'package:chronyx/core/widgets/state_view.dart';
import 'package:chronyx/features/ai_coach/domain/entities/ai_insight.dart';
import 'package:chronyx/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kPad = 20.0;

class AICoachPage extends ConsumerWidget {
  const AICoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiCoachProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(_kPad, 12, _kPad, 16),
              child: PageHeader(title: 'AI Coach'),
            ),
            Expanded(
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
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        _kPad,
                        0,
                        _kPad,
                        120 + bottomInset,
                      ),
                      itemCount: insights.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _CoachCard(insight: insights[index]),
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
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.insight});
  final AIInsight insight;

  /// Accent + icon for each insight type (info / suggestion / warning).
  (Color, IconData) _meta(ColorScheme scheme) {
    return switch (insight.type) {
      AIInsightType.warning => (scheme.error, Icons.warning_amber_rounded),
      AIInsightType.suggestion => (
        scheme.primary,
        Icons.tips_and_updates_outlined,
      ),
      AIInsightType.info => (
        scheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (accent, icon) = _meta(scheme);
    final typeLabel = insight.type.name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: accent, size: AppSpacing.iconMd),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
