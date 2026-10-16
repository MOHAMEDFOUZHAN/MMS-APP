import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/chocolate_product_vocabulary_service.dart';

void main() {
  group('Chocolate Finished Product Vocabulary & Speech Adaptation Suite', () {
    late ChocolateProductVocabularyService vocabService;

    setUp(() {
      vocabService = ChocolateProductVocabularyService();
    });

    test('1. Exact Match Test: Recognizes all database chocolate finished products with 1.0 confidence', () {
      final products = [
        'dark',
        'dark almond',
        'dark cashew',
        'dark peanut',
        'mixed box',
        'White bar',
      ];

      for (final p in products) {
        final matches = vocabService.findMatches(p);
        expect(matches, isNotEmpty, reason: 'Failed to match exact product: $p');
        expect(matches.first.isExact, isTrue);
        expect(matches.first.score, equals(1.0));
        expect(matches.first.product.productName.toLowerCase(), equals(p.toLowerCase()));
      }
    });

    test('2. Indian Accent / Phonetic Adaptation: Correctly matches accented or misrecognized spoken words', () {
      final testCases = {
        'dhark almond': 'dark almond',
        'dark allmond': 'dark almond',
        'dark aalmond': 'dark almond',
        'dark kaju': 'dark cashew',
        'dark cashu': 'dark cashew',
        'dark peenut': 'dark peanut',
        'miksed box': 'mixed box',
        'vite bar': 'White bar',
      };

      for (final entry in testCases.entries) {
        final spoken = entry.key;
        final expected = entry.value;

        final matches = vocabService.findMatches(spoken);
        expect(matches, isNotEmpty, reason: 'No suggestion found for: "$spoken"');
        expect(
          matches.first.product.productName.toLowerCase(),
          equals(expected.toLowerCase()),
          reason: 'Expected "$expected" but got "${matches.first.product.productName}" for spoken input "$spoken"',
        );
        expect(matches.first.score, greaterThanOrEqualTo(0.80));
      }
    });

    test('3. Conversational / Filler Words: Matches correctly when operator appends "chocolate" or "slab"', () {
      final testCases = {
        'dark almond chocolate': 'dark almond',
        'dark cashew chocolate': 'dark cashew',
        'mixed box chocolate': 'mixed box',
        'white bar chocolate': 'White bar',
      };

      for (final entry in testCases.entries) {
        final matches = vocabService.findMatches(entry.key);
        expect(matches, isNotEmpty);
        expect(matches.first.product.productName.toLowerCase(), equals(entry.value.toLowerCase()));
        expect(matches.first.score, greaterThanOrEqualTo(0.75));
      }
    });

    test('4. Ambiguous Spoken Input: Returns multiple ranked candidate alternatives instead of guessing', () {
      // Operator just says "dark" -> should provide "dark" as exact, plus "dark almond", "dark cashew", "dark peanut" as alternatives
      final matches = vocabService.findMatches('dark');
      expect(matches.length, greaterThanOrEqualTo(2));
      expect(matches.first.product.productName, equals('dark'));
      expect(matches.first.isExact, isTrue);

      final otherNames = matches.skip(1).map((m) => m.product.productName).toList();
      expect(otherNames.any((n) => n.contains('almond') || n.contains('cashew') || n.contains('peanut')), isTrue);
    });

    test('5. Conflicting Nut Types: Never conflates different finished products (e.g. almond vs cashew)', () {
      final matches = vocabService.findMatches('dark almond');
      for (final m in matches) {
        if (m.product.productName.contains('cashew') || m.product.productName.contains('peanut')) {
          expect(m.score, lessThan(0.50), reason: 'Wrong nut type matched with high score: ${m.product.productName}');
        }
      }
    });

    test('6. Unregistered / Brand New Product: Preserved verbatim without forced false replacement', () {
      const newProduct = 'Sugar Free 85% Dark Madagascar';
      final matches = vocabService.findMatches(newProduct);
      // Even if some weak sub-token matches, it must not claim exact or high confidence
      if (matches.isNotEmpty) {
        expect(matches.first.isExact, isFalse);
        expect(matches.first.score, lessThan(0.70));
      }
    });

    test('7. Empty and Noise Resilience: Handles silence and gibberish without crash', () {
      expect(vocabService.findMatches(''), isEmpty);
      expect(vocabService.findMatches('   '), isEmpty);
      expect(vocabService.findMatches('xyz123abc456'), isEmpty);
    });
  });
}
