import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../data/models/chocolate_finished_product_model.dart';
import 'chocolate_product_vocabulary_service.dart';

enum SpeechStatus {
  idle,
  initializing,
  listening,
  processing,
  completed,
  error,
  permissionDenied,
  notAvailable,
}

class SpeechLocaleOption {
  final String id;
  final String label;
  final String code;

  const SpeechLocaleOption({
    required this.id,
    required this.label,
    required this.code,
  });
}

class ChocolateSpeechService {
  static final ChocolateSpeechService _instance = ChocolateSpeechService._internal();
  factory ChocolateSpeechService() => _instance;
  ChocolateSpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final ChocolateProductVocabularyService _vocabService = ChocolateProductVocabularyService();

  bool _isInitialized = false;
  SpeechStatus _status = SpeechStatus.idle;
  String _currentWords = '';
  String? _errorMessage;
  double _soundLevel = 0.0;
  List<VocabularyMatchSuggestion> _suggestions = const [];
  ProductMatchResult? _currentMatchResult;

  // Available language choices for factory operators
  static const List<SpeechLocaleOption> supportedLocales = [
    SpeechLocaleOption(id: 'en_IN', label: 'English (India)', code: 'en_IN'),
    SpeechLocaleOption(id: 'ta_IN', label: 'தமிழ் (Tamil)', code: 'ta_IN'),
    SpeechLocaleOption(id: 'hi_IN', label: 'हिंदी (Hindi)', code: 'hi_IN'),
    SpeechLocaleOption(id: 'en_US', label: 'English (US)', code: 'en_US'),
  ];

  SpeechLocaleOption _selectedLocale = supportedLocales.first;

  // Listeners
  final ValueNotifier<SpeechStatus> statusNotifier = ValueNotifier(SpeechStatus.idle);
  final ValueNotifier<String> wordsNotifier = ValueNotifier('');
  final ValueNotifier<double> soundLevelNotifier = ValueNotifier(0.0);
  final ValueNotifier<List<VocabularyMatchSuggestion>> suggestionsNotifier = ValueNotifier(const []);
  final ValueNotifier<ProductMatchResult?> matchResultNotifier = ValueNotifier(null);

  SpeechStatus get status => _status;
  String get currentWords => _currentWords;
  String? get errorMessage => _errorMessage;
  double get soundLevel => _soundLevel;
  List<VocabularyMatchSuggestion> get suggestions => _suggestions;
  ProductMatchResult? get currentMatchResult => _currentMatchResult;
  SpeechLocaleOption get selectedLocale => _selectedLocale;
  bool get isListening => _status == SpeechStatus.listening;

  void setSelectedLocale(SpeechLocaleOption locale) {
    _selectedLocale = locale;
  }

  /// Initialize speech engine and verify permission
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _updateStatus(SpeechStatus.initializing);
    try {
      final available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );

      if (!available) {
        _errorMessage = 'Speech recognition is not available or microphone permission was denied.';
        _updateStatus(SpeechStatus.notAvailable);
        _isInitialized = false;
        return false;
      }

      // Pre-warm the vocabulary cache
      await _vocabService.loadVocabulary();

      _isInitialized = true;
      _updateStatus(SpeechStatus.idle);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize speech recognition: $e';
      _updateStatus(SpeechStatus.error);
      _isInitialized = false;
      return false;
    }
  }

  /// Resolve raw spoken utterance against authoritative product dataset
  ProductMatchResult resolveSpokenResult(String rawText) {
    return _vocabService.matchProduct(rawText);
  }

  /// Start listening for chocolate finished product name
  Future<bool> startListening({
    required Function(String text, List<VocabularyMatchSuggestion> suggestions) onResult,
    Duration listenFor = const Duration(seconds: 12),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    _currentWords = '';
    wordsNotifier.value = '';
    _suggestions = const [];
    suggestionsNotifier.value = const [];
    _currentMatchResult = null;
    matchResultNotifier.value = null;
    _errorMessage = null;
    _updateStatus(SpeechStatus.listening);

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _currentWords = result.recognizedWords;
          wordsNotifier.value = _currentWords;

          // Compute live suggestions & decision match from finished products catalog
          if (_currentWords.trim().isNotEmpty) {
            _currentMatchResult = _vocabService.matchProduct(_currentWords);
            _suggestions = _currentMatchResult!.candidates;
            matchResultNotifier.value = _currentMatchResult;
            suggestionsNotifier.value = _suggestions;
          }

          if (result.finalResult) {
            _updateStatus(SpeechStatus.completed);
            onResult(_currentWords, _suggestions);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: _selectedLocale.id,
        ),
        onSoundLevelChange: (level) {
          // Normalize level (roughly -30 dB to 10 dB) into 0.0 to 1.0 range
          final normalized = ((level + 30) / 40.0).clamp(0.0, 1.0);
          _soundLevel = normalized;
          soundLevelNotifier.value = normalized;
        },
      );
      return true;
    } catch (e) {
      _errorMessage = 'Microphone listening error: $e';
      _updateStatus(SpeechStatus.error);
      return false;
    }
  }

  /// Stop listening manually (e.g. user taps checkmark / stop button)
  Future<String> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _updateStatus(SpeechStatus.completed);
    return _currentWords;
  }

  /// Cancel listening and discard buffer
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _currentWords = '';
    wordsNotifier.value = '';
    _suggestions = const [];
    suggestionsNotifier.value = const [];
    _currentMatchResult = null;
    matchResultNotifier.value = null;
    _soundLevel = 0.0;
    soundLevelNotifier.value = 0.0;
    _updateStatus(SpeechStatus.idle);
  }

  void _onStatus(String sttStatus) {
    switch (sttStatus) {
      case 'listening':
        _updateStatus(SpeechStatus.listening);
        break;
      case 'notListening':
        if (_status == SpeechStatus.listening) {
          _updateStatus(SpeechStatus.completed);
        }
        break;
      case 'done':
        _updateStatus(SpeechStatus.completed);
        break;
    }
  }

  void _onError(SpeechRecognitionError errorNotification) {
    final msg = errorNotification.errorMsg.toLowerCase();
    debugPrint('Speech recognition error: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');

    if (msg.contains('permission')) {
      _errorMessage = 'Microphone permission denied. Please grant microphone access in device settings to use voice input.';
      _updateStatus(SpeechStatus.permissionDenied);
    } else if (msg.contains('no speech') || msg.contains('speech timeout') || msg.contains('error_no_match')) {
      _errorMessage = 'No speech detected. Please speak clearly into the microphone and try again.';
      _updateStatus(SpeechStatus.idle);
    } else if (msg.contains('network')) {
      _errorMessage = 'Network connection issue with speech service. Voice recognition will retry locally.';
      _updateStatus(SpeechStatus.error);
    } else {
      _errorMessage = 'Speech error: ${errorNotification.errorMsg}';
      _updateStatus(SpeechStatus.error);
    }
  }

  void _updateStatus(SpeechStatus newStatus) {
    _status = newStatus;
    statusNotifier.value = newStatus;
  }
}
