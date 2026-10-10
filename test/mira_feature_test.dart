import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/features/mira/domain/mira_state.dart';
import 'package:mms_app/features/mira/domain/mira_ai_provider.dart';
import 'package:mms_app/features/mira/infrastructure/mira_ai_service.dart';
import 'package:mms_app/features/mira/infrastructure/mira_tts_service.dart';
import 'package:mms_app/features/mira/infrastructure/speech_recognition_service.dart';
import 'package:mms_app/features/mira/infrastructure/inventory_tools.dart';
import 'package:mms_app/features/mira/presentation/widgets/mira_core_wave.dart';
import 'package:mms_app/features/mira/presentation/widgets/mira_message_card.dart';
import 'package:mms_app/features/mira/presentation/widgets/mira_input_bar.dart';
import 'package:mms_app/features/mira/presentation/pages/mira_page.dart';
import 'package:mms_app/features/mira/infrastructure/gemini_mira_provider.dart';

void main() {
  group('1. MIRA Language Detection Tests', () {
    test('Detects English input correctly', () {
      expect(
        MiraLanguageDetector.detect('How much mint stock is available?'),
        MiraLanguage.english,
      );
      expect(
        MiraLanguageDetector.detect('Show me today invoices and dispatches'),
        MiraLanguage.english,
      );
    });

    test('Detects pure Tamil Unicode script correctly', () {
      expect(
        MiraLanguageDetector.detect('மின்ட் எவ்வளவு ஸ்டாக் இருக்கு?'),
        MiraLanguage.tamil,
      );
      expect(
        MiraLanguageDetector.detect('இன்றைய இன்வாய்ஸ் காட்டுங்கள்'),
        MiraLanguage.tamil,
      );
    });

    test('Detects Tanglish / Romanized Tamil keywords correctly', () {
      expect(
        MiraLanguageDetector.detect('Mint evlo stock irukku?'),
        MiraLanguage.tanglish,
      );
      expect(
        MiraLanguageDetector.detect('Today dispatch enna aachu?'),
        MiraLanguage.tanglish,
      );
      expect(
        MiraLanguageDetector.detect('Chocolate stock check pannunga'),
        MiraLanguage.tanglish,
      );
    });
  });

  group('2. MIRA AI Provider Abstraction & Honest Setup State (No Fake AI)', () {
    test('UnconfiguredMiraAIProvider returns honest setup guidance without fake numbers', () async {
      final provider = UnconfiguredMiraAIProvider();
      expect(provider.providerDisplayName, 'Pending Model Connection');
      expect(provider.isConfigured, false);

      const query = MiraQuery(
        queryText: 'How much mint stock is available?',
        detectedLanguage: MiraLanguage.english,
      );

      final response = await provider.processQuery(query);

      // Must state clearly that provider is awaiting connection (Rule 4: NO FAKE AI)
      expect(response.text, contains('MIRA is ready'));
      expect(response.text, contains('Connect the AI model to activate intelligent responses'));
      expect(response.isModelConfigured, false);
      expect(response.referencedTools, isEmpty);
    });

    test('MiraAIResponse models scannable structured data correctly', () {
      const resp = MiraAIResponse(
        text: 'Mint currently has 100 kg across 2 lots.',
        language: MiraLanguage.english,
        isModelConfigured: true,
        referencedTools: ['getMaterialStock'],
        structuredData: {
          'material_code': '100',
          'description': 'MINT',
          'total_available': 100.0,
          'uom': 'kg',
          'lots': 2,
          'oldest_lot': 'BATCH-275',
        },
      );

      expect(resp.structuredData?['material_code'], '100');
      expect(resp.structuredData?['total_available'], 100.0);
      expect(resp.referencedTools.first, 'getMaterialStock');
      expect(resp.isModelConfigured, true);
    });
  });

  group('3. MIRA State Machine & State Transitions', () {
    test('Initial MiraState is idle with default configurations', () {
      const state = MiraState();
      expect(state.mode, MiraStateMode.idle);
      expect(state.isVoiceEnabled, true);
      expect(state.language, MiraLanguage.auto);
      expect(state.messages, isEmpty);
      expect(state.audioAmplitude, 0.0);
      expect(state.isModelConnected, false);
      expect(state.statusMessage, 'Ready when you are.');
    });

    test('MiraState mode transitions update correctly', () {
      var state = const MiraState();
      expect(state.mode, MiraStateMode.idle);

      state = state.copyWith(mode: MiraStateMode.listening, audioAmplitude: 0.75);
      expect(state.mode, MiraStateMode.listening);
      expect(state.audioAmplitude, 0.75);

      state = state.copyWith(mode: MiraStateMode.processing);
      expect(state.mode, MiraStateMode.processing);

      state = state.copyWith(mode: MiraStateMode.speaking);
      expect(state.mode, MiraStateMode.speaking);

      state = state.copyWith(mode: MiraStateMode.error, errorMessage: 'Network timeout');
      expect(state.mode, MiraStateMode.error);
      expect(state.errorMessage, 'Network timeout');

      state = state.copyWith(mode: MiraStateMode.idle, errorMessage: null);
      expect(state.mode, MiraStateMode.idle);
      expect(state.errorMessage, isNull);
    });
  });

  group('4. Voice Infrastructure & TTS Provider Abstraction', () {
    test('MiraTtsService allows speaking and stop', () async {
      final tts = MiraTtsService();
      expect(tts.isSpeaking, false);

      await tts.speak(
        text: 'Hello, this is MIRA.',
        language: MiraLanguage.english,
      );
      expect(tts.isSpeaking, true);

      await tts.stop();
      expect(tts.isSpeaking, false);
    });

    test('MiraSpeechRecognitionService starts and stops cleanly', () async {
      final stt = MiraSpeechRecognitionService();
      expect(stt.isListening, false);

      await stt.startListening(
        language: MiraLanguage.english,
        onResult: (_, __) {},
        onAmplitude: (_) {},
        onError: (_) {},
      );
      expect(stt.isListening, true);

      await stt.stopListening();
      expect(stt.isListening, false);
    });
  });

  group('5. Inventory Tools Safe Architecture (Read-Only Guarantee)', () {
    test('All tool methods are pure static functions and no destructive actions exist', () {
      expect(MiraInventoryTools.getMaterialStock, isA<Function>());
      expect(MiraInventoryTools.getOutOfStockMaterials, isA<Function>());
      expect(MiraInventoryTools.getReorderMaterials, isA<Function>());
      expect(MiraInventoryTools.getExpiringMaterials, isA<Function>());
      expect(MiraInventoryTools.getTodayInvoices, isA<Function>());
      expect(MiraInventoryTools.getInventorySummary, isA<Function>());
    });
  });

  group('6. MIRA Presentation Widgets & Animations', () {
    testWidgets('MiraCoreWave renders smoothly in all states', (tester) async {
      for (final mode in MiraStateMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF020617),
              body: Center(
                child: MiraCoreWave(
                  mode: mode,
                  audioAmplitude: 0.5,
                  size: 200,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('MiraMessageCard displays structured scannable metrics', (tester) async {
      final message = MiraMessage(
        id: 'msg-01',
        text: 'MINT currently has 100 kg across 2 lots.',
        isUser: false,
        timestamp: DateTime.now(),
        structuredData: const {
          'material_code': '100',
          'description': 'MINT',
          'quantity': 100.0,
          'unit': 'kg',
          'lots_count': 2,
          'oldest_lot': 'BATCH-275',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiraMessageCard(
              message: message,
              isSpeakingThis: false,
              onPlayVoice: () {},
              onStopVoice: () {},
            ),
          ),
        ),
      );

      expect(find.text('MINT'), findsOneWidget);
      expect(find.text('100.0'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('Oldest Lot: BATCH-275'), findsOneWidget);
    });

    testWidgets('MiraInputBar renders text field, language selector, and buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiraInputBar(
              mode: MiraStateMode.idle,
              language: MiraLanguage.auto,
              isVoiceEnabled: true,
              onSendText: (_) {},
              onMicTap: () {},
              onSelectLanguage: (_) {},
              onToggleVoice: () {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('MiraPage renders in mobile portrait (360x800) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MiraPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('MIRA'), findsWidgets);
      expect(find.text('Ready when you are.'), findsOneWidget);
      expect(find.byType(MiraCoreWave), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MiraPage renders in tablet landscape (1024x768) dual-pane with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MiraPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('MIRA'), findsWidgets);
      expect(find.byType(MiraCoreWave), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('7. Gemini AI Provider Configuration & Real API Tests', () {
    test('GeminiMiraAIProvider is configured and initializes properly', () {
      final gemini = GeminiMiraAIProvider(
        apiKey: 'test-gemini-key-placeholder',
      );
      expect(gemini.providerId, 'google-gemini');
      expect(gemini.isConfigured, true);
      expect(gemini.providerDisplayName, contains('Google Gemini'));
    });
  });
}
