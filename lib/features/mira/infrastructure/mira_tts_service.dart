import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/mira_state.dart';
import '../domain/mira_voice_provider.dart';

/// Pluggable Text-To-Speech Service for MIRA
class MiraTtsService {
  MiraTtsProvider? _provider;
  bool _isSpeaking = false;
  Timer? _simulatedWaveTimer;

  bool get isSpeaking => _isSpeaking;
  bool get isConfigured => _provider?.isReady ?? false;

  /// Register custom TTS provider (e.g. ElevenLabs, Google Cloud TTS, Azure Neural)
  void registerProvider(MiraTtsProvider provider) {
    _provider = provider;
  }

  /// Speaks text with specified female voice matching language
  Future<void> speak({
    required String text,
    required MiraLanguage language,
    void Function(double amplitude)? onAmplitude,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    await stop();
    _isSpeaking = true;

    if (_provider != null && _provider!.isReady) {
      try {
        await _provider!.speak(
          text: text,
          language: language,
          onAmplitude: onAmplitude,
          onComplete: () {
            _isSpeaking = false;
            onComplete?.call();
          },
          onError: () {
            _isSpeaking = false;
            onError?.call();
          },
        );
        return;
      } catch (e) {
        debugPrint('Custom TTS provider failed: $e');
      }
    }

    // Default simulated speech wave when external TTS provider is not yet attached
    // This allows testing the visual dot-wave response rhythmically
    _startSimulatedSpeechWave(
      durationMs: min(4000, max(1500, text.length * 60)),
      onAmplitude: onAmplitude,
      onComplete: () {
        _isSpeaking = false;
        onComplete?.call();
      },
    );
  }

  void _startSimulatedSpeechWave({
    required int durationMs,
    void Function(double amplitude)? onAmplitude,
    VoidCallback? onComplete,
  }) {
    final start = DateTime.now();
    final random = Random();
    int tick = 0;

    _simulatedWaveTimer?.cancel();
    _simulatedWaveTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      if (elapsed >= durationMs || !_isSpeaking) {
        timer.cancel();
        _isSpeaking = false;
        onAmplitude?.call(0.0);
        onComplete?.call();
        return;
      }

      tick++;
      // Natural oscillating voice amplitude rhythm
      final base = 0.35 + 0.45 * sin(tick * 0.4).abs();
      final jitter = (random.nextDouble() - 0.5) * 0.15;
      final amp = (base + jitter).clamp(0.1, 0.95);
      onAmplitude?.call(amp);
    });
  }

  /// Immediately terminates TTS and wave synthesis
  Future<void> stop() async {
    _isSpeaking = false;
    _simulatedWaveTimer?.cancel();
    _simulatedWaveTimer = null;
    if (_provider != null) {
      await _provider!.stop();
    }
  }

  Future<void> pause() async {
    _simulatedWaveTimer?.cancel();
    if (_provider != null) {
      await _provider!.pause();
    }
  }
}
