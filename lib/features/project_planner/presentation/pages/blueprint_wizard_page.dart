import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/features/project_planner/presentation/pages/steps/goal_input_step.dart';
import 'package:chronyx/features/project_planner/presentation/pages/steps/prompt_preview_step.dart';
import 'package:chronyx/features/project_planner/presentation/pages/steps/paste_response_step.dart';
import 'package:chronyx/features/project_planner/presentation/pages/steps/blueprint_review_step.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlueprintWizardPage extends ConsumerWidget {
  const BlueprintWizardPage({super.key});

  static const _stepLabels = ['Goal', 'Prompt', 'Paste', 'Review'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(blueprintWizardProvider);

    return PopScope(
      canPop: !wizardState.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(blueprintWizardProvider.notifier).previousStep();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Blueprint Wizard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (wizardState.canGoBack) {
                ref.read(blueprintWizardProvider.notifier).previousStep();
              } else {
                ref.read(blueprintWizardProvider.notifier).reset();
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: ResponsiveCenter(
          maxWidth: Breakpoints.maxContent,
          child: Column(
            children: [
              // ── Step Indicator ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: _StepIndicator(
                  currentStep: wizardState.currentStep,
                  labels: _stepLabels,
                ),
              ),
  
              // ── Step Content ───────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(wizardState.currentStep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    return switch (step) {
      0 => const GoalInputStep(key: ValueKey('goal')),
      1 => const PromptPreviewStep(key: ValueKey('prompt')),
      2 => const PasteResponseStep(key: ValueKey('paste')),
      3 => const BlueprintReviewStep(key: ValueKey('review')),
      _ => const GoalInputStep(key: ValueKey('goal')),
    };
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.labels});

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepBefore = index ~/ 2;
          final isCompleted = stepBefore < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted ? scheme.primary : scheme.outlineVariant,
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final isActive = stepIndex == currentStep;
        final isCompleted = stepIndex < currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive || isCompleted
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                border: Border.all(
                  color: isActive || isCompleted
                      ? scheme.primary
                      : scheme.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: scheme.onPrimary,
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[stepIndex],
              style: textTheme.labelSmall?.copyWith(
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 9,
              ),
            ),
          ],
        );
      }),
    );
  }
}
