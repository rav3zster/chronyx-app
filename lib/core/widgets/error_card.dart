import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer))),
                  ],
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
