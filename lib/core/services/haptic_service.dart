import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});

class HapticService {
  final Ref _ref;

  HapticService(this._ref);

  bool get _enabled => _ref.read(settingsProvider).hapticFeedback;

  Future<void> lightImpact() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> mediumImpact() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> heavyImpact() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> vibrate() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  Future<void> buttonPress() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> toggleSwitch() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> sessionComplete() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  Future<void> goalComplete() async {
    if (!_enabled) return;
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }
}
