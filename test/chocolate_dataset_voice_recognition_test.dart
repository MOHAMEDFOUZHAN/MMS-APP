import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/chocolate_product_vocabulary_service.dart';
import 'package:mms_app/data/models/chocolate_finished_product_model.dart';

void main() {
  group('Dataset-Based Voice Recognition Comprehensive Test Suite', () {
    late ChocolateProductVocabularyService vocabService;

    setUp(() {
      vocabService = ChocolateProductVocabularyService();
    });

    test('1. Exact Product Names: High confidence and exact canonical registered name returned', () {
      final sampleList = [
        'CLASSIC MILK CHOCOLATE',
        'MAPLE GLAZED ALMOND CHOCOLATE',
        'SINGLE ORIGIN ESTATE DARK 70 PERCENT',
        '3 IN 1 CHOCO',
        '46 PERCENT DARK CHOCOLATE',
        'ALMOND RAISINS BLISS',
        'ALMOND SILK',
        'ALMOND WITH BISCUIT CHOCO',
        'ALTO EL SOL',
        'ALUNGA CHOCOLATE',
        'AMARETTO ALMOND TRUFFLES',
        'ARABIAN DATES DELIGHT CHOCOLATE',
        'BENCHMARK GRAND ASSORTED 250G',
        'BERRY CHOCO',
        'BLACK FOREST INDULGENCE TRUFFLE',
        'BLUE BERRY ROYALE TRUFFLE',
        'BLUEBERRY BLISS',
        'BRANDY PLUM CHOCOLATE DELIGHT',
        'BUTTER SCOTCH 100GMS',
        'BUTTER SCOTCH VELVET TRUFFLES',
        'BUTTERSCOTCH CHOCOLATE CRUNCH',
        'CARRY BAG SMALL',
        'CASHEW MILK ROYALE',
        'CHILLI DARK TRUFFLES',
        'CLASSIC DARK CHOCOLATE',
        'CLASSIC DARK TRUFFLE',
        'CLASSIC WHITE CHOCOLATE',
        'COCONUT CREAM TRUFFLES',
        'CRANBERRY RUBY TRUFFLES',
        'CRISPY COCOA CRUNCH TRUFFLES',
        'DARK 2 IN 1 CRUNCH',
        'DARK CRUNCH CHOCO',
        'DARK FRUIT AND NUT RESERVE',
        'DARK HAZELNUT LUXE',
        'DARK PEANUTS',
        'ECUADOR CHOCOLATE',
        'ESPRESSO COFFEE TRUFFLES',
        'EXCELLENCE',
        'FRUIT AND NUT HARMONY',
        'FUDGE',
        'GAHANA',
        'GOLDEN HONEY FIG TRUFFLE',
        'HAZELNUTS DARK',
        'HONEY FIG DELIGHT CHOCOLATE',
        'INAYA CHOCOLATE',
        'MALAGA',
        'MANGO PASSION FRUIT',
        'MILK 2 IN 1 CRUNCH CHOCO',
        'MILK CRUNCH CHOCO',
        'MILK HAZELNUTS CREAM',
        'MILK PEANUTS',
        'MILK TRUFFLE',
        'MINT TRUFFLES',
        'NUTRIBON ELITE',
        'NUTTIES',
        'PEANUT TRUFFLE',
        'PINEAPPLE TRUFFELS',
        'PISTACHIO CHOCO',
        'RASPBERRY VELVET',
        'RASPBERRY ROSE TRUFFLE',
        'RASPEEEY RUBY',
        'RED WINE TRUFFLE',
        'ROASTED HAZELNUTS TRUFFLES',
        'ROYAL PISTACHIO KUNAFA CHOCOLATE',
        'RUM AND RAISIN TRUFFLES',
        'SALTED CARAMEL CREAM TRUFFLES',
        'STRAWBERRY SWIRL',
        'STRAWBERRY TRUFFLE',
        'SUGAR FREE CHO',
        'TROPICAL MANGAO DELIGHT',
        'VALANTINE SIGNATURE CHOCOLATE',
        'VENEZUELA',
        'WALNUT COCOA CRUNCH',
        'WHITE CRUNCH CHOCO',
        'WHITE HEART MILK CHOCOLATE',
        'WHITE RAISINS',
        'cutting and truffle sample',
      ];

      int highConfidenceCount = 0;
      for (final canonical in sampleList) {
        final match = vocabService.matchProduct(canonical);
        expect(match.confidence, equals(MatchConfidenceLevel.high),
            reason: 'Failed high confidence for "$canonical"');
        expect(match.selectedProduct?.productName, equals(canonical),
            reason: 'Expected exact canonical name for "$canonical"');
        highConfidenceCount++;
      }

      expect(highConfidenceCount, equals(sampleList.length));
    });

    test('2. Minor Spelling Errors & Speech-to-Text Glitches: Resolves to exact canonical name', () {
      final variations = {
        'single origin estate dark 70 persent': 'SINGLE ORIGIN ESTATE DARK 70 PERCENT',
        'royal pistashio kanafeh chocolate': 'ROYAL PISTACHIO KUNAFA CHOCOLATE',
        'valantine signature choclate': 'VALANTINE SIGNATURE CHOCOLATE',
        'valentine signature chocolate': 'VALANTINE SIGNATURE CHOCOLATE',
        'tropical mango delight': 'TROPICAL MANGAO DELIGHT',
        'pinapple truffles': 'PINEAPPLE TRUFFELS',
        'pineapple truffle': 'PINEAPPLE TRUFFELS',
        'inayah chocolate': 'INAYA CHOCOLATE',
        'amretto almond truffle': 'AMARETTO ALMOND TRUFFLES',
        'ghana chocolate': 'GAHANA',
        'raspeeey ruby': 'RASPEEEY RUBY',
        'maple glased almond chocolate': 'MAPLE GLAZED ALMOND CHOCOLATE',
      };

      for (final entry in variations.entries) {
        final match = vocabService.matchProduct(entry.key);
        expect(match.confidence, equals(MatchConfidenceLevel.high),
            reason: 'Failed for query: ${entry.key}');
        expect(match.selectedProduct?.productName, equals(entry.value),
            reason: 'Spelling error "${entry.key}" did not resolve to "${entry.value}"');
      }
    });

    test('3. Number & Percentage Recognition: Handles words vs digits and percent symbols', () {
      final numberQueries = {
        'single origin estate dark seventy percent': 'SINGLE ORIGIN ESTATE DARK 70 PERCENT',
        'single origin estate dark 70%': 'SINGLE ORIGIN ESTATE DARK 70 PERCENT',
        'forty six percent dark chocolate': '46 PERCENT DARK CHOCOLATE',
        '46% dark chocolate': '46 PERCENT DARK CHOCOLATE',
        'three in one choco': '3 IN 1 CHOCO',
        'two in one dark crunch': 'DARK 2 IN 1 CRUNCH',
        'benchmark grand assorted two fifty grams': 'BENCHMARK GRAND ASSORTED 250G',
        'benchmark grand assorted 250 grams': 'BENCHMARK GRAND ASSORTED 250G',
        'butter scotch hundred grams': 'BUTTER SCOTCH 100GMS',
        'butterscotch 100 grams': 'BUTTER SCOTCH 100GMS',
      };

      for (final entry in numberQueries.entries) {
        final match = vocabService.matchProduct(entry.key);
        expect(match.confidence, equals(MatchConfidenceLevel.high),
            reason: 'Failed number recognition for "${entry.key}"');
        expect(match.selectedProduct?.productName, equals(entry.value));
      }
    });

    test('4. Conversational Filler Words: Strips natural operator prefixes safely', () {
      final spokenUtterances = {
        'please select royal pistachio kunafa chocolate': 'ROYAL PISTACHIO KUNAFA CHOCOLATE',
        'give me classic milk chocolate': 'CLASSIC MILK CHOCOLATE',
        'tray of dark peanuts': 'DARK PEANUTS',
        'entry for maple glazed almond chocolate': 'MAPLE GLAZED ALMOND CHOCOLATE',
        'this is strawberry swirl': 'STRAWBERRY SWIRL',
        'can you add white heart milk chocolate': 'WHITE HEART MILK CHOCOLATE',
        'item roasted hazelnuts truffles': 'ROASTED HAZELNUTS TRUFFLES',
      };

      for (final entry in spokenUtterances.entries) {
        final match = vocabService.matchProduct(entry.key);
        expect(match.confidence, equals(MatchConfidenceLevel.high));
        expect(match.selectedProduct?.productName, equals(entry.value));
      }
    });

    test('5. Protecting Similar Product Pairs: Zero incorrect cross-matches', () {
      // (Spoken query, Forbidden incorrect candidate)
      final criticalPairs = [
        ('mint truffles', 'MILK TRUFFLE'),
        ('milk truffle', 'MINT TRUFFLES'),
        ('classic milk chocolate', 'CLASSIC DARK CHOCOLATE'),
        ('classic milk chocolate', 'CLASSIC WHITE CHOCOLATE'),
        ('classic dark chocolate', 'CLASSIC MILK CHOCOLATE'),
        ('classic dark chocolate', 'CLASSIC WHITE CHOCOLATE'),
        ('classic white chocolate', 'CLASSIC DARK CHOCOLATE'),
        ('dark peanuts', 'MILK PEANUTS'),
        ('dark peanuts', 'PEANUT TRUFFLE'),
        ('milk peanuts', 'DARK PEANUTS'),
        ('strawberry swirl', 'STRAWBERRY TRUFFLE'),
        ('strawberry truffle', 'STRAWBERRY SWIRL'),
        ('raspberry velvet', 'RASPBERRY ROSE TRUFFLE'),
        ('raspberry rose truffle', 'RASPBERRY VELVET'),
        ('3 in 1 choco', 'DARK 2 IN 1 CRUNCH'),
        ('single origin estate dark 70 percent', '46 PERCENT DARK CHOCOLATE'),
      ];

      for (final pair in criticalPairs) {
        final query = pair.$1;
        final forbiddenWrong = pair.$2;

        final match = vocabService.matchProduct(query);
        if (match.selectedProduct != null) {
          expect(match.selectedProduct!.productName, isNot(equals(forbiddenWrong)),
              reason: 'CRITICAL FAILURE: Spoken "$query" falsely resolved to forbidden "$forbiddenWrong"');
        }
      }
    });

    test('6. Ambiguous Match Handling: Presents short candidate list without silent auto-selection', () {
      final ambiguousQueries = [
        // Spoken query, expected candidate names in ambiguity list
        ('classic chocolate', ['CLASSIC MILK CHOCOLATE', 'CLASSIC DARK CHOCOLATE', 'CLASSIC WHITE CHOCOLATE']),
        ('strawberry', ['STRAWBERRY SWIRL', 'STRAWBERRY TRUFFLE']),
        ('classic dark', ['CLASSIC DARK CHOCOLATE', 'CLASSIC DARK TRUFFLE']),
      ];

      for (final item in ambiguousQueries) {
        final query = item.$1;
        final expectedChoices = item.$2;

        final match = vocabService.matchProduct(query);
        expect(match.confidence, equals(MatchConfidenceLevel.ambiguous),
            reason: 'Query "$query" should have been classified as AMBIGUOUS');
        expect(match.selectedProduct, isNull,
            reason: 'Ambiguous query must NOT silently auto-select a product');
        expect(match.candidates.isNotEmpty, isTrue);

        final candidateNames = match.candidates.map((c) => c.product.productName).toList();
        for (final expected in expectedChoices) {
          expect(candidateNames.contains(expected), isTrue,
              reason: 'Candidate list should include "$expected" for query "$query"');
        }
      }
    });

    test('7. No Match & Noise Rejection: Protects against unrelated speech or noise', () {
      final noiseQueries = [
        'whirrr hummm machinery background sound',
        'forklift pallet warehouse 999',
        'random office noise and chatter',
        'xyz 12345 non-existent product',
        '',
        '   ',
      ];

      for (final noise in noiseQueries) {
        final match = vocabService.matchProduct(noise);
        expect(match.confidence, equals(MatchConfidenceLevel.none),
            reason: 'Noise "$noise" should result in MatchConfidenceLevel.none');
        expect(match.selectedProduct, isNull);
      }
    });

    test('8. Preservation of Exact Registered Spellings & Capitalizations', () {
      // Verify odd/exact registered spellings specified in prompt
      final oddProducts = [
        'RASPEEEY RUBY',
        'PINEAPPLE TRUFFELS',
        'TROPICAL MANGAO DELIGHT',
        'VALANTINE SIGNATURE CHOCOLATE',
        'SUGAR FREE CHO',
        'GAHANA',
        'cutting and truffle sample',
      ];

      for (final p in oddProducts) {
        final match = vocabService.matchProduct(p);
        expect(match.confidence, equals(MatchConfidenceLevel.high));
        expect(match.selectedProduct?.productName, equals(p));
      }
    });
  });
}
