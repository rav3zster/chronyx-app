import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/input_field.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateGoalPage extends ConsumerStatefulWidget {
  const CreateGoalPage({super.key});

  @override
  ConsumerState<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends ConsumerState<CreateGoalPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  double _targetMinutes = 30;
  bool _isChallenge = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start?.add(const Duration(days: 30)) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _showError('Please enter a goal title.');
      return;
    }
    if (_start == null || _end == null) {
      _showError('Please select start and end dates.');
      return;
    }
    if (_end!.isBefore(_start!)) {
      _showError('End date must be after start date.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(goalsProvider.notifier).createGoal(
            title: title,
            description: _desc.text.trim(),
            startDate: _start!,
            endDate: _end!,
            dailyTargetMinutes: _targetMinutes.round(),
            isChallenge: _isChallenge,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      _showError(ErrorMessageMapper.fromError(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Basic Info ─────────────────────────────────────────────────
          _SectionLabel(label: 'Goal Details'),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                InputField(
                  controller: _title,
                  label: 'Title',
                  hint: 'e.g. Read 30 minutes daily',
                  prefixIcon: Icon(
                    Icons.flag_rounded,
                    color: scheme.onSurfaceVariant,
                    size: AppSpacing.iconMd,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                InputField(
                  controller: _desc,
                  label: 'Description (optional)',
                  hint: 'What motivates this goal?',
                  maxLines: 3,
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                    color: scheme.onSurfaceVariant,
                    size: AppSpacing.iconMd,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Dates ─────────────────────────────────────────────────────
          _SectionLabel(label: 'Duration'),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Start',
                    date: _start,
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickStart,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.arrow_forward_rounded,
                    color: scheme.onSurfaceVariant, size: AppSpacing.iconSm),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DateButton(
                    label: 'End',
                    date: _end,
                    icon: Icons.event_rounded,
                    onTap: _pickEnd,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Daily Target ───────────────────────────────────────────────
          _SectionLabel(label: 'Daily Target'),
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
                    Icon(Icons.timer_rounded,
                        color: scheme.primary, size: AppSpacing.iconMd),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${_targetMinutes.round()} min / day',
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _targetMinutes,
                  min: 5,
                  max: 240,
                  divisions: 47,
                  label: '${_targetMinutes.round()} min',
                  onChanged: (v) => setState(() => _targetMinutes = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('5 min',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    Text('4 hrs',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Challenge Mode ─────────────────────────────────────────────
          _SectionLabel(label: 'Challenge Mode'),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '🔥 Challenge Mode',
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Missing a day resets your streak to zero',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: _isChallenge,
              onChanged: (v) => setState(() => _isChallenge = v),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            label: 'Create Goal',
            isLoading: _busy,
            onPressed: _submit,
            icon: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: AppSpacing.iconMd,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasDate = date != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: hasDate
              ? scheme.primary.withValues(alpha: 0.1)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: hasDate ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: hasDate ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: hasDate ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              date == null
                  ? 'Select date'
                  : '${date!.day}/${date!.month}/${date!.year}',
              style: textTheme.bodySmall?.copyWith(
                color: hasDate ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
