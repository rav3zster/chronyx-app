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
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final dailyReminder = _prefs.getBool('dailyReminder') ?? true;
    final sessionCompleteNotify = _prefs.getBool('sessionCompleteNotify') ?? true;
    final goalDeadlineNotify = _prefs.getBool('goalDeadlineNotify') ?? true;
    final weeklySummaryNotify = _prefs.getBool('weeklySummaryNotify') ?? true;
    final themeVariantStr = _prefs.getString('themeVariant') ?? AppThemeVariant.warmMinimal.name;
    final themeVariant = AppThemeVariant.values.firstWhere(
      (e) => e.name == themeVariantStr,
      orElse: () => AppThemeVariant.warmMinimal,
    );
    final amoledMode = _prefs.getBool('amoledMode') ?? false;
    final focusDuration = _prefs.getInt('focusDuration') ?? 25;
    final breakDuration = _prefs.getInt('breakDuration') ?? 5;
    final autoStartBreaks = _prefs.getBool('autoStartBreaks') ?? false;
    final autoStartNextSession = _prefs.getBool('autoStartNextSession') ?? false;
    final hapticFeedback = _prefs.getBool('hapticFeedback') ?? true;
    final soundEffects = _prefs.getBool('soundEffects') ?? true;
    final showStreakCard = _prefs.getBool('showStreakCard') ?? true;
    final showMomentumCard = _prefs.getBool('showMomentumCard') ?? true;
    final showWeeklyGraph = _prefs.getBool('showWeeklyGraph') ?? true;
    final showQuotes = _prefs.getBool('showQuotes') ?? true;
    final compactDashboardMode = _prefs.getBool('compactDashboardMode') ?? false;
    final requireBiometrics = _prefs.getBool('requireBiometrics') ?? false;
    final lockInactivity = _prefs.getString('lockInactivity') ?? 'Never';
    final hideSensitiveStats = _prefs.getBool('hideSensitiveStats') ?? false;
    final enableDebugTools = _prefs.getBool('enableDebugTools') ?? false;
    final enableExperimentalFeatures = _prefs.getBool('enableExperimentalFeatures') ?? false;

    state = SettingsState(
      dailyReminder: dailyReminder,
      sessionCompleteNotify: sessionCompleteNotify,
      goalDeadlineNotify: goalDeadlineNotify,
      weeklySummaryNotify: weeklySummaryNotify,
      themeVariant: themeVariant,
      amoledMode: amoledMode,
      focusDuration: focusDuration,
      breakDuration: breakDuration,
      autoStartBreaks: autoStartBreaks,
      autoStartNextSession: autoStartNextSession,
      hapticFeedback: hapticFeedback,
      soundEffects: soundEffects,
      showStreakCard: showStreakCard,
      showMomentumCard: showMomentumCard,
      showWeeklyGraph: showWeeklyGraph,
      showQuotes: showQuotes,
      compactDashboardMode: compactDashboardMode,
      requireBiometrics: requireBiometrics,
      lockInactivity: lockInactivity,
      hideSensitiveStats: hideSensitiveStats,
      enableDebugTools: enableDebugTools,
      enableExperimentalFeatures: enableExperimentalFeatures,
    );
  }

  Future<void> setDailyReminder(bool value) async {
    await _prefs.setBool('dailyReminder', value);
    state = state.copyWith(dailyReminder: value);
  }

  Future<void> setSessionCompleteNotify(bool value) async {
    await _prefs.setBool('sessionCompleteNotify', value);
    state = state.copyWith(sessionCompleteNotify: value);
  }

  Future<void> setGoalDeadlineNotify(bool value) async {
    await _prefs.setBool('goalDeadlineNotify', value);
    state = state.copyWith(goalDeadlineNotify: value);
  }

  Future<void> setWeeklySummaryNotify(bool value) async {
    await _prefs.setBool('weeklySummaryNotify', value);
    state = state.copyWith(weeklySummaryNotify: value);
  }

  Future<void> setThemeVariant(AppThemeVariant value) async {
    await _prefs.setString('themeVariant', value.name);
    state = state.copyWith(themeVariant: value);
  }

  Future<void> setAmoledMode(bool value) async {
    await _prefs.setBool('amoledMode', value);
    state = state.copyWith(amoledMode: value);
  }

  Future<void> setFocusDuration(int value) async {
    await _prefs.setInt('focusDuration', value);
    state = state.copyWith(focusDuration: value);
  }

  Future<void> setBreakDuration(int value) async {
    await _prefs.setInt('breakDuration', value);
    state = state.copyWith(breakDuration: value);
  }

  Future<void> setAutoStartBreaks(bool value) async {
    await _prefs.setBool('autoStartBreaks', value);
    state = state.copyWith(autoStartBreaks: value);
  }

  Future<void> setAutoStartNextSession(bool value) async {
    await _prefs.setBool('autoStartNextSession', value);
    state = state.copyWith(autoStartNextSession: value);
  }

  Future<void> setHapticFeedback(bool value) async {
    await _prefs.setBool('hapticFeedback', value);
    state = state.copyWith(hapticFeedback: value);
  }

  Future<void> setSoundEffects(bool value) async {
    await _prefs.setBool('soundEffects', value);
    state = state.copyWith(soundEffects: value);
  }

  Future<void> setShowStreakCard(bool value) async {
    await _prefs.setBool('showStreakCard', value);
    state = state.copyWith(showStreakCard: value);
  }

  Future<void> setShowMomentumCard(bool value) async {
    await _prefs.setBool('showMomentumCard', value);
    state = state.copyWith(showMomentumCard: value);
  }

  Future<void> setShowWeeklyGraph(bool value) async {
    await _prefs.setBool('showWeeklyGraph', value);
    state = state.copyWith(showWeeklyGraph: value);
  }

  Future<void> setShowQuotes(bool value) async {
    await _prefs.setBool('showQuotes', value);
    state = state.copyWith(showQuotes: value);
  }

  Future<void> setCompactDashboardMode(bool value) async {
    await _prefs.setBool('compactDashboardMode', value);
    state = state.copyWith(compactDashboardMode: value);
  }

  Future<void> setRequireBiometrics(bool value) async {
    await _prefs.setBool('requireBiometrics', value);
    state = state.copyWith(requireBiometrics: value);
  }

  Future<void> setLockInactivity(String value) async {
    await _prefs.setString('lockInactivity', value);
    state = state.copyWith(lockInactivity: value);
  }

  Future<void> setHideSensitiveStats(bool value) async {
    await _prefs.setBool('hideSensitiveStats', value);
    state = state.copyWith(hideSensitiveStats: value);
  }

  Future<void> setEnableDebugTools(bool value) async {
    await _prefs.setBool('enableDebugTools', value);
    state = state.copyWith(enableDebugTools: value);
  }

  Future<void> setEnableExperimentalFeatures(bool value) async {
    await _prefs.setBool('enableExperimentalFeatures', value);
    state = state.copyWith(enableExperimentalFeatures: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
