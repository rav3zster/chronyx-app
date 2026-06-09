import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:chronyx/core/widgets/biometric_gate.dart';

final inactivityLockProvider = ChangeNotifierProvider<InactivityLock>((ref) {
  final lock = InactivityLock(ref);
  ref.onDispose(() => lock.dispose());
  return lock;
});

class InactivityLock with WidgetsBindingObserver implements ChangeNotifier {
  final Ref _ref;
  Timer? _inactivityTimer;
  DateTime? _lastActiveTime;
  final List<VoidCallback> _listeners = [];

  InactivityLock(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    _lastActiveTime = DateTime.now();
    _updateTimer();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isInBackground = true;
      _lastActiveTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _checkIfShouldLock();
      _updateTimer();
    }
  }

  void _updateTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkInactivity();
    });
  }

  void _checkIfShouldLock() {
    if (_lastActiveTime == null) return;

    final settings = _ref.read(settingsProvider);
    if (!settings.requireBiometrics) return;

    final durationStr = settings.lockInactivity;
    if (durationStr == 'Never') return;

    final elapsed = DateTime.now().difference(_lastActiveTime!);
    final maxDuration = _parseDuration(durationStr);
    if (maxDuration == null) return;

    if (elapsed >= maxDuration) {
      _ref.read(biometricGateNotifierProvider.notifier).lock();
    }
  }

  void _checkInactivity() {
    if (!_isInBackground) {
      final settings = _ref.read(settingsProvider);
      if (!settings.requireBiometrics) return;

      final durationStr = settings.lockInactivity;
      if (durationStr == 'Never') return;

      if (_lastActiveTime == null) {
        _lastActiveTime = DateTime.now();
        return;
      }

      final elapsed = DateTime.now().difference(_lastActiveTime!);
      final maxDuration = _parseDuration(durationStr);
      if (maxDuration == null) return;

      if (elapsed >= maxDuration) {
        _ref.read(biometricGateNotifierProvider.notifier).lock();
      }
    }
  }

  bool _isInBackground = false;

  Duration? _parseDuration(String value) {
    return switch (value) {
      '1 minute' => const Duration(minutes: 1),
      '5 minutes' => const Duration(minutes: 5),
      '15 minutes' => const Duration(minutes: 15),
      _ => null,
    };
  }

  void notifyActivity() {
    _lastActiveTime = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
  }
}
