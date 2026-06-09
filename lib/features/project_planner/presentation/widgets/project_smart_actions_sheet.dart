import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions a user can take on a project from the smart-actions sheet.
enum SmartAction {
  edit,
  pause,
  resume,
  duplicate,
  regenerateRemaining,
  archive,
  delete,
}

/// Android bottom sheet of contextual project actions. Destructive actions
/// are visually separated at the bottom. Returns null if dismissed.
Future<SmartAction?> showProjectSmartActions(
  BuildContext context, {
  required ProjectStatus status,
}) {
  ProviderScope.containerOf(context).read(hapticServiceProvider).selectionClick();
  return showModalBottomSheet<SmartAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SmartActionsSheet(status: status),
  );
}

class _SmartActionsSheet extends StatelessWidget {
  const _SmartActionsSheet({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final isPaused = status == ProjectStatus.paused;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'Manage Blueprint',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _Row(
            icon: Icons.edit_outlined,
            label: 'Edit Blueprint',
            onTap: () => Navigator.of(context).pop(SmartAction.edit),
          ),
          if (isPaused)
            _Row(
              icon: Icons.play_arrow_rounded,
              label: 'Resume Blueprint',
              onTap: () => Navigator.of(context).pop(SmartAction.resume),
            )
          else
            _Row(
              icon: Icons.pause_rounded,
              label: 'Pause Blueprint',
              onTap: () => Navigator.of(context).pop(SmartAction.pause),
            ),
          _Row(
            icon: Icons.copy_all_rounded,
            label: 'Duplicate',
            onTap: () => Navigator.of(context).pop(SmartAction.duplicate),
          ),
          _Row(
            icon: Icons.auto_mode_rounded,
            label: 'Regenerate Remaining Days',
            onTap: () =>
                Navigator.of(context).pop(SmartAction.regenerateRemaining),
          ),
          _Row(
            icon: Icons.inventory_2_outlined,
            label: 'Archive',
            onTap: () => Navigator.of(context).pop(SmartAction.archive),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
          _Row(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
            onTap: () => Navigator.of(context).pop(SmartAction.delete),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = destructive ? scheme.error : scheme.onSurface;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () {
  ProviderScope.containerOf(context).read(hapticServiceProvider).selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 16),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
