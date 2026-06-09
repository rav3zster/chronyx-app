import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService(ref);
});

class SoundService {
  final Ref _ref;
  AudioPlayer? _player;
  static SoundService? instance;
  DateTime? _lastPlayTime;

  SoundService(this._ref) {
    instance = this;
  }

  bool get _enabled => _ref.read(settingsProvider).soundEffects;

  Future<AudioPlayer> _getPlayer() async {
    _player ??= AudioPlayer();
    return _player!;
  }

  Future<void> _playAsset(String path) async {
    if (!_enabled) return;
    final now = DateTime.now();
    if (_lastPlayTime != null && now.difference(_lastPlayTime!).inMilliseconds < 60) {
      return;
    }
    _lastPlayTime = now;
    try {
      final player = await _getPlayer();
      await player.stop();
      await player.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> toggleSwitch() async {
    await _playAsset('sounds/toggle.wav');
  }

  Future<void> buttonPress() async {
    await _playAsset('sounds/click.wav');
  }

  Future<void> sessionComplete() async {
    final customPath = _ref.read(settingsProvider).customSessionCompleteSound;
    if (customPath.isNotEmpty) {
      await playCustom(customPath);
    } else {
      await _playAsset('sounds/success.wav');
    }
  }

  Future<void> goalComplete() async {
    final customPath = _ref.read(settingsProvider).customGoalCompleteSound;
    if (customPath.isNotEmpty) {
      await playCustom(customPath);
    } else {
      await _playAsset('sounds/reward.wav');
    }
  }

  Future<void> blueprintComplete() async {
    await _playAsset('sounds/celebrate.wav');
  }

  Future<void> playCustom(String path) async {
    if (!_enabled) return;
    try {
      final player = await _getPlayer();
      await player.stop();
      await player.play(DeviceFileSource(path));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
