import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentVariant = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        children: [
          // ── Theme Section ─────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose your theme',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ThemeGrid(currentVariant: currentVariant),

          const SizedBox(height: AppSpacing.xl),

          // ── About Section ──────────────────────────────────────────────────
          _SectionHeader(label: 'About'),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: 'App', value: 'Chronyx'),
          _InfoRow(label: 'Version', value: '1.0.0'),
          _InfoRow(label: 'Build', value: 'Release 1'),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Theme Grid ───────────────────────────────────────────────────────────────

class _ThemeGrid extends ConsumerWidget {
  const _ThemeGrid({required this.currentVariant});
  final AppThemeVariant currentVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.5,
      ),
      itemCount: AppThemeVariant.values.length,
      itemBuilder: (context, index) {
        final variant = AppThemeVariant.values[index];
        final isSelected = variant == currentVariant;
        return _ThemeCard(
          variant: variant,
          isSelected: isSelected,
          onTap: () => ref.read(themeProvider.notifier).setTheme(variant),
        );
      },
    );
  }
}

class _ThemeCard extends StatefulWidget {
  const _ThemeCard({
    required this.variant,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeVariant variant;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (List<Color>, Color, Color) _themeColors(AppThemeVariant v) {
    return switch (v) {
      AppThemeVariant.cosmicDark => (
          AppColors.brandGradient,
          AppColors.darkBackground,
          AppColors.indigo,
        ),
      AppThemeVariant.lightClean => (
          AppColors.brandGradient,
          AppColors.lightBackground,
          AppColors.indigo,
        ),
      AppThemeVariant.violetDream => (
          AppColors.violetGradient,
          const Color(0xFF08050F),
          AppColors.violet,
        ),
      AppThemeVariant.midnightOcean => (
          AppColors.oceanGradient,
          AppColors.oceanBackground,
          AppColors.oceanPrimary,
        ),
      AppThemeVariant.sunsetAmber => (
          AppColors.amberGradient,
          AppColors.amberBackground,
          AppColors.amberPrimary,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (gradColors, bgColor, accentColor) = _themeColors(widget.variant);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: widget.isSelected
                  ? accentColor
                  : scheme.outlineVariant,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color swatch bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [bgColor, bgColor.withValues(alpha: 0.7)],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppSpacing.radiusSm),
                            bottomLeft: Radius.circular(AppSpacing.radiusSm),
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 28,
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(AppSpacing.radiusSm),
                          bottomRight: Radius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      widget.variant.icon,
                      size: AppSpacing.iconSm,
                      color: accentColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        widget.variant.label,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: AppSpacing.iconSm,
                        color: accentColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
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
        Expanded(
          child: Divider(color: scheme.outlineVariant, height: 1),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
