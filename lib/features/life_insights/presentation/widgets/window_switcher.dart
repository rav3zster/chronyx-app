import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/features/life_insights/domain/entities/insight_window.dart';
import 'package:flutter/material.dart';

/// Segmented pill switcher for [InsightWindow]. Animated active indicator.
class WindowSwitcher extends StatelessWidget {
  const WindowSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final InsightWindow value;
  final ValueChanged<InsightWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final values = InsightWindow.values;
    final selectedIndex = values.indexOf(value);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: DesignTokens.motionMedium,
                curve: DesignTokens.easeOut,
                left: width * selectedIndex,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  margin: const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    gradient: DesignTokens.brandGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: values.map((w) {
                  final isActive = w == value;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(w),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: DesignTokens.motionFast,
                          style: textTheme.labelMedium!.copyWith(
                            color: isActive
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(w.label),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
