import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User's choice from the recovery bottom sheet.
enum RecoveryChoice { restoreMissing, replaceAll }

/// Android bottom sheet shown when restoring a blueprint that still has some
/// tasks. Lets the user restore only missing tasks (safe) or replace all.
///
/// Returns null if dismissed/cancelled.
Future<RecoveryChoice?> showBlueprintRecoverySheet(
  BuildContext context, {
  required int existingTaskCount,
}) {
  ProviderScope.containerOf(context).read(hapticServiceProvider).selectionClick();
  return showModalBottomSheet<RecoveryChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecoverySheet(existingTaskCount: existingTaskCount),
  );
}

class _RecoverySheet extends StatelessWidget {
  const _RecoverySheet({required this.existingTaskCount});
  final int existingTaskCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Restore Blueprint',
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You already have $existingTaskCount task${existingTaskCount == 1 ? '' : 's'}. "
            'Choose how to restore from your saved blueprint.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _RecoveryOption(
            icon: Icons.auto_fix_high_rounded,
            title: 'Restore missing tasks only',
            subtitle: 'Recommended — keeps your existing progress.',
            highlighted: true,
            onTap: () =>
                Navigator.of(context).pop(RecoveryChoice.restoreMissing),
          ),
          const SizedBox(height: 10),
          _RecoveryOption(
            icon: Icons.restart_alt_rounded,
            title: 'Replace all tasks',
            subtitle: 'Rebuilds the full roadmap. Resets task progress.',
            highlighted: false,
            destructive: true,
            onTap: () => Navigator.of(context).pop(RecoveryChoice.replaceAll),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _RecoveryOption extends StatelessWidget {
  const _RecoveryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = destructive ? scheme.error : scheme.primary;

    return Material(
      color: highlighted
          ? accent.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () {
  ProviderScope.containerOf(context).read(hapticServiceProvider).selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: highlighted
                  ? accent.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
