import 'package:chronyx/core/services/notification_service.dart';
import 'package:chronyx/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class SettingsState {
  final bool dailyReminder;
  final bool sessionCompleteNotify;
  final bool goalDeadlineNotify;
  final bool weeklySummaryNotify;
  final AppThemeVariant themeVariant;
  final bool amoledMode;
  final int focusDuration;
  final int breakDuration;
  final bool autoStartBreaks;
  final bool autoStartNextSession;
  final bool hapticFeedback;
  final bool soundEffects;
  final bool showStreakCard;
  final bool showMomentumCard;
  final bool showWeeklyGraph;
  final bool showQuotes;
  final bool compactDashboardMode;
  final bool requireBiometrics;
  final String lockInactivity;
  final bool hideSensitiveStats;
  final bool enableDebugTools;
  final bool enableExperimentalFeatures;
  final String notificationSoundUri;
  final String notificationSoundName;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final String customSessionCompleteSound;
  final String customGoalCompleteSound;

  const SettingsState({
    this.dailyReminder = true,
    this.sessionCompleteNotify = true,
    this.goalDeadlineNotify = true,
    this.weeklySummaryNotify = true,
    this.themeVariant = AppThemeVariant.warmMinimal,
    this.amoledMode = false,
    this.focusDuration = 25,
    this.breakDuration = 5,
    this.autoStartBreaks = false,
    this.autoStartNextSession = false,
    this.hapticFeedback = true,
    this.soundEffects = true,
    this.showStreakCard = true,
    this.showMomentumCard = true,
    this.showWeeklyGraph = true,
    this.showQuotes = true,
    this.compactDashboardMode = false,
    this.requireBiometrics = false,
    this.lockInactivity = 'Never',
    this.hideSensitiveStats = false,
    this.enableDebugTools = false,
    this.enableExperimentalFeatures = false,
    this.notificationSoundUri = '',
    this.notificationSoundName = 'Default',
    this.dailyReminderHour = 9,
    this.dailyReminderMinute = 0,
    this.customSessionCompleteSound = '',
    this.customGoalCompleteSound = '',
  });

  SettingsState copyWith({
    bool? dailyReminder,
    bool? sessionCompleteNotify,
    bool? goalDeadlineNotify,
    bool? weeklySummaryNotify,
    AppThemeVariant? themeVariant,
    bool? amoledMode,
    int? focusDuration,
    int? breakDuration,
    bool? autoStartBreaks,
    bool? autoStartNextSession,
    bool? hapticFeedback,
    bool? soundEffects,
    bool? showStreakCard,
    bool? showMomentumCard,
    bool? showWeeklyGraph,
    bool? showQuotes,
    bool? compactDashboardMode,
    bool? requireBiometrics,
    String? lockInactivity,
    bool? hideSensitiveStats,
    bool? enableDebugTools,
    bool? enableExperimentalFeatures,
    String? notificationSoundUri,
    String? notificationSoundName,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    String? customSessionCompleteSound,
    String? customGoalCompleteSound,
  }) {
    return SettingsState(
      dailyReminder: dailyReminder ?? this.dailyReminder,
      sessionCompleteNotify: sessionCompleteNotify ?? this.sessionCompleteNotify,
      goalDeadlineNotify: goalDeadlineNotify ?? this.goalDeadlineNotify,
      weeklySummaryNotify: weeklySummaryNotify ?? this.weeklySummaryNotify,
      themeVariant: themeVariant ?? this.themeVariant,
      amoledMode: amoledMode ?? this.amoledMode,
      focusDuration: focusDuration ?? this.focusDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartNextSession: autoStartNextSession ?? this.autoStartNextSession,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      soundEffects: soundEffects ?? this.soundEffects,
      showStreakCard: showStreakCard ?? this.showStreakCard,
      showMomentumCard: showMomentumCard ?? this.showMomentumCard,
      showWeeklyGraph: showWeeklyGraph ?? this.showWeeklyGraph,
      showQuotes: showQuotes ?? this.showQuotes,
      compactDashboardMode: compactDashboardMode ?? this.compactDashboardMode,
      requireBiometrics: requireBiometrics ?? this.requireBiometrics,
      lockInactivity: lockInactivity ?? this.lockInactivity,
      hideSensitiveStats: hideSensitiveStats ?? this.hideSensitiveStats,
      enableDebugTools: enableDebugTools ?? this.enableDebugTools,
      enableExperimentalFeatures: enableExperimentalFeatures ?? this.enableExperimentalFeatures,
      notificationSoundUri: notificationSoundUri ?? this.notificationSoundUri,
      notificationSoundName: notificationSoundName ?? this.notificationSoundName,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      customSessionCompleteSound: customSessionCompleteSound ?? this.customSessionCompleteSound,
      customGoalCompleteSound: customGoalCompleteSound ?? this.customGoalCompleteSound,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;
  final Ref _ref;

  SettingsNotifier(this._prefs, this._ref) : super(const SettingsState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    state = SettingsState(
      dailyReminder: _prefs.getBool('dailyReminder') ?? true,
      sessionCompleteNotify: _prefs.getBool('sessionCompleteNotify') ?? true,
      goalDeadlineNotify: _prefs.getBool('goalDeadlineNotify') ?? true,
      weeklySummaryNotify: _prefs.getBool('weeklySummaryNotify') ?? true,
      themeVariant: _themeVariantFromPrefs(),
      amoledMode: _prefs.getBool('amoledMode') ?? false,
      focusDuration: _prefs.getInt('focusDuration') ?? 25,
      breakDuration: _prefs.getInt('breakDuration') ?? 5,
      autoStartBreaks: _prefs.getBool('autoStartBreaks') ?? false,
      autoStartNextSession: _prefs.getBool('autoStartNextSession') ?? false,
      hapticFeedback: _prefs.getBool('hapticFeedback') ?? true,
      soundEffects: _prefs.getBool('soundEffects') ?? true,
      showStreakCard: _prefs.getBool('showStreakCard') ?? true,
      showMomentumCard: _prefs.getBool('showMomentumCard') ?? true,
      showWeeklyGraph: _prefs.getBool('showWeeklyGraph') ?? true,
      showQuotes: _prefs.getBool('showQuotes') ?? true,
      compactDashboardMode: _prefs.getBool('compactDashboardMode') ?? false,
      requireBiometrics: _prefs.getBool('requireBiometrics') ?? false,
      lockInactivity: _prefs.getString('lockInactivity') ?? 'Never',
      hideSensitiveStats: _prefs.getBool('hideSensitiveStats') ?? false,
      enableDebugTools: _prefs.getBool('enableDebugTools') ?? false,
      enableExperimentalFeatures: _prefs.getBool('enableExperimentalFeatures') ?? false,
      notificationSoundUri: _prefs.getString('notificationSoundUri') ?? '',
      notificationSoundName: _prefs.getString('notificationSoundName') ?? 'Default',
      dailyReminderHour: _prefs.getInt('dailyReminderHour') ?? 9,
      dailyReminderMinute: _prefs.getInt('dailyReminderMinute') ?? 0,
      customSessionCompleteSound: _prefs.getString('customSessionCompleteSound') ?? '',
      customGoalCompleteSound: _prefs.getString('customGoalCompleteSound') ?? '',
    );
  }

  AppThemeVariant _themeVariantFromPrefs() {
    final str = _prefs.getString('themeVariant') ?? AppThemeVariant.warmMinimal.name;
    return AppThemeVariant.values.firstWhere(
      (e) => e.name == str,
      orElse: () => AppThemeVariant.warmMinimal,
    );
  }

  Future<void> _save(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
  }

  Future<void> setDailyReminder(bool value) async {
    await _save('dailyReminder', value);
    state = state.copyWith(dailyReminder: value);
  }

  Future<void> setSessionCompleteNotify(bool value) async {
    await _save('sessionCompleteNotify', value);
    state = state.copyWith(sessionCompleteNotify: value);
  }

  Future<void> setGoalDeadlineNotify(bool value) async {
    await _save('goalDeadlineNotify', value);
    state = state.copyWith(goalDeadlineNotify: value);
  }

  Future<void> setWeeklySummaryNotify(bool value) async {
    await _save('weeklySummaryNotify', value);
    state = state.copyWith(weeklySummaryNotify: value);
  }

  Future<void> setThemeVariant(AppThemeVariant value) async {
    await _save('themeVariant', value.name);
    state = state.copyWith(themeVariant: value);
  }

  Future<void> setAmoledMode(bool value) async {
    await _save('amoledMode', value);
    state = state.copyWith(amoledMode: value);
  }

  Future<void> setFocusDuration(int value) async {
    await _save('focusDuration', value);
    state = state.copyWith(focusDuration: value);
  }

  Future<void> setBreakDuration(int value) async {
    await _save('breakDuration', value);
    state = state.copyWith(breakDuration: value);
  }

  Future<void> setAutoStartBreaks(bool value) async {
    await _save('autoStartBreaks', value);
    state = state.copyWith(autoStartBreaks: value);
  }

  Future<void> setAutoStartNextSession(bool value) async {
    await _save('autoStartNextSession', value);
    state = state.copyWith(autoStartNextSession: value);
  }

  Future<void> setHapticFeedback(bool value) async {
    await _save('hapticFeedback', value);
    state = state.copyWith(hapticFeedback: value);
  }

  Future<void> setSoundEffects(bool value) async {
    await _save('soundEffects', value);
    state = state.copyWith(soundEffects: value);
  }

  Future<void> setShowStreakCard(bool value) async {
    await _save('showStreakCard', value);
    state = state.copyWith(showStreakCard: value);
  }

  Future<void> setShowMomentumCard(bool value) async {
    await _save('showMomentumCard', value);
    state = state.copyWith(showMomentumCard: value);
  }

  Future<void> setShowWeeklyGraph(bool value) async {
    await _save('showWeeklyGraph', value);
    state = state.copyWith(showWeeklyGraph: value);
  }

  Future<void> setShowQuotes(bool value) async {
    await _save('showQuotes', value);
    state = state.copyWith(showQuotes: value);
  }

  Future<void> setCompactDashboardMode(bool value) async {
    await _save('compactDashboardMode', value);
    state = state.copyWith(compactDashboardMode: value);
  }

  Future<void> setRequireBiometrics(bool value) async {
    await _save('requireBiometrics', value);
    state = state.copyWith(requireBiometrics: value);
  }

  Future<void> setLockInactivity(String value) async {
    await _save('lockInactivity', value);
    state = state.copyWith(lockInactivity: value);
  }

  Future<void> setHideSensitiveStats(bool value) async {
    await _save('hideSensitiveStats', value);
    state = state.copyWith(hideSensitiveStats: value);
  }

  Future<void> setEnableDebugTools(bool value) async {
    await _save('enableDebugTools', value);
    state = state.copyWith(enableDebugTools: value);
  }

  Future<void> setEnableExperimentalFeatures(bool value) async {
    await _save('enableExperimentalFeatures', value);
    state = state.copyWith(enableExperimentalFeatures: value);
  }

  Future<void> setNotificationSound(String uri, String name) async {
    await _save('notificationSoundUri', uri);
    await _save('notificationSoundName', name);
    state = state.copyWith(
      notificationSoundUri: uri,
      notificationSoundName: name,
    );
    await _ref.read(notificationServiceProvider).updateNotificationChannel();
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    await _save('dailyReminderHour', hour);
    await _save('dailyReminderMinute', minute);
    state = state.copyWith(
      dailyReminderHour: hour,
      dailyReminderMinute: minute,
    );
  }

  Future<void> setCustomSessionCompleteSound(String path) async {
    await _save('customSessionCompleteSound', path);
    state = state.copyWith(customSessionCompleteSound: path);
  }

  Future<void> setCustomGoalCompleteSound(String path) async {
    await _save('customGoalCompleteSound', path);
    state = state.copyWith(customGoalCompleteSound: path);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs, ref);
});
