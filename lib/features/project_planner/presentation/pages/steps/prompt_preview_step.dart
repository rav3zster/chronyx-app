import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/core/widgets/secondary_button.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptPreviewStep extends ConsumerWidget {
  const PromptPreviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(blueprintWizardProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prompt = wizardState.generatedPrompt ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      children: [
        // ── Helper Text ──────────────────────────────────────────────────
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: scheme.primary,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Paste this into ChatGPT, Gemini, Kimi, or your preferred AI.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Configuration Summary ────────────────────────────────────────
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuration',
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ConfigRow(
                label: 'Template',
                value: wizardState.selectedTemplate.label,
              ),
              _ConfigRow(
                label: 'Duration',
                value: '${wizardState.durationDays} days',
              ),
              _ConfigRow(
                label: 'Difficulty',
                value: wizardState.difficulty.label,
              ),
              _ConfigRow(
                label: 'Daily Time',
                value: _formatMinutes(wizardState.dailyTimeMinutes),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Prompt Text ──────────────────────────────────────────────────
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    color: scheme.primary,
                    size: AppSpacing.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Generated Prompt',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: SelectableText(
                    prompt,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Actions ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Copy',
                icon: Icon(
                  Icons.copy_rounded,
                  color: scheme.onSurface,
                  size: AppSpacing.iconMd,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: prompt));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prompt copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SecondaryButton(
                label: 'Regenerate',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: scheme.onSurface,
                  size: AppSpacing.iconMd,
                ),
                onPressed: () {
                  ref.read(blueprintWizardProvider.notifier).regeneratePrompt();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prompt regenerated'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        PrimaryButton(
          label: 'I Have the Response',
          onPressed: () {
            ref.read(blueprintWizardProvider.notifier).nextStep();
          },
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: AppSpacing.iconMd,
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '$hours hr${hours > 1 ? 's' : ''}';
    return '${hours}h ${remaining}m';
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
