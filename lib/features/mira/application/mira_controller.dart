import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/mira_state.dart';
import '../infrastructure/gemini_mira_provider.dart';
import '../infrastructure/mira_ai_service.dart';
import '../infrastructure/mira_tts_service.dart';
import '../infrastructure/speech_recognition_service.dart';

const String _kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Riverpod Provider for MIRA Controller
final miraControllerProvider = StateNotifierProvider<MiraController, MiraState>((ref) {
  final aiService = MiraAIService();
  if (_kGeminiApiKey.isNotEmpty) {
    aiService.registerProvider(GeminiMiraAIProvider(apiKey: _kGeminiApiKey));
  }
  return MiraController(
    aiService: aiService,
    ttsService: MiraTtsService(),
    sttService: MiraSpeechRecognitionService(),
  );
});

class MiraController extends StateNotifier<MiraState> {
  final MiraAIService _aiService;
  final MiraTtsService _ttsService;
  final MiraSpeechRecognitionService _sttService;

  MiraController({
    required MiraAIService aiService,
    required MiraTtsService ttsService,
    required MiraSpeechRecognitionService sttService,
  })  : _aiService = aiService,
        _ttsService = ttsService,
        _sttService = sttService,
        super(MiraState(
          isModelConnected: aiService.isModelConnected,
          statusMessage: 'Ready when you are.',
        ));

  /// Submit a typed question to MIRA
  Future<void> submitTextQuery(String queryText) async {
    final clean = queryText.trim();
    if (clean.isEmpty) return;

    // Interrupt any active voice playback
    await stopSpeaking();

    // 1. Add user message and set PROCESSING state
    final userMsg = MiraMessage(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      text: clean,
      isUser: true,
      timestamp: DateTime.now(),
      language: state.language,
    );

    state = state.copyWith(
      mode: MiraStateMode.processing,
      statusMessage: 'Thinking...',
      errorMessage: null,
      messages: [...state.messages, userMsg],
    );

    try {
      // 2. Process query via AI service
      final response = await _aiService.processQuery(
        clean,
        preferredLanguage: state.language,
      );

      final miraMsg = MiraMessage(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        language: response.language,
        structuredData: response.structuredData,
        isSetupPrompt: !response.isModelConfigured,
      );

      // 3. Transition to RESPONDING / SPEAKING
      if (state.isVoiceEnabled && response.spokenText != null && response.spokenText!.isNotEmpty) {
        state = state.copyWith(
          mode: MiraStateMode.speaking,
          statusMessage: 'Speaking...',
          messages: [...state.messages, miraMsg],
          currentSpokenMessageId: miraMsg.id,
        );

        await _ttsService.speak(
          text: response.spokenText!,
          language: response.language,
          onAmplitude: (amp) {
            if (state.mode == MiraStateMode.speaking) {
              state = state.copyWith(audioAmplitude: amp);
            }
          },
          onComplete: () {
            state = state.copyWith(
              mode: MiraStateMode.idle,
              statusMessage: 'Ready when you are.',
              audioAmplitude: 0.0,
              currentSpokenMessageId: null,
            );
          },
          onError: () {
            state = state.copyWith(
              mode: MiraStateMode.idle,
              statusMessage: 'Ready when you are.',
              audioAmplitude: 0.0,
              currentSpokenMessageId: null,
            );
          },
        );
      } else {
        state = state.copyWith(
          mode: MiraStateMode.idle,
          statusMessage: 'Ready when you are.',
          messages: [...state.messages, miraMsg],
        );
      }
    } catch (e) {
      state = state.copyWith(
        mode: MiraStateMode.error,
        statusMessage: 'Something went wrong.',
        errorMessage: 'Unable to process query: $e',
        audioAmplitude: 0.0,
      );
    }
  }

  /// Start voice input session
  Future<void> startVoiceInput() async {
    // Barge-in: interrupt speech if MIRA is speaking
    await stopSpeaking();

    state = state.copyWith(
      mode: MiraStateMode.listening,
      statusMessage: 'Listening...',
      audioAmplitude: 0.15,
      errorMessage: null,
    );

    final started = await _sttService.startListening(
      language: state.language,
      onResult: (text, isFinal) {
        if (isFinal && text.trim().isNotEmpty) {
          stopVoiceInput(recognizedQuery: text.trim());
        }
      },
      onAmplitude: (amp) {
        if (state.mode == MiraStateMode.listening) {
          state = state.copyWith(audioAmplitude: amp);
        }
      },
      onError: (err) {
        state = state.copyWith(
          mode: MiraStateMode.error,
          statusMessage: 'Something went wrong.',
          errorMessage: err,
          audioAmplitude: 0.0,
        );
      },
    );

    if (!started) {
      state = state.copyWith(
        mode: MiraStateMode.idle,
        statusMessage: 'Ready when you are.',
        audioAmplitude: 0.0,
      );
    }
  }

  /// Stop voice input session
  Future<void> stopVoiceInput({String? recognizedQuery}) async {
    await _sttService.stopListening();
    state = state.copyWith(audioAmplitude: 0.0);

    if (recognizedQuery != null && recognizedQuery.isNotEmpty) {
      await submitTextQuery(recognizedQuery);
    } else {
      state = state.copyWith(
        mode: MiraStateMode.idle,
        statusMessage: 'Ready when you are.',
      );
    }
  }

  /// Stop active speech immediately and return wave to idle
  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    if (state.mode == MiraStateMode.speaking) {
      state = state.copyWith(
        mode: MiraStateMode.idle,
        statusMessage: 'Ready when you are.',
        audioAmplitude: 0.0,
        currentSpokenMessageId: null,
      );
    }
  }

  /// Toggle speech voice playback ON/OFF
  void toggleVoiceMode() {
    final next = !state.isVoiceEnabled;
    if (!next) {
      stopSpeaking();
    }
    state = state.copyWith(isVoiceEnabled: next);
  }

  /// Change language preference (Auto, English, Tamil, Tanglish)
  void setLanguage(MiraLanguage lang) {
    state = state.copyWith(language: lang);
  }

  /// Retry after error
  void retry() {
    state = state.copyWith(
      mode: MiraStateMode.idle,
      statusMessage: 'Ready when you are.',
      errorMessage: null,
      audioAmplitude: 0.0,
    );
  }

  /// Reset conversation session
  void clearSession() {
    stopSpeaking();
    _aiService.clearSession();
    state = state.copyWith(
      mode: MiraStateMode.idle,
      statusMessage: 'Ready when you are.',
      messages: [],
      errorMessage: null,
      audioAmplitude: 0.0,
    );
  }

  @override
  void dispose() {
    _ttsService.stop();
    _sttService.stopListening();
    super.dispose();
  }
}
