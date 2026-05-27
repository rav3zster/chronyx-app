import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

/// A premium, on-brand state view for empty and error states.
///
/// Replaces the harsh red `ErrorCard` with a calm, centered layout
/// that matches the redesigned dashboard's visual language.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// Convenience constructor for error state.
  factory StateView.error({required String message, VoidCallback? onRetry}) {
    return StateView(
      icon: Icons.cloud_off_rounded,
      title: 'Couldn\'t load',
      message: message,
      actionLabel: onRetry != null ? 'Try again' : null,
      onAction: onRetry,
    );
  }

  /// Convenience constructor for empty state.
  factory StateView.empty({
    required IconData icon,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = iconColor ?? scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tint.withValues(alpha: 0.18),
                    tint.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Icon(icon, size: 32, color: tint),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
