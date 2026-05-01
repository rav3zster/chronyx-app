import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

/// A full-width secondary/ghost button with animated border and press effect.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.icon,
    this.height = AppSpacing.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Optional leading icon widget.
  final Widget? icon;

  final double height;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.975).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _ctrl.forward(),
        onTapUp: disabled ? null : (_) => _ctrl.reverse(),
        onTapCancel: disabled ? null : _ctrl.reverse,
        onTap: disabled ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _hovered
                  ? scheme.onSurface.withOpacity(0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: disabled
                    ? scheme.outline.withOpacity(0.3)
                    : scheme.outline,
                width: 1,
              ),
            ),
            child: _buildChild(context, textTheme, scheme, disabled),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme scheme,
    bool disabled,
  ) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          widget.label,
          style: textTheme.labelLarge?.copyWith(
            color: disabled
                ? scheme.onSurface.withOpacity(0.38)
                : scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
