import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A primary/secondary/destructive action for a project state screen.
class ProjectStateAction {
  const ProjectStateAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.kind = ProjectActionKind.secondary,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ProjectActionKind kind;
  final bool loading;
}

enum ProjectActionKind { primary, secondary, destructive }

/// Premium, intentional state screen used for recovery / missing / archived
/// empty-ish states. Big glyph, eyebrow, headline, body, and a stack of
/// forward actions — never a dead end.
class ProjectStateScaffold extends StatelessWidget {
  const ProjectStateScaffold({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.actions,
    this.accent,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final List<ProjectStateAction> actions;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = accent ?? scheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glyph in a soft tinted halo
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: tint),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              eyebrow.toUpperCase(),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ActionButton(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});
  final ProjectStateAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, border) = switch (action.kind) {
      ProjectActionKind.primary => (scheme.primary, scheme.onPrimary, null),
      ProjectActionKind.secondary => (
        scheme.elevatedCard,
        scheme.onSurface,
        scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      ProjectActionKind.destructive => (
        scheme.error.withValues(alpha: 0.10),
        scheme.error,
        scheme.error.withValues(alpha: 0.4),
      ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: action.loading
            ? null
            : () {
                HapticFeedback.selectionClick();
                action.onTap();
              },
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: border == null ? null : Border.all(color: border),
          ),
          child: action.loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 18, color: fg),
                    const SizedBox(width: 10),
                    Text(
                      action.label,
                      style: textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
