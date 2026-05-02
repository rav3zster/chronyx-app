import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.subtitle,
    this.icon,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon ?? Icons.hourglass_empty, size: AppSpacing.iconXl, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (onCta != null && ctaLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
