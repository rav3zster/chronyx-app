import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/input_field.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalInputStep extends ConsumerStatefulWidget {
  const GoalInputStep({super.key});

  @override
  ConsumerState<GoalInputStep> createState() => _GoalInputStepState();
}

class _GoalInputStepState extends ConsumerState<GoalInputStep> {
  late final TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    final current = ref.read(blueprintWizardProvider).goalDescription;
    _goalController = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _onNext() {
    final notifier = ref.read(blueprintWizardProvider.notifier);
    notifier.setGoalDescription(_goalController.text);
    notifier.generatePrompt();
    notifier.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(blueprintWizardProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      children: [
        // ── Goal Description ─────────────────────────────────────────────
        _SectionLabel(label: 'Your Goal'),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InputField(
            controller: _goalController,
            label: 'What do you want to achieve?',
            hint: 'e.g. Learn Flutter in 30 days, Build a SaaS MVP...',
            maxLines: 3,
            onChanged: (v) => ref
                .read(blueprintWizardProvider.notifier)
                .setGoalDescription(v),
            prefixIcon: Icon(
              Icons.lightbulb_outline_rounded,
              color: scheme.onSurfaceVariant,
              size: AppSpacing.iconMd,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Template Selection ───────────────────────────────────────────
        _SectionLabel(label: 'Template'),
        const SizedBox(height: AppSpacing.sm),
        _TemplateGrid(
          selected: wizardState.selectedTemplate,
          onSelected: (t) {
            ref.read(blueprintWizardProvider.notifier).setTemplate(t);
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Duration ─────────────────────────────────────────────────────
        _SectionLabel(label: 'Duration'),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: scheme.primary,
                    size: AppSpacing.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${wizardState.durationDays} days',
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: wizardState.durationDays.toDouble(),
                min: 7,
                max: 365,
                divisions: 358,
                label: '${wizardState.durationDays} days',
                onChanged: (v) => ref
                    .read(blueprintWizardProvider.notifier)
                    .setDuration(v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '7 days',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '365 days',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Difficulty ───────────────────────────────────────────────────
        _SectionLabel(label: 'Difficulty'),
        const SizedBox(height: AppSpacing.sm),
        _DifficultySelector(
          selected: wizardState.difficulty,
          onSelected: (d) =>
              ref.read(blueprintWizardProvider.notifier).setDifficulty(d),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Next Button ──────────────────────────────────────────────────
        PrimaryButton(
          label: 'Generate Prompt',
          onPressed: wizardState.isGoalValid ? _onNext : null,
          icon: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: AppSpacing.iconMd,
          ),
        ),

        if (!wizardState.isGoalValid && _goalController.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Goal must be at least 10 characters',
            style: textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ── Template Grid ─────────────────────────────────────────────────────────────

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.selected, required this.onSelected});

  final PromptTemplate selected;
  final ValueChanged<PromptTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 90,
      ),
      itemCount: PromptTemplate.values.length,
      itemBuilder: (context, index) {
        final template = PromptTemplate.values[index];
        final isSelected = template == selected;
        return _TemplateCard(
          template: template,
          isSelected: isSelected,
          onTap: () => onSelected(template),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final PromptTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(template.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              template.label,
              style: textTheme.labelSmall?.copyWith(
                color: isSelected ? scheme.primary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Difficulty Selector ───────────────────────────────────────────────────────

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.selected, required this.onSelected});

  final ProjectDifficulty selected;
  final ValueChanged<ProjectDifficulty> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: ProjectDifficulty.values.map((d) {
        final isSelected = d == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.15)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  d.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
      ],
    );
  }
}
