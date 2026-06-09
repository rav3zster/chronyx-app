import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/services/biometric_service.dart';
import 'package:chronyx/core/services/data_service.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/core/services/notification_service.dart';
import 'package:chronyx/core/services/permission_service.dart';
import 'package:chronyx/core/services/ringtone_service.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/core/theme/theme_provider.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                  onChanged: (val) {
                    settingsNotifier.setDailyReminder(val);
                    if (val) {
                      ref.read(notificationServiceProvider).scheduleDailyReminder(
                        TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute),
                      );
                      ref.read(permissionServiceProvider).requestPermissionsForFeature(
                        context,
                        needsNotifications: true,
                        needsExactAlarm: true,
                        needsStorage: false,
                      );
                    } else {
                      ref.read(notificationServiceProvider).cancelDailyReminder();
                    }
                  },
                ),
                if (settings.dailyReminder) ...[
                  const SizedBox(height: 4),
                  _ActionTile(
                    icon: Icons.schedule_rounded,
                    label: 'Daily Reminder Time',
                    description: '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute),
                      );
                      if (time != null) {
                        settingsNotifier.setDailyReminderTime(time.hour, time.minute);
                        ref.read(notificationServiceProvider).scheduleDailyReminder(time);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Session Complete Notification',
                  description: 'Notify me when focus session ends',
                  value: settings.sessionCompleteNotify,
                  onChanged: (val) {
                    settingsNotifier.setSessionCompleteNotify(val);
                    ref.read(permissionServiceProvider).requestPermissionsForFeature(
                      context,
                      needsNotifications: true,
                      needsExactAlarm: false,
                      needsStorage: false,
                    );
                  },
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Goal Deadline Reminder',
                  description: 'Notify me when goal targets approach deadlines',
                  value: settings.goalDeadlineNotify,
                  onChanged: (val) {
                    settingsNotifier.setGoalDeadlineNotify(val);
                    ref.read(permissionServiceProvider).requestPermissionsForFeature(
                      context,
                      needsNotifications: true,
                      needsExactAlarm: false,
                      needsStorage: false,
                    );
                  },
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _SwitchRow(
                  label: 'Weekly Summary Notification',
                  description: 'Sunday evening summary of progress',
                  value: settings.weeklySummaryNotify,
                  onChanged: (val) {
                    settingsNotifier.setWeeklySummaryNotify(val);
                    if (val) {
                      ref.read(notificationServiceProvider).scheduleWeeklySummary();
                    } else {
                      ref.read(notificationServiceProvider).cancelWeeklySummary();
                    }
                  },
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.ring_volume_rounded,
                  label: 'Notification Sound',
                  description: settings.notificationSoundName,
                  onTap: () => _showNotificationSoundPicker(context, ref),
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
                if (settings.soundEffects) ...[
                  const SizedBox(height: 4),
                  _ActionTile(
                    icon: Icons.music_note_rounded,
                    label: 'Focus Completion Sound',
                    description: settings.customSessionCompleteSound.isNotEmpty
                        ? settings.customSessionCompleteSound.split('/').last
                        : 'Default (Success Tone)',
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                      if (result != null && result.files.single.path != null) {
                        settingsNotifier.setCustomSessionCompleteSound(result.files.single.path!);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  _ActionTile(
                    icon: Icons.audiotrack_rounded,
                    label: 'Goal Completion Sound',
                    description: settings.customGoalCompleteSound.isNotEmpty
                        ? settings.customGoalCompleteSound.split('/').last
                        : 'Default (Reward Tone)',
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                      if (result != null && result.files.single.path != null) {
                        settingsNotifier.setCustomGoalCompleteSound(result.files.single.path!);
                      }
                    },
                  ),
                ],
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
                  onChanged: (val) async {
                    if (val) {
                      final bioService = ref.read(biometricServiceProvider);
                      final available = await bioService.isAvailable();
                      if (!available) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Biometrics not available on this device')),
                          );
                        }
                        return;
                      }
                      final authenticated = await bioService.authenticate(
                        reason: 'Enable biometric lock at launch',
                      );
                      if (!authenticated) return;
                    }
                    settingsNotifier.setRequireBiometrics(val);
                  },
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
                  label: 'Export as JSON',
                  description: 'Export goals, projects, sessions to JSON',
                  onTap: () => _exportData(context, ref, asCsv: false),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.table_chart_rounded,
                  label: 'Export as CSV',
                  description: 'Export data in spreadsheet-compatible format',
                  onTap: () => _exportData(context, ref, asCsv: true),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.3), height: 16),
                _ActionTile(
                  icon: Icons.backup_rounded,
                  label: 'Backup to File',
                  description: 'Create a local backup archive',
                  onTap: () => _backupToFile(context, ref),
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
                  onTap: () => _clearCache(context, ref),
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

  Future<void> _exportData(BuildContext context, WidgetRef ref, {bool asCsv = false}) async {
    try {
      await ref.read(dataServiceProvider).exportAndShare(asCsv: asCsv);
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

  Future<void> _backupToFile(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(dataServiceProvider).backupToFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup file created.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
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
                'Paste the JSON content from your backup file below, or choose a file:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await ref.read(dataServiceProvider).restoreFromFilePicker();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup restored successfully.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Restore failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.file_open_rounded, size: 18),
                label: const Text('Choose Backup File'),
              ),
              const SizedBox(height: 12),
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
                await ref.read(dataServiceProvider).restoreFromJson(text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored successfully.')),
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
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

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(dataServiceProvider).clearCache();
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
              onPressed: () async {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                await ref.read(dataServiceProvider).clearCache();
                ref.read(authProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSoundPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _NotificationSoundPickerSheet(),
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

  void _showDoubleDeleteConfirmDialog(BuildContext outerContext, WidgetRef ref) {
    final scheme = Theme.of(outerContext).colorScheme;
    showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Wipe Account Data',
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you absolutely sure? Biometric confirmation will be required to proceed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final bioService = ref.read(biometricServiceProvider);
              final authenticated = await bioService.authenticate(
                reason: 'Confirm account deletion',
              );
              if (!authenticated) {
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('Biometric confirmation failed. Deletion cancelled.')),
                  );
                }
                return;
              }
              if (outerContext.mounted) {
                Navigator.of(outerContext).pop();
              }
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
                  await ref.read(dataServiceProvider).clearCache();
                  await ref.read(authProvider.notifier).signOut();
                  
                  if (outerContext.mounted) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(content: Text('Account wiped successfully.')),
                    );
                  }
                }
              } catch (e) {
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
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

class _SwitchRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
              onChanged: onChanged == null
                  ? null
                  : (val) {
                      ref.read(hapticServiceProvider).toggleSwitch();
                      ref.read(soundServiceProvider).toggleSwitch();
                      onChanged!(val);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSelector<T> extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                onTap: () {
                  ref.read(hapticServiceProvider).buttonPress();
                  ref.read(soundServiceProvider).buttonPress();
                  onSelected(opt);
                },
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

class _ActionTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tileColor = color ?? scheme.primary;

    return InkWell(
      onTap: () {
        ref.read(hapticServiceProvider).buttonPress();
        ref.read(soundServiceProvider).buttonPress();
        onTap();
      },
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

// ── Notification Sound Picker ────────────────────────────────────────────────

class _NotificationSoundPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notification Sound',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _SoundOption(
            label: 'Default',
            subtitle: 'System default notification sound',
            isSelected: settings.notificationSoundUri.isEmpty,
            onTap: () {
              ref.read(settingsProvider.notifier).setNotificationSound('', 'Default');
              Navigator.of(context).pop();
            },
          ),
          _SoundOption(
            label: 'Pick from Ringtones',
            subtitle: 'Choose a device ringtone',
            isSelected: false,
            onTap: () async {
              final ringtoneService = RingtoneService();
              final uri = await ringtoneService.pickRingtone();
              if (uri != null && uri.isNotEmpty) {
                final parts = uri.split('/');
                final name = parts.isNotEmpty ? parts.last.replaceAll('.', ' ') : 'Custom';
                ref.read(settingsProvider.notifier).setNotificationSound(uri, name);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SoundOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SoundOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}

// ── End Notification Sound Picker ────────────────────────────────────────────

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
