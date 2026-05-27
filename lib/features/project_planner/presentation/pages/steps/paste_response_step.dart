import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/project_planner/domain/entities/blueprint_parse_exception.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PasteResponseStep extends ConsumerStatefulWidget {
  const PasteResponseStep({super.key});

  @override
  ConsumerState<PasteResponseStep> createState() => _PasteResponseStepState();
}

class _PasteResponseStepState extends ConsumerState<PasteResponseStep> {
  late final TextEditingController _responseController;

  @override
  void initState() {
    super.initState();
    final current = ref.read(blueprintWizardProvider).rawBlueprintResponse;
    _responseController = TextEditingController(text: current ?? '');
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _onValidateAndContinue() {
    final notifier = ref.read(blueprintWizardProvider.notifier);
    notifier.setRawResponse(_responseController.text);
    final success = notifier.parseResponse();
    if (success) {
      notifier.nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(blueprintWizardProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasError = wizardState.errorMessage != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      children: [
        // ── Instructions ─────────────────────────────────────────────────
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.paste_rounded,
                color: scheme.primary,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste AI Response',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Paste the JSON response from your AI tool below. '
                      'The parser will validate and extract the roadmap.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Response Input ───────────────────────────────────────────────
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _responseController,
            maxLines: 12,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontFamily: 'monospace',
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Paste the AI-generated JSON here...',
              hintStyle: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(
                  color: hasError ? scheme.error : scheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(
                  color: hasError ? scheme.error : scheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(
                  color: hasError ? scheme.error : scheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
            onChanged: (_) {
              // Clear error when user edits
              if (hasError) {
                ref
                    .read(blueprintWizardProvider.notifier)
                    .setRawResponse(_responseController.text);
              }
            },
          ),
        ),

        // ── Error Display ────────────────────────────────────────────────
        if (hasError) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorPanel(
            message: wizardState.errorMessage!,
            issues: wizardState.parseWarnings,
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // ── Validate Button ──────────────────────────────────────────────
        PrimaryButton(
          label: 'Validate & Continue',
          onPressed: _responseController.text.trim().isNotEmpty
              ? _onValidateAndContinue
              : null,
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: AppSpacing.iconMd,
          ),
        ),
      ],
    );
  }
}

// ── Error Panel ───────────────────────────────────────────────────────────────

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.issues});

  final String message;
  final List<ParseIssue> issues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...issues
                .take(5)
                .map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          issue.severity == ParseIssueSeverity.error
                              ? Icons.close_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: issue.severity == ParseIssueSeverity.error
                              ? scheme.error
                              : scheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${issue.field}: ${issue.message}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (issues.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '...and ${issues.length - 5} more issues',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
