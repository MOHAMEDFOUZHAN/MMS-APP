import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/chocolate_product_vocabulary_service.dart';
import 'package:mms_app/core/services/chocolate_speech_service.dart';
import 'package:mms_app/data/models/chocolate_ocr_ledger_model.dart';
import 'package:mms_app/presentation/chocolate/chocolate_ocr_screen.dart';
import 'package:mms_app/presentation/providers/chocolate_ocr_providers.dart';

void main() {
  group('Chocolate Speech-to-Text Accuracy & Benchmark Test Suite', () {
    late ChocolateProductVocabularyService vocabService;

    setUp(() {
      vocabService = ChocolateProductVocabularyService();
    });

    test('Benchmark: Exact Product Recognition Rate across repeated spoken iterations', () {
      final dataset = [
        'dark',
        'dark almond',
        'dark cashew',
        'dark peanut',
        'mixed box',
        'White bar',
      ];

      int totalTrials = 0;
      int exactMatches = 0;

      // Simulate 5 operator utterances per product
      for (final product in dataset) {
        for (int i = 0; i < 5; i++) {
          totalTrials++;
          final matches = vocabService.findMatches(product);
          if (matches.isNotEmpty && matches.first.isExact && matches.first.score == 1.0) {
            exactMatches++;
          }
        }
      }

      final exactAccuracy = (exactMatches / totalTrials) * 100;
      debugPrint('Benchmark Result - Exact Match Accuracy: $exactAccuracy% ($exactMatches / $totalTrials)');
      expect(exactAccuracy, equals(100.0));
    });

    test('Benchmark: Accented & Phonetic Adaptation Accuracy (Indian English & Regional Dialects)', () {
      final accentedDataset = {
        'dhark almond': 'dark almond',
        'dark allmond': 'dark almond',
        'dark aalmond': 'dark almond',
        'dark kaju': 'dark cashew',
        'dark cashu': 'dark cashew',
        'dark peenut': 'dark peanut',
        'miksed box': 'mixed box',
        'vite bar': 'White bar',
      };

      int totalTrials = 0;
      int successfulMatches = 0;

      for (final entry in accentedDataset.entries) {
        totalTrials++;
        final matches = vocabService.findMatches(entry.key);
        if (matches.isNotEmpty &&
            matches.first.product.productName.toLowerCase() == entry.value.toLowerCase() &&
            matches.first.score >= 0.80) {
          successfulMatches++;
        }
      }

      final phoneticAccuracy = (successfulMatches / totalTrials) * 100;
      debugPrint('Benchmark Result - Accented Adaptation Accuracy: $phoneticAccuracy% ($successfulMatches / $totalTrials)');
      expect(phoneticAccuracy, equals(100.0));
    });

    test('Benchmark: Wrong-Product Selection Rate across Confusing / Similar-Sounding Pairs', () {
      final confusingPairs = [
        // Spoken query, Forbidden incorrect match
        ('dark almond', 'dark cashew'),
        ('dark almond', 'dark peanut'),
        ('dark cashew', 'dark almond'),
        ('dark cashew', 'dark peanut'),
        ('dark peanut', 'dark almond'),
        ('dark peanut', 'dark cashew'),
        ('mixed box', 'White bar'),
        ('White bar', 'mixed box'),
      ];

      int totalTrials = 0;
      int wrongSelections = 0;

      for (final pair in confusingPairs) {
        totalTrials++;
        final spoken = pair.$1;
        final forbiddenWrongProduct = pair.$2;

        final matches = vocabService.findMatches(spoken);
        // The forbidden wrong product MUST NEVER be the top recommended match
        if (matches.isNotEmpty &&
            matches.first.product.productName.toLowerCase() == forbiddenWrongProduct.toLowerCase()) {
          wrongSelections++;
        }
      }

      final wrongSelectionRate = (wrongSelections / totalTrials) * 100;
      debugPrint('Benchmark Result - Wrong Product Selection Rate: $wrongSelectionRate%');
      expect(wrongSelectionRate, equals(0.0));
    });

    test('Benchmark: Noise & Gibberish Rejection (Transcription Failure Rate)', () {
      final noiseSamples = [
        'whirrr hummm machinery',
        '123456789',
        'random background clatter',
        'xyz abc qwerty',
        '',
        '   ',
      ];

      int totalTrials = 0;
      int correctlyRejected = 0;

      for (final noise in noiseSamples) {
        totalTrials++;
        final matches = vocabService.findMatches(noise, minConfidence: 0.55);
        if (matches.isEmpty) {
          correctlyRejected++;
        }
      }

      final rejectionRate = (correctlyRejected / totalTrials) * 100;
      debugPrint('Benchmark Result - Noise Rejection Rate: $rejectionRate% ($correctlyRejected / $totalTrials)');
      expect(rejectionRate, equals(100.0));
    });

    test('Guardrail: Brand new / unlisted products are preserved verbatim without forced replacement', () {
      const newCustomProduct = 'Alphonso Mango Truffle Slab';
      final matches = vocabService.findMatches(newCustomProduct);
      // Must not falsely snap to an existing finished product with high confidence
      if (matches.isNotEmpty) {
        expect(matches.first.isExact, isFalse);
        expect(matches.first.score, lessThan(0.60));
      }
    });
  });

  group('Chocolate OCR UI & Voice Workflow Guardrails', () {
    testWidgets('1. Product name field displays voice mic icon and validates on camera click', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value(<ChocolateOcrLedgerModel>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChocolateOcrScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Finished Product Name field
      expect(find.text('Finished Product Name *'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.mic_rounded), findsAtLeastNWidgets(1));

      final cameraTextFinder = find.text('Camera');
      expect(cameraTextFinder, findsOneWidget);
      await tester.tap(cameraTextFinder);
      await tester.pumpAndSettle();

      // Error message should be visible
      expect(find.text('Finished Product Name is required before scanning'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Typing or speaking product name shows Confirm button and suggestion chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value(<ChocolateOcrLedgerModel>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChocolateOcrScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter "dark almond" in product name field
      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, 'dark almond');
      await tester.pumpAndSettle();

      // Matching product suggestions chip should appear
      expect(find.textContaining('Matching Finished Products'), findsAtLeastNWidgets(1));

      // Click Confirm button
      final confirmBtnText = find.textContaining('Confirm "dark almond"');
      expect(confirmBtnText, findsOneWidget);

      await tester.tap(confirmBtnText);
      await tester.pumpAndSettle();

      // Now "CONFIRMED" badge should appear
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('3. Supported speech locales include English, Tamil, and Hindi for operators', (WidgetTester tester) async {
      final locales = ChocolateSpeechService.supportedLocales;
      expect(locales.any((l) => l.id == 'en_IN'), isTrue);
      expect(locales.any((l) => l.id == 'ta_IN'), isTrue);
      expect(locales.any((l) => l.id == 'hi_IN'), isTrue);
    });

    testWidgets('4. Tapping matching suggestion chip fills exact registered canonical product name', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value(<ChocolateOcrLedgerModel>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChocolateOcrScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField).first;
      // Type operator voice query for kunafa
      await tester.enterText(textField, 'kunafa chocolate');
      await tester.pumpAndSettle();

      // Suggestion chip for exact registered product should appear
      final chipFinder = find.textContaining('ROYAL PISTACHIO KUNAFA CHOCOLATE');
      expect(chipFinder, findsOneWidget);

      // Tap the chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Field must now contain the exact registered canonical name
      final textFormFieldWidget = tester.widget<TextFormField>(textField);
      expect(textFormFieldWidget.controller?.text, equals('ROYAL PISTACHIO KUNAFA CHOCOLATE'));
      expect(find.text('CONFIRMED'), findsOneWidget);
    });

    testWidgets('5. Similar product safety in UI: Typing classic milk never suggests classic dark or white', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value(<ChocolateOcrLedgerModel>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChocolateOcrScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, 'classic milk');
      await tester.pumpAndSettle();

      // CLASSIC MILK CHOCOLATE must be suggested
      expect(find.textContaining('CLASSIC MILK CHOCOLATE'), findsOneWidget);
      // Conflicting chocolate bases must NOT be suggested
      expect(find.textContaining('CLASSIC DARK CHOCOLATE'), findsNothing);
      expect(find.textContaining('CLASSIC WHITE CHOCOLATE'), findsNothing);
    });
  });
}
