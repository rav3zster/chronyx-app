import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/core/widgets/animated_counter.dart';
import 'package:chronyx/features/life_insights/domain/entities/session_celebration.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/confetti_layer.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a premium celebration sheet for a finished session.
///
/// Call [showSessionCelebration] from anywhere a session has just stopped.
Future<void> showSessionCelebration(
  BuildContext context, {
  required TimeEntry justFinished,
}) async {
  ProviderScope.containerOf(context).read(hapticServiceProvider).sessionComplete();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _SessionCelebrationSheet(justFinished: justFinished),
  );
}

class _SessionCelebrationSheet extends ConsumerWidget {
  const _SessionCelebrationSheet({required this.justFinished});
  final TimeEntry justFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Build the celebration directly from the repository.
    return FutureBuilder<SessionCelebration>(
      future: ref
          .read(lifeInsightsRepositoryProvider)
          .buildCelebration(justFinished),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _CelebrationCard(celebration: snapshot.data!);
      },
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.celebration});
  final SessionCelebration celebration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mins = celebration.duration.inMinutes;
    final delta = celebration.momentumDeltaPercent;
    final taskName = celebration.session.taskName.trim().isEmpty
        ? 'Session'
        : celebration.session.taskName.trim();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: Stack(
            children: [
              // ── Layer 1: gradient backdrop ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.45),
                        scheme.secondary.withValues(alpha: 0.35),
                        scheme.tertiary.withValues(alpha: 0.20),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // ── Layer 2: glass overlay ──
              Positioned.fill(
                child: Container(color: scheme.surface.withValues(alpha: 0.78)),
              ),
              // ── Layer 3: confetti ──
              const Positioned.fill(child: ConfettiLayer()),
              // ── Layer 4: content ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Pulse ring with glyph
                    _PulseRing(
                      glyph: celebration.glyph,
                      accent: scheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      celebration.headline,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      taskName,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Hero counter — minutes
                    AnimatedCounter(
                      value: mins,
                      style: textTheme.displayMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'minutes focused',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'CATEGORY',
                            value: celebration.categoryLabel,
                            accent: scheme.primary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _StatTile(
                            label: 'TODAY',
                            value: '${celebration.todayMinutes}m',
                            accent: DesignTokens.accentMint,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _StatTile(
                            label: 'STREAK',
                            value: '${celebration.streakDays}d',
                            accent: DesignTokens.accentEmber,
                          ),
                        ),
                      ],
                    ),

                    if (delta != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (delta >= 0
                                      ? DesignTokens.accentMint
                                      : DesignTokens.accentEmber)
                                  .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              delta >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 14,
                              color: delta >= 0
                                  ? DesignTokens.accentMint
                                  : DesignTokens.accentEmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% this week',
                              style: textTheme.labelMedium?.copyWith(
                                color: delta >= 0
                                    ? DesignTokens.accentMint
                                    : DesignTokens.accentEmber,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    // CTA
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.glyph, required this.accent});
  final String glyph;
  final Color accent;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 2; i++) ...[
                Builder(
                  builder: (context) {
                    final phase = ((_ctrl.value + i * 0.5) % 1).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - phase,
                      child: Container(
                        width: 56 + phase * 40,
                        height: 56 + phase * 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.accent.withValues(alpha: 0.45),
                      widget.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(widget.glyph, style: const TextStyle(fontSize: 28)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
