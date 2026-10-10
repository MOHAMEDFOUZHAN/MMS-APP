import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/mira_state.dart';
import '../domain/mira_voice_provider.dart';

/// Pluggable Speech-To-Text Service for MIRA
class MiraSpeechRecognitionService {
  MiraSttProvider? _provider;
  bool _isListening = false;
  Timer? _listeningAmplitudeTimer;

  bool get isListening => _isListening;
  bool get isConfigured => _provider != null;

  /// Register custom STT provider (e.g. Whisper, Google Cloud Speech, Device STT)
  void registerProvider(MiraSttProvider provider) {
    _provider = provider;
  }

  /// Request microphone permission on demand and begin listening
  Future<bool> startListening({
    required MiraLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(double amplitude) onAmplitude,
    required void Function(String error) onError,
  }) async {
    await stopListening();
    _isListening = true;

    if (_provider != null) {
      try {
        final ready = await _provider!.initialize();
        if (!ready) {
          _isListening = false;
          onError('Microphone permission or voice engine unavailable.');
          return false;
        }

        await _provider!.startListening(
          language: language,
          onResult: onResult,
          onAmplitude: onAmplitude,
          onError: (err) {
            _isListening = false;
            onError(err);
          },
        );
        return true;
      } catch (e) {
        debugPrint('Custom STT provider error: $e');
      }
    }

    // Default listening mode with simulated microphone sensitivity
    // allows previewing dynamic dot-wave reactivity when microphone hardware is not yet initialized
    _startSimulatedListeningAmplitude(onAmplitude: onAmplitude);
    return true;
  }

  void _startSimulatedListeningAmplitude({required void Function(double amplitude) onAmplitude}) {
    final random = Random();
    int tick = 0;
    _listeningAmplitudeTimer?.cancel();
    _listeningAmplitudeTimer = Timer.periodic(const Duration(milliseconds: 75), (timer) {
      if (!_isListening) {
        timer.cancel();
        onAmplitude(0.0);
        return;
      }
      tick++;
      // Organic voice energy fluctuations
      final amp = (0.25 + 0.55 * sin(tick * 0.3).abs() + (random.nextDouble() * 0.2)).clamp(0.05, 0.95);
      onAmplitude(amp);
    });
  }

  /// Immediately terminates listening session
  Future<void> stopListening() async {
    _isListening = false;
    _listeningAmplitudeTimer?.cancel();
    _listeningAmplitudeTimer = null;
    if (_provider != null) {
      await _provider!.stopListening();
    }
  }
}
