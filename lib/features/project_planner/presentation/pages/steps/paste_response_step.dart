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
    _responseController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _responseController.removeListener(_onTextChanged);
    _responseController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Clear any previous error when the user edits the field.
    final wizardState = ref.read(blueprintWizardProvider);
    if (wizardState.errorMessage != null) {
      ref
          .read(blueprintWizardProvider.notifier)
          .setRawResponse(_responseController.text);
    }
    // Trigger rebuild for live status chip.
    setState(() {});
  }

  void _onValidateAndContinue() {
    final notifier = ref.read(blueprintWizardProvider.notifier);
    notifier.setRawResponse(_responseController.text);
    final success = notifier.parseResponse();
    if (success) {
      notifier.nextStep();
    }
  }

  void _onCleanResponse() {
    final notifier = ref.read(blueprintWizardProvider.notifier);
    final cleaned = notifier.cleanResponse(_responseController.text);
    _responseController.text = cleaned;
    _responseController.selection = TextSelection.collapsed(
      offset: cleaned.length,
    );
    notifier.setRawResponse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(blueprintWizardProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = _responseController.text;
    final hasText = text.trim().isNotEmpty;
    final hasError = wizardState.errorMessage != null;
    final status = _detectStatus(text);

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
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Live status chip + Clean button ──────────────────────────────
        if (hasText)
          Row(
            children: [
              _StatusChip(status: status),
              const Spacer(),
              // "Clean Response" button — strips markdown, extracts JSON
              TextButton.icon(
                onPressed: _onCleanResponse,
                icon: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
                label: Text(
                  'Clean Response',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
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

        // ── Validate Button — always enabled when text exists ────────────
        PrimaryButton(
          label: 'Validate & Continue',
          // Button is enabled whenever there is text — validation happens
          // on click, not by disabling the button.
          onPressed: hasText ? _onValidateAndContinue : null,
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: AppSpacing.iconMd,
          ),
        ),
      ],
    );
  }

  /// Lightweight pre-flight check on the raw text — runs locally without
  /// invoking the full parser. Used only for the live status chip.
  _PasteStatus _detectStatus(String text) {
    if (text.trim().isEmpty) return _PasteStatus.empty;

    final t = text.trim();
    final hasOpenBrace = t.contains('{');
    final hasCloseBrace = t.contains('}');
    final hasDays = t.contains('"days"') || t.contains("'days'");
    final hasTitle = t.contains('"title"') || t.contains("'title'");

    if (!hasOpenBrace) return _PasteStatus.invalid;
    if (!hasCloseBrace) return _PasteStatus.incomplete;
    if (!hasDays) return _PasteStatus.incomplete;
    if (!hasTitle) return _PasteStatus.incomplete;
    return _PasteStatus.ready;
  }
}

// ── Status enum ───────────────────────────────────────────────────────────────

enum _PasteStatus { empty, ready, incomplete, invalid }

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _PasteStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (icon, label, color) = switch (status) {
      _PasteStatus.ready => (
        Icons.check_circle_rounded,
        'Ready to validate',
        const Color(0xFF22D3A6),
      ),
      _PasteStatus.incomplete => (
        Icons.warning_amber_rounded,
        'Looks incomplete',
        const Color(0xFFF59E0B),
      ),
      _PasteStatus.invalid => (
        Icons.cancel_rounded,
        'Invalid format',
        scheme.error,
      ),
      _PasteStatus.empty => (
        Icons.circle_outlined,
        'Waiting for input',
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
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

    // Count recovered tasks from warnings (days with tasks that parsed OK)
    final recoveredDays = issues
        .where(
          (i) =>
              i.severity == ParseIssueSeverity.warning &&
              i.field.startsWith('days['),
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main error message ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _friendlyTitle(message),
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Field-level issues ─────────────────────────────────────────
          if (issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: scheme.error.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: AppSpacing.sm),
            ...issues
                .take(5)
                .map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          issue.severity == ParseIssueSeverity.error
                              ? Icons.close_rounded
                              : Icons.warning_amber_rounded,
                          size: 13,
                          color: issue.severity == ParseIssueSeverity.error
                              ? scheme.error
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${issue.field}: ${issue.message}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (issues.length > 5)
              Text(
                '...and ${issues.length - 5} more issues',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],

          // ── Recovery hint ──────────────────────────────────────────────
          if (recoveredDays > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF22D3A6).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 13,
                    color: Color(0xFF22D3A6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'We recovered $recoveredDays valid day${recoveredDays == 1 ? '' : 's'} from your roadmap. '
                      'Try "Clean Response" to fix the rest.',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF22D3A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Suggestions ────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.sm),
          _SuggestionRow(message: message),
        ],
      ),
    );
  }

  String _friendlyTitle(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('empty')) return 'Empty response';
    if (lower.contains('malformed') || lower.contains('json parse')) {
      return 'Invalid JSON format';
    }
    if (lower.contains('no json') || lower.contains('could not find')) {
      return 'No roadmap found';
    }
    if (lower.contains('days')) return 'Missing roadmap structure';
    if (lower.contains('truncated')) return 'Response appears truncated';
    return "We couldn't understand the AI response";
  }
}

// ── Suggestion row ────────────────────────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final suggestion = _suggest(message);
    if (suggestion == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline_rounded, size: 13, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            suggestion,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  String? _suggest(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('empty')) {
      return 'Make sure you copied the full response from your AI tool.';
    }
    if (lower.contains('malformed') || lower.contains('json parse')) {
      return 'Try the "Clean Response" button — it strips markdown and extracts the JSON automatically.';
    }
    if (lower.contains('no json') || lower.contains('could not find')) {
      return 'The AI may have replied with text instead of JSON. Ask it to "respond with only valid JSON, no explanation."';
    }
    if (lower.contains('days')) {
      return 'The response is missing the "days" array. Ask the AI to regenerate using the exact prompt format.';
    }
    if (lower.contains('truncated')) {
      return 'The response may have been cut off. Ask the AI to continue or regenerate a shorter roadmap.';
    }
    return 'Try the "Clean Response" button, or go back and regenerate the prompt.';
  }
}
