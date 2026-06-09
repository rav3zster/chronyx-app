import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/page_header.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/profile/presentation/providers/profile_avatar_provider.dart';
import 'package:chronyx/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine user name display
    final String email = user.email ?? 'user@chronyx.app';
    final String name = email.split('@').first;
    final String displayName = name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : 'User';

    final isCompact = context.isCompact;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: context.responsiveValue(
            compact: Breakpoints.maxContent,
            medium: Breakpoints.maxContent,
            expanded: Breakpoints.maxDoubleContent,
          ),
          child: isCompact
              ? CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: PageHeader(title: 'Profile'),
                      ),
                    ),

                    // Profile Card Details
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ProfileHeaderCard(
                          displayName: displayName,
                          email: email,
                        ),
                      ),
                    ),

                    // Statistics Section
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ProfileStatsSection(),
                      ),
                    ),

                    // Actions Menu
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      sliver: SliverToBoxAdapter(
                        child: _ProfileMenu(scheme: scheme, textTheme: textTheme),
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: PageHeader(title: 'Profile'),
                      ),
                    ),

                    // Side-by-side layout for wide screens
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Header details + actions menu)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ProfileHeaderCard(
                                    displayName: displayName,
                                    email: email,
                                  ),
                                  const SizedBox(height: 20),
                                  _ProfileMenu(scheme: scheme, textTheme: textTheme),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Column (Stats / Performance summary)
                            Expanded(
                              flex: 5,
                              child: _ProfileStatsSection(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Profile Header Card ───────────────────────────────────────────────────────

class _ProfileHeaderCard extends ConsumerWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.email,
  });

  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final avatarGlyph = ref.watch(profileAvatarProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          // Avatar with hover/tap effect
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              showAvatarPicker(context, ref);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarGlyph,
                      style: const TextStyle(fontSize: 54, height: 1.0),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.surfaceContainerHighest,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => showAvatarPicker(context, ref),
            child: Text(
              'Change Avatar Character',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Stats Section ─────────────────────────────────────────────────────

class _ProfileStatsSection extends ConsumerWidget {
  const _ProfileStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(analyticsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PERFORMANCE SUMMARY',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
          ],
        ),
        const SizedBox(height: 16),
        analyticsState.when(
          data: (summary) {
            if (summary == null) {
              return const _StatsPlaceholder(message: 'No logs recorded yet');
            }
            final todayHrs = summary.totalMinutesDaily / 60;
            final weekHrs = summary.totalMinutesWeekly / 60;
            final score = summary.productivityScore;

            return Row(
              children: [
                Expanded(
                  child: _StatGridItem(
                    title: 'Today',
                    value: '${todayHrs.toStringAsFixed(1)}h',
                    icon: Icons.today_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatGridItem(
                    title: 'This Week',
                    value: '${weekHrs.toStringAsFixed(1)}h',
                    icon: Icons.date_range_rounded,
                    color: const Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatGridItem(
                    title: 'Score',
                    value: '${score.toStringAsFixed(0)}%',
                    icon: Icons.offline_bolt_rounded,
                    color: const Color(0xFF22D3A6),
                  ),
                ),
              ],
            );
          },
          loading: () => const _StatsPlaceholder(message: 'Loading stats...', isShimmer: true),
          error: (_, _) => const _StatsPlaceholder(message: 'Failed to load stats'),
        ),
      ],
    );
  }
}

class _StatGridItem extends StatelessWidget {
  const _StatGridItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPlaceholder extends StatelessWidget {
  const _StatsPlaceholder({
    required this.message,
    this.isShimmer = false,
  });

  final String message;
  final bool isShimmer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: isShimmer
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                message,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

// ── Profile Menu Actions ─────────────────────────────────────────────────────

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({
    required this.scheme,
    required this.textTheme,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // App Settings
        _MenuTile(
          icon: Icons.settings_outlined,
          color: scheme.primary,
          title: 'Settings',
          description: 'Customize appearance, notifications, productivity, and privacy',
          onTap: () => context.push(AppRoutes.settings),
        ),
        const SizedBox(height: 10),

        // Auth Debug Tooling (Only visible in debug mode)
        if (kDebugMode) ...[
          _MenuTile(
            icon: Icons.bug_report_outlined,
            color: const Color(0xFFFBBC05),
            title: 'Developer Debug Tools',
            description: 'Check auth events, logs and database status',
            onTap: () => context.push(AppRoutes.authDebug),
          ),
          const SizedBox(height: 10),
        ],

        // Sign Out
        _MenuTile(
          icon: Icons.logout_rounded,
          color: scheme.error,
          title: 'Sign Out',
          description: 'Securely disconnect your current session',
          onTap: () {
            HapticFeedback.vibrate();
            _showSignOutDialog(context, ref);
          },
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Sign Out',
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of Chronyx?',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(authProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      useBlur: false,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
