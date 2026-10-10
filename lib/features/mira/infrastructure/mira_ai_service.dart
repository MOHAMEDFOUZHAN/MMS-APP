import '../domain/mira_ai_provider.dart';
import '../domain/mira_state.dart';

/// Language Detector for English, Tamil, and Tanglish
class MiraLanguageDetector {
  static final RegExp _tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
  static final List<RegExp> _tanglishPatterns = [
    RegExp(r'\bevlo\b', caseSensitive: false),
    RegExp(r'\birukku\b', caseSensitive: false),
    RegExp(r'\benna\b', caseSensitive: false),
    RegExp(r'\bstocku\b', caseSensitive: false),
    RegExp(r'\bpannunga\b', caseSensitive: false),
    RegExp(r'\bsollunga\b', caseSensitive: false),
    RegExp(r'\bkudunga\b', caseSensitive: false),
    RegExp(r'\bippo\b', caseSensitive: false),
    RegExp(r'\binnaiku\b', caseSensitive: false),
    RegExp(r'\binnikku\b', caseSensitive: false),
    RegExp(r'\benga\b', caseSensitive: false),
    RegExp(r'\bpaakanum\b', caseSensitive: false),
    RegExp(r'\bvarum\b', caseSensitive: false),
    RegExp(r'\bkitta\b', caseSensitive: false),
  ];

  static MiraLanguage detect(String text, {MiraLanguage userPreference = MiraLanguage.auto}) {
    if (userPreference != MiraLanguage.auto) {
      return userPreference;
    }

    if (_tamilRegex.hasMatch(text)) {
      return MiraLanguage.tamil;
    }

    for (final pattern in _tanglishPatterns) {
      if (pattern.hasMatch(text)) {
        return MiraLanguage.tanglish;
      }
    }

    return MiraLanguage.english;
  }
}

/// Core AI Service for MIRA
class MiraAIService {
  MiraAIProvider _provider = UnconfiguredMiraAIProvider();
  final List<MiraMessage> _sessionHistory = [];

  MiraAIProvider get provider => _provider;
  bool get isModelConnected => _provider.isConfigured;

  /// Hot-swappable provider registration for future LLM integration
  void registerProvider(MiraAIProvider newProvider) {
    _provider = newProvider;
  }

  /// Reset to unconfigured state
  void resetToDefault() {
    _provider = UnconfiguredMiraAIProvider();
  }

  /// Process query through the active AI provider
  Future<MiraAIResponse> processQuery(
    String queryText, {
    MiraLanguage preferredLanguage = MiraLanguage.auto,
  }) async {
    final detectedLang = MiraLanguageDetector.detect(queryText, userPreference: preferredLanguage);

    final query = MiraQuery(
      queryText: queryText,
      detectedLanguage: detectedLang,
      history: List.unmodifiable(_sessionHistory),
    );

    final response = await _provider.processQuery(query);

    // Keep session context
    _sessionHistory.add(MiraMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      text: queryText,
      isUser: true,
      timestamp: DateTime.now(),
      language: detectedLang,
    ));

    _sessionHistory.add(MiraMessage(
      id: 'mira-${DateTime.now().millisecondsSinceEpoch}',
      text: response.text,
      isUser: false,
      timestamp: DateTime.now(),
      language: response.language,
      structuredData: response.structuredData,
      isSetupPrompt: !response.isModelConfigured,
    ));

    return response;
  }

  void clearSession() {
    _sessionHistory.clear();
  }
}
