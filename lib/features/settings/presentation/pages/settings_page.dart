import 'dart:convert';
import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/theme_provider.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final currentVariant = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final darkThemes = [
      AppThemeVariant.cosmicDark,
      AppThemeVariant.violetDream,
      AppThemeVariant.midnightOcean,
      AppThemeVariant.sunsetAmber,
      AppThemeVariant.graphiteBlue,
      AppThemeVariant.noirRust,
    ];
    final isDark = darkThemes.contains(currentVariant);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          children: [
            // ── Appearance Section ───────────────────────────────────────────
            const _SectionHeader(label: 'Appearance'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SwitchRow(
                  label: 'Dark Mode',
                  description: 'Toggle dark interface mode',
                  value: isDark,
                  onChanged: (val) {
                    if (val) {
                      ref.read(themeProvider.notifier).setTheme(AppThemeVariant.cosmicDark);
                    } else {
                      ref.read(themeProvider.notifier).setTheme(AppThemeVariant.warmMinimal);
                    }
                  },
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'AMOLED Black Mode',
                  description: 'Pure black backgrounds for OLED screens',
                  value: settings.amoledMode,
                  onChanged: isDark
                      ? (val) => settingsNotifier.setAmoledMode(val)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose your theme variant',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ThemeGrid(currentVariant: currentVariant),

            const SizedBox(height: AppSpacing.lg),

            // ── Notifications Section ────────────────────────────────────────
            const _SectionHeader(label: 'Notifications'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SwitchRow(
                  label: 'Daily Reminder',
                  description: 'Remind me to work on active roadmaps',
                  value: settings.dailyReminder,
                  onChanged: (val) => settingsNotifier.setDailyReminder(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Session Complete Notification',
                  description: 'Notify me when focus session ends',
                  value: settings.sessionCompleteNotify,
                  onChanged: (val) => settingsNotifier.setSessionCompleteNotify(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Goal Deadline Reminder',
                  description: 'Notify me when goal targets approach deadlines',
                  value: settings.goalDeadlineNotify,
                  onChanged: (val) => settingsNotifier.setGoalDeadlineNotify(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Weekly Summary Notification',
                  description: 'Sunday evening summary of progress',
                  value: settings.weeklySummaryNotify,
                  onChanged: (val) => settingsNotifier.setWeeklySummaryNotify(val),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Productivity Section ─────────────────────────────────────────
            const _SectionHeader(label: 'Productivity'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SegmentedSelector<int>(
                  label: 'Default Focus Duration',
                  description: 'Duration of focus sessions',
                  options: const [25, 30, 45, 60, 0],
                  selectedOption: [25, 30, 45, 60].contains(settings.focusDuration)
                      ? settings.focusDuration
                      : 0,
                  labelBuilder: (opt) {
                    if (opt == 0) {
                      return [25, 30, 45, 60].contains(settings.focusDuration)
                          ? 'Custom...'
                          : 'Custom (${settings.focusDuration}m)';
                    }
                    return '${opt}m';
                  },
                  onSelected: (opt) {
                    if (opt == 0) {
                      _showCustomDurationDialog(context, ref, settings.focusDuration);
                    } else {
                      settingsNotifier.setFocusDuration(opt);
                    }
                  },
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SegmentedSelector<int>(
                  label: 'Break Duration',
                  description: 'Duration of break sessions',
                  options: const [5, 10, 15],
                  selectedOption: settings.breakDuration,
                  labelBuilder: (opt) => '${opt}m',
                  onSelected: (opt) => settingsNotifier.setBreakDuration(opt),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Auto Start Breaks',
                  description: 'Transition into breaks automatically',
                  value: settings.autoStartBreaks,
                  onChanged: (val) => settingsNotifier.setAutoStartBreaks(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Auto Start Next Session',
                  description: 'Start next focus session automatically',
                  value: settings.autoStartNextSession,
                  onChanged: (val) => settingsNotifier.setAutoStartNextSession(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Haptic Feedback',
                  description: 'Vibrate on session clicks and triggers',
                  value: settings.hapticFeedback,
                  onChanged: (val) => settingsNotifier.setHapticFeedback(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Sound Effects',
                  description: 'Play sounds on session completed',
                  value: settings.soundEffects,
                  onChanged: (val) => settingsNotifier.setSoundEffects(val),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Dashboard Preferences Section ───────────────────────────────
            const _SectionHeader(label: 'Dashboard Preferences'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SwitchRow(
                  label: 'Show Streak Card',
                  description: 'Display focus consistency metrics',
                  value: settings.showStreakCard,
                  onChanged: (val) => settingsNotifier.setShowStreakCard(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Show Momentum Card',
                  description: 'Display productivity score indicator',
                  value: settings.showMomentumCard,
                  onChanged: (val) => settingsNotifier.setShowMomentumCard(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Show Weekly Graph',
                  description: 'Display analytics chart on dashboard',
                  value: settings.showWeeklyGraph,
                  onChanged: (val) => settingsNotifier.setShowWeeklyGraph(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Show Quotes',
                  description: 'Display focus quotes on dashboard greeting',
                  value: settings.showQuotes,
                  onChanged: (val) => settingsNotifier.setShowQuotes(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Compact Dashboard Mode',
                  description: 'Reduce padding and sizing on home page',
                  value: settings.compactDashboardMode,
                  onChanged: (val) => settingsNotifier.setCompactDashboardMode(val),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Privacy Section ──────────────────────────────────────────────
            const _SectionHeader(label: 'Privacy'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SwitchRow(
                  label: 'Require Biometrics On Launch',
                  description: 'Use fingerprint or face recognition',
                  value: settings.requireBiometrics,
                  onChanged: (val) => settingsNotifier.setRequireBiometrics(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SegmentedSelector<String>(
                  label: 'Lock App After Inactivity',
                  description: 'Secure lock when app stays inactive',
                  options: const ['Never', '1 minute', '5 minutes', '15 minutes'],
                  selectedOption: settings.lockInactivity,
                  labelBuilder: (opt) => opt,
                  onSelected: (opt) => settingsNotifier.setLockInactivity(opt),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Hide Sensitive Statistics',
                  description: 'Obfuscate focus charts and times on public view',
                  value: settings.hideSensitiveStats,
                  onChanged: (val) => settingsNotifier.setHideSensitiveStats(val),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Data Section ─────────────────────────────────────────────────
            const _SectionHeader(label: 'Data'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _ActionTile(
                  icon: Icons.download_rounded,
                  label: 'Export Data',
                  description: 'Export goals, projects, sessions to JSON',
                  onTap: () => _exportData(context),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.backup_rounded,
                  label: 'Backup to File',
                  description: 'Create a local backup archive',
                  onTap: () => _backupToFile(context),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.settings_backup_restore_rounded,
                  label: 'Restore Backup',
                  description: 'Restore databases from a JSON backup content',
                  onTap: () => _showRestoreDialog(context, ref),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Clear Cache',
                  description: 'Delete local temporary session files',
                  onTap: () => _clearCache(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Account Section ──────────────────────────────────────────────
            const _SectionHeader(label: 'Account'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _ActionTile(
                  icon: Icons.logout_rounded,
                  color: scheme.error,
                  label: 'Sign Out',
                  description: 'Safely exit current user session',
                  onTap: () => _showSignOutDialog(context, ref),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.delete_forever_rounded,
                  color: scheme.error,
                  label: 'Delete Account',
                  description: 'Danger: Wipes all user database records',
                  onTap: () => _showDeleteAccountDialog(context, ref),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Developer Section ────────────────────────────────────────────
            const _SectionHeader(label: 'Developer Options'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _SwitchRow(
                  label: 'Enable Debug Tools',
                  description: 'Access database event logs',
                  value: settings.enableDebugTools,
                  onChanged: (val) => settingsNotifier.setEnableDebugTools(val),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Enable Experimental Features',
                  description: 'Turn on early-stage pipeline widgets',
                  value: settings.enableExperimentalFeatures,
                  onChanged: (val) => settingsNotifier.setEnableExperimentalFeatures(val),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── About Section ────────────────────────────────────────────────
            const _SectionHeader(label: 'About'),
            const SizedBox(height: AppSpacing.md),
            _GroupedCard(
              children: [
                _InfoRow(label: 'App Name', value: 'Chronyx'),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 12),
                _InfoRow(label: 'Version', value: '1.0.0'),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 12),
                _InfoRow(label: 'Build Number', value: '1'),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 12),
                _InfoRow(label: 'Flutter Version', value: '3.22.0'),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 12),
                _InfoRow(
                  label: 'Supabase Status',
                  value: Supabase.instance.client.auth.currentSession != null
                      ? 'Connected'
                      : 'Disconnected',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Action Handlers ────────────────────────────────────────────────────────

  void _showCustomDurationDialog(BuildContext context, WidgetRef ref, int currentVal) {
    final controller = TextEditingController(text: currentVal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Custom Focus Duration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g. 25',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 1 && val <= 180) {
                ref.read(settingsProvider.notifier).setFocusDuration(val);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('You must be signed in to export data.');
      }
      
      final goals = await client.from('goals').select().eq('user_id', userId);
      final projects = await client.from('projects').select().eq('user_id', userId);
      final sessions = await client.from('time_logs').select().eq('user_id', userId);

      final exportMap = {
        'goals': goals,
        'projects': projects,
        'sessions': sessions,
        'exported_at': DateTime.now().toIso8601String(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);
      final bytes = utf8.encode(jsonString);
      final base64 = base64Encode(bytes);
      final url = 'data:application/json;base64,$base64';
      
      await launchUrl(Uri.parse(url));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _backupToFile(BuildContext context) async {
    await _exportData(context);
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Restore Backup'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste the JSON content from your backup file below:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{ "goals": [...], "projects": [...], "sessions": [...] }',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text;
              if (text.trim().isEmpty) return;
              try {
                final data = jsonDecode(text) as Map<String, dynamic>;
                final goals = data['goals'] as List?;
                final projects = data['projects'] as List?;
                final sessions = data['sessions'] as List?;

                final client = Supabase.instance.client;

                if (goals != null) {
                  for (var g in goals) {
                    await client.from('goals').upsert(g);
                  }
                }
                if (projects != null) {
                  for (var p in projects) {
                    await client.from('projects').upsert(p);
                  }
                }
                if (sessions != null) {
                  for (var s in sessions) {
                    await client.from('time_logs').upsert(s);
                  }
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored successfully.')),
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: Invalid JSON format ($e)')),
                  );
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary cache cleared successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear cache failed: $e')),
        );
      }
    }
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                Navigator.of(context).pop(); // Exit Settings page
                ref.read(authProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Delete Account',
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action is irreversible. All your data including projects, goals, sessions, and profile stats will be permanently wiped out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () {
              Navigator.of(context).pop();
              _showDoubleDeleteConfirmDialog(context, ref);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showDoubleDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Wipe Account Data',
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you absolutely sure? Click "Delete Permanently" to wipe all database tables and log out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Exit Settings page
              try {
                final client = Supabase.instance.client;
                final userId = client.auth.currentUser?.id;
                if (userId != null) {
                  await client.from('time_logs').delete().eq('user_id', userId);
                  final projectsRes = await client.from('projects').select('id').eq('user_id', userId);
                  final projectIds = (projectsRes as List).map((p) => p['id'] as String).toList();
                  if (projectIds.isNotEmpty) {
                    await client.from('project_tasks').delete().inFilter('project_id', projectIds);
                  }
                  await client.from('projects').delete().eq('user_id', userId);
                  await client.from('goals').delete().eq('user_id', userId);
                  await ref.read(authProvider.notifier).signOut();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account wiped successfully.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deletion failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
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
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
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
    _scale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (List<Color>, Color, Color) _themeColors(AppThemeVariant v) {
    return switch (v) {
      AppThemeVariant.warmMinimal => (
        [AppColors.warmGold, AppColors.warmGoldLight],
        AppColors.warmBackground,
        AppColors.warmGold,
      ),
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
      AppThemeVariant.warmCream => (
        AppColors.creamGradient,
        AppColors.creamBg,
        AppColors.creamGold,
      ),
      AppThemeVariant.graphiteBlue => (
        AppColors.graphiteGradient,
        AppColors.graphiteBg,
        AppColors.graphiteBlueBright,
      ),
      AppThemeVariant.forestSage => (
        AppColors.sageGradient,
        AppColors.sageBg,
        AppColors.sageGreen,
      ),
      AppThemeVariant.noirRust => (
        AppColors.noirGradient,
        AppColors.noirBg,
        AppColors.noirRust,
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
              color: widget.isSelected ? accentColor : scheme.outlineVariant,
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

// ── Reusable Settings Layout Subwidgets ──────────────────────────────────────

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

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
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: onChanged == null
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            container: true,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: scheme.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSelector<T> extends StatelessWidget {
  const _SegmentedSelector({
    required this.label,
    required this.description,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    required this.labelBuilder,
  });

  final String label;
  final String description;
  final List<T> options;
  final T selectedOption;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selectedOption;
              return GestureDetector(
                onTap: () => onSelected(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.16)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    labelBuilder(opt),
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected ? scheme.primary : scheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tileColor = color ?? scheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tileColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: color ?? scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
