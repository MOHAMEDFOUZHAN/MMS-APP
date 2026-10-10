import 'package:flutter/foundation.dart';
import 'mira_state.dart';

/// Pluggable Text-To-Speech Provider interface
abstract class MiraTtsProvider {
  String get providerId;
  String get displayName;
  bool get isReady;

  /// Speaks text with specified language and voice
  Future<void> speak({
    required String text,
    required MiraLanguage language,
    void Function(double amplitude)? onAmplitude,
    VoidCallback? onComplete,
    VoidCallback? onError,
  });

  /// Immediately terminates speech
  Future<void> stop();

  /// Pauses speech
  Future<void> pause();
}

/// Pluggable Speech-To-Text Provider interface
abstract class MiraSttProvider {
  String get providerId;
  String get displayName;
  bool get isListening;

  /// Initializes microphone permissions and engine
  Future<bool> initialize();

  /// Starts listening for speech
  Future<void> startListening({
    required MiraLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(double amplitude) onAmplitude,
    required void Function(String error) onError,
  });

  /// Stops active listening
  Future<void> stopListening();
}
