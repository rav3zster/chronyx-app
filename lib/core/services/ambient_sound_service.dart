import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Ambient Sound Types ──────────────────────────────────────────────────────

enum AmbientSound {
  none,
  rain,
  cafe,
  whiteNoise,
  brownNoise,
  forest,
  ocean,
  fireplace,
  wind;

  String get label => switch (this) {
    AmbientSound.none => 'None',
    AmbientSound.rain => 'Rain',
    AmbientSound.cafe => 'Café',
    AmbientSound.whiteNoise => 'White Noise',
    AmbientSound.brownNoise => 'Brown Noise',
    AmbientSound.forest => 'Forest',
    AmbientSound.ocean => 'Ocean',
    AmbientSound.fireplace => 'Fireplace',
    AmbientSound.wind => 'Wind',
  };

  String get emoji => switch (this) {
    AmbientSound.none => '🔇',
    AmbientSound.rain => '🌧️',
    AmbientSound.cafe => '☕',
    AmbientSound.whiteNoise => '〰️',
    AmbientSound.brownNoise => '🎶',
    AmbientSound.forest => '🌲',
    AmbientSound.ocean => '🌊',
    AmbientSound.fireplace => '🔥',
    AmbientSound.wind => '💨',
  };

  /// Asset path relative to assets/sounds/
  String? get assetPath => switch (this) {
    AmbientSound.none => null,
    AmbientSound.rain => 'sounds/ambient/rain.mp3',
    AmbientSound.cafe => 'sounds/ambient/cafe.mp3',
    AmbientSound.whiteNoise => 'sounds/ambient/white_noise.mp3',
    AmbientSound.brownNoise => 'sounds/ambient/brown_noise.mp3',
    AmbientSound.forest => 'sounds/ambient/forest.mp3',
    AmbientSound.ocean => 'sounds/ambient/ocean.mp3',
    AmbientSound.fireplace => 'sounds/ambient/fireplace.mp3',
    AmbientSound.wind => 'sounds/ambient/wind.mp3',
  };

  String get jsonKey => name;

  static AmbientSound fromJson(String? value) => switch (value) {
    'rain' => AmbientSound.rain,
    'cafe' => AmbientSound.cafe,
    'whiteNoise' => AmbientSound.whiteNoise,
    'brownNoise' => AmbientSound.brownNoise,
    'forest' => AmbientSound.forest,
    'ocean' => AmbientSound.ocean,
    'fireplace' => AmbientSound.fireplace,
    'wind' => AmbientSound.wind,
    _ => AmbientSound.none,
  };
}

// ── Ambient State ────────────────────────────────────────────────────────────

class AmbientState {
  const AmbientState({
    this.activeSound = AmbientSound.none,
    this.volume = 0.5,
    this.isPlaying = false,
  });

  final AmbientSound activeSound;
  final double volume;
  final bool isPlaying;

  AmbientState copyWith({
    AmbientSound? activeSound,
    double? volume,
    bool? isPlaying,
  }) =>
      AmbientState(
        activeSound: activeSound ?? this.activeSound,
        volume: volume ?? this.volume,
        isPlaying: isPlaying ?? this.isPlaying,
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final ambientSoundServiceProvider =
    AsyncNotifierProvider<AmbientSoundService, AmbientState>(
  AmbientSoundService.new,
);

// ── Service ──────────────────────────────────────────────────────────────────

class AmbientSoundService extends AsyncNotifier<AmbientState> {
  AudioPlayer? _player;

  static const _keySound = 'ambient_sound';
  static const _keyVolume = 'ambient_volume';

  @override
  Future<AmbientState> build() async {
    ref.onDispose(_disposePlayer);

    final prefs = await SharedPreferences.getInstance();
    final sound = AmbientSound.fromJson(prefs.getString(_keySound));
    final volume = prefs.getDouble(_keyVolume) ?? 0.5;

    return AmbientState(activeSound: sound, volume: volume, isPlaying: false);
  }

  Future<void> play(AmbientSound sound) async {
    final current = state.valueOrNull ?? const AmbientState();
    if (current.activeSound == sound && current.isPlaying) {
      // toggle off
      await stop();
      return;
    }

    final path = sound.assetPath;
    if (path == null || sound == AmbientSound.none) {
      await stop();
      return;
    }

    try {
      await _disposePlayer();
      _player = AudioPlayer();
      await _player!.setVolume(current.volume);
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource(path));
      state = AsyncData(current.copyWith(activeSound: sound, isPlaying: true));
      await _persist(sound, current.volume);
    } catch (e) {
      debugPrint('[AMBIENT] play error: $e');
    }
  }

  Future<void> stop() async {
    await _disposePlayer();
    final current = state.valueOrNull ?? const AmbientState();
    state = AsyncData(current.copyWith(isPlaying: false));
  }

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    await _player?.setVolume(v);
    final current = state.valueOrNull ?? const AmbientState();
    state = AsyncData(current.copyWith(volume: v));
    await _persist(current.activeSound, v);
  }

  Future<void> pauseAmbient() async {
    await _player?.pause();
    final current = state.valueOrNull ?? const AmbientState();
    state = AsyncData(current.copyWith(isPlaying: false));
  }

  Future<void> resumeAmbient() async {
    final current = state.valueOrNull ?? const AmbientState();
    if (current.activeSound == AmbientSound.none) return;
    try {
      await _player?.resume();
      state = AsyncData(current.copyWith(isPlaying: true));
    } catch (e) {
      // player may have been disposed; re-play
      await play(current.activeSound);
    }
  }

  Future<void> _disposePlayer() async {
    await _player?.stop();
    await _player?.dispose();
    _player = null;
  }

  Future<void> _persist(AmbientSound sound, double volume) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySound, sound.jsonKey);
      await prefs.setDouble(_keyVolume, volume);
    } catch (_) {}
  }
}
