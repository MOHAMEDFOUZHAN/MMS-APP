import 'package:flutter/foundation.dart';

/// Operational modes for MIRA's state machine
enum MiraStateMode {
  idle,
  listening,
  processing,
  responding,
  speaking,
  error,
}

/// Language preference and detection for MIRA
enum MiraLanguage {
  auto,
  english,
  tamil,
  tanglish;

  String get label {
    switch (this) {
      case MiraLanguage.auto:
        return 'Auto';
      case MiraLanguage.english:
        return 'EN';
      case MiraLanguage.tamil:
        return 'தமிழ்';
      case MiraLanguage.tanglish:
        return 'Tanglish';
    }
  }

  String get displayName {
    switch (this) {
      case MiraLanguage.auto:
        return 'Automatic';
      case MiraLanguage.english:
        return 'English';
      case MiraLanguage.tamil:
        return 'Tamil (தமிழ்)';
      case MiraLanguage.tanglish:
        return 'Tanglish';
    }
  }
}

/// Message model for MIRA conversations
@immutable
class MiraMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MiraLanguage language;
  final Map<String, dynamic>? structuredData;
  final bool isPlayingVoice;
  final bool isSetupPrompt;

  const MiraMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.language = MiraLanguage.english,
    this.structuredData,
    this.isPlayingVoice = false,
    this.isSetupPrompt = false,
  });

  MiraMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    MiraLanguage? language,
    Map<String, dynamic>? structuredData,
    bool? isPlayingVoice,
    bool? isSetupPrompt,
  }) {
    return MiraMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      language: language ?? this.language,
      structuredData: structuredData ?? this.structuredData,
      isPlayingVoice: isPlayingVoice ?? this.isPlayingVoice,
      isSetupPrompt: isSetupPrompt ?? this.isSetupPrompt,
    );
  }
}

/// Root state for MIRA AI Assistant
@immutable
class MiraState {
  final MiraStateMode mode;
  final MiraLanguage language;
  final bool isVoiceEnabled;
  final double audioAmplitude; // 0.0 to 1.0 for dynamic dot-wave reactivity
  final String statusMessage;
  final String? errorMessage;
  final bool isModelConnected;
  final bool isTtsConnected;
  final List<MiraMessage> messages;
  final String? currentSpokenMessageId;

  const MiraState({
    this.mode = MiraStateMode.idle,
    this.language = MiraLanguage.auto,
    this.isVoiceEnabled = true,
    this.audioAmplitude = 0.0,
    this.statusMessage = 'Ready when you are.',
    this.errorMessage,
    this.isModelConnected = false,
    this.isTtsConnected = false,
    this.messages = const [],
    this.currentSpokenMessageId,
  });

  MiraState copyWith({
    MiraStateMode? mode,
    MiraLanguage? language,
    bool? isVoiceEnabled,
    double? audioAmplitude,
    String? statusMessage,
    String? errorMessage,
    bool? isModelConnected,
    bool? isTtsConnected,
    List<MiraMessage>? messages,
    String? currentSpokenMessageId,
  }) {
    return MiraState(
      mode: mode ?? this.mode,
      language: language ?? this.language,
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      audioAmplitude: audioAmplitude ?? this.audioAmplitude,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
      isModelConnected: isModelConnected ?? this.isModelConnected,
      isTtsConnected: isTtsConnected ?? this.isTtsConnected,
      messages: messages ?? this.messages,
      currentSpokenMessageId: currentSpokenMessageId,
    );
  }
}
