import 'mira_state.dart';

/// Structured request for MIRA AI
class MiraQuery {
  final String queryText;
  final MiraLanguage detectedLanguage;
  final List<MiraMessage> history;
  final Map<String, dynamic>? sessionContext;

  const MiraQuery({
    required this.queryText,
    required this.detectedLanguage,
    this.history = const [],
    this.sessionContext,
  });
}

/// Structured response from MIRA AI
class MiraAIResponse {
  final String text;
  final MiraLanguage language;
  final String? spokenText;
  final Map<String, dynamic>? structuredData;
  final List<String> referencedTools;
  final bool isModelConfigured;

  const MiraAIResponse({
    required this.text,
    required this.language,
    this.spokenText,
    this.structuredData,
    this.referencedTools = const [],
    this.isModelConfigured = true,
  });
}

/// Pluggable AI Provider Interface for MIRA
/// Allows connecting any LLM API provider without refactoring the MIRA engine.
abstract class MiraAIProvider {
  String get providerId;
  String get providerDisplayName;
  bool get isConfigured;

  /// Process natural language query with available authorized inventory tools
  Future<MiraAIResponse> processQuery(MiraQuery query);
}

/// Default Unconfigured Provider indicating the setup state
/// as explicitly required by Rule 4: "No Fake AI"
class UnconfiguredMiraAIProvider implements MiraAIProvider {
  @override
  String get providerId => 'unconfigured';

  @override
  String get providerDisplayName => 'Pending Model Connection';

  @override
  bool get isConfigured => false;

  @override
  Future<MiraAIResponse> processQuery(MiraQuery query) async {
    // Return honest setup state
    final isTamil = query.detectedLanguage == MiraLanguage.tamil;

    final message = isTamil
        ? 'MIRA தயாராக உள்ளது.\nஅறிவார்ந்த பதில்களைப் பெற AI மாதிரியை இணைக்கவும்.'
        : 'MIRA is ready.\nConnect the AI model to activate intelligent responses.';

    return MiraAIResponse(
      text: message,
      language: query.detectedLanguage,
      spokenText: message,
      isModelConfigured: false,
      structuredData: {
        'title': 'AI MODEL SETUP REQUIRED',
        'status': 'Awaiting API Key & Endpoint Configuration',
        'tools_ready': [
          'Material Master & Live Stock',
          'Batch & Lot Allocation',
          'Expiry & Reorder Tracking',
          'Invoices & Dispatches Summary',
          'Storage & Transfers Ledger',
        ],
      },
    );
  }
}
