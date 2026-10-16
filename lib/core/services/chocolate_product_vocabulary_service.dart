import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/chocolate_finished_product_model.dart';
import '../config/supabase_config.dart';

class ChocolateProductVocabularyService {
  static final ChocolateProductVocabularyService _instance = ChocolateProductVocabularyService._internal();
  factory ChocolateProductVocabularyService() => _instance;
  ChocolateProductVocabularyService._internal();

  /// Authoritative baseline vocabulary extracted from the supplied reference sheets (Image 1 & Image 2)
  /// along with baseline active storage_products.
  static const List<ChocolateFinishedProduct> defaultVocabulary = [
    // Image 1 (17 registered products)
    ChocolateFinishedProduct(productCode: 'TRAY-RASPEEEY-RUBY', productName: 'RASPEEEY RUBY', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-RED-WINE-TRUFFLE', productName: 'RED WINE TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ROASTED-HAZELNUTS-TRUFFLES', productName: 'ROASTED HAZELNUTS TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ROYAL-PISTACHIO-KUNAFA-CHOCOLATE', productName: 'ROYAL PISTACHIO KUNAFA CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-RUM-AND-RAISIN-TRUFFLES', productName: 'RUM AND RAISIN TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-SALTED-CARAMEL-CREAM-TRUFFLES', productName: 'SALTED CARAMEL CREAM TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-STRAWBERRY-SWIRL', productName: 'STRAWBERRY SWIRL', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-STRAWBERRY-TRUFFLE', productName: 'STRAWBERRY TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-SUGAR-FREE-CHO', productName: 'SUGAR FREE CHO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-TROPICAL-MANGAO-DELIGHT', productName: 'TROPICAL MANGAO DELIGHT', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-VALANTINE-SIGNATURE-CHOCOLATE', productName: 'VALANTINE SIGNATURE CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-VENEZUELA', productName: 'VENEZUELA', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-WALNUT-COCOA-CRUNCH', productName: 'WALNUT COCOA CRUNCH', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-WHITE-CRUNCH-CHOCO', productName: 'WHITE CRUNCH CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-WHITE-HEART-MILK-CHOCOLATE', productName: 'WHITE HEART MILK CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-WHITE-RAISINS', productName: 'WHITE RAISINS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CUTTING-AND-TRUFFLE-SAMPLE', productName: 'cutting and truffle sample', defaultUom: 'kg'),

    // Image 2 (61 registered products)
    ChocolateFinishedProduct(productCode: 'TRAY-CLASSIC-MILK-CHOCOLATE', productName: 'CLASSIC MILK CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MAPLE-GLAZED-ALMOND-CHOCOLATE', productName: 'MAPLE GLAZED ALMOND CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-SINGLE-ORIGIN-ESTATE-DARK-70-PERCENT', productName: 'SINGLE ORIGIN ESTATE DARK 70 PERCENT', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-3-IN-1-CHOCO', productName: '3 IN 1 CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-46-PERCENT-DARK-CHOCOLATE', productName: '46 PERCENT DARK CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ALMOND-RAISINS-BLISS', productName: 'ALMOND RAISINS BLISS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ALMOND-SILK', productName: 'ALMOND SILK', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ALMOND-WITH-BISCUIT-CHOCO', productName: 'ALMOND WITH BISCUIT CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ALTO-EL-SOL', productName: 'ALTO EL SOL', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ALUNGA-CHOCOLATE', productName: 'ALUNGA CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-AMARETTO-ALMOND-TRUFFLES', productName: 'AMARETTO ALMOND TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ARABIAN-DATES-DELIGHT-CHOCOLATE', productName: 'ARABIAN DATES DELIGHT CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BAR', productName: 'BAR', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BENCHMARK-GRAND-ASSORTED-250G', productName: 'BENCHMARK GRAND ASSORTED 250G', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BERRY-CHOCO', productName: 'BERRY CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BLACK-FOREST-INDULGENCE-TRUFFLE', productName: 'BLACK FOREST INDULGENCE TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BLUE-BERRY-ROYALE-TRUFFLE', productName: 'BLUE BERRY ROYALE TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BLUEBERRY-BLISS', productName: 'BLUEBERRY BLISS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BRANDY-PLUM-CHOCOLATE-DELIGHT', productName: 'BRANDY PLUM CHOCOLATE DELIGHT', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BUTTER-SCOTCH-100GMS', productName: 'BUTTER SCOTCH 100GMS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BUTTER-SCOTCH-VELVET-TRUFFLES', productName: 'BUTTER SCOTCH VELVET TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-BUTTERSCOTCH-CHOCOLATE-CRUNCH', productName: 'BUTTERSCOTCH CHOCOLATE CRUNCH', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CARRY-BAG-SMALL', productName: 'CARRY BAG SMALL', defaultUom: 'pcs'),
    ChocolateFinishedProduct(productCode: 'TRAY-CASHEW-MILK-ROYALE', productName: 'CASHEW MILK ROYALE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CHILLI-DARK-TRUFFLES', productName: 'CHILLI DARK TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CLASSIC-DARK-CHOCOLATE', productName: 'CLASSIC DARK CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CLASSIC-DARK-TRUFFLE', productName: 'CLASSIC DARK TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CLASSIC-WHITE-CHOCOLATE', productName: 'CLASSIC WHITE CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-COCONUT-CREAM-TRUFFLES', productName: 'COCONUT CREAM TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CRANBERRY-RUBY-TRUFFLES', productName: 'CRANBERRY RUBY TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CRISPY-COCOA-CRUNCH-TRUFFLES', productName: 'CRISPY COCOA CRUNCH TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-2-IN-1-CRUNCH', productName: 'DARK 2 IN 1 CRUNCH', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-CRUNCH-CHOCO', productName: 'DARK CRUNCH CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-FRUIT-AND-NUT-RESERVE', productName: 'DARK FRUIT AND NUT RESERVE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-HAZELNUT-LUXE', productName: 'DARK HAZELNUT LUXE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-PEANUTS', productName: 'DARK PEANUTS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ECUADOR-CHOCOLATE', productName: 'ECUADOR CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-ESPRESSO-COFFEE-TRUFFLES', productName: 'ESPRESSO COFFEE TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-EXCELLENCE', productName: 'EXCELLENCE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-FRUIT-AND-NUT-HARMONY', productName: 'FRUIT AND NUT HARMONY', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-FUDGE', productName: 'FUDGE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-GAHANA', productName: 'GAHANA', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-GOLDEN-HONEY-FIG-TRUFFLE', productName: 'GOLDEN HONEY FIG TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-HAZELNUTS-DARK', productName: 'HAZELNUTS DARK', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-HONEY-FIG-DELIGHT-CHOCOLATE', productName: 'HONEY FIG DELIGHT CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-INAYA-CHOCOLATE', productName: 'INAYA CHOCOLATE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MALAGA', productName: 'MALAGA', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MANGO-PASSION-FRUIT', productName: 'MANGO PASSION FRUIT', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-2-IN-1-CRUNCH-CHOCO', productName: 'MILK 2 IN 1 CRUNCH CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-CRUNCH-CHOCO', productName: 'MILK CRUNCH CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-HAZELNUTS-CREAM', productName: 'MILK HAZELNUTS CREAM', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-PEANUTS', productName: 'MILK PEANUTS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-TRUFFLE', productName: 'MILK TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MINT-TRUFFLES', productName: 'MINT TRUFFLES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-NUTRIBON-ELITE', productName: 'NUTRIBON ELITE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-NUTTIES', productName: 'NUTTIES', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-PEANUT-TRUFFLE', productName: 'PEANUT TRUFFLE', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-PINEAPPLE-TRUFFELS', productName: 'PINEAPPLE TRUFFELS', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-PISTACHIO-CHOCO', productName: 'PISTACHIO CHOCO', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-RASPBERRY-VELVET', productName: 'RASPBERRY VELVET', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-RASPBERRY-ROSE-TRUFFLE', productName: 'RASPBERRY ROSE TRUFFLE', defaultUom: 'kg'),

    // Baseline active storage_products and ledger products for continuous compatibility
    ChocolateFinishedProduct(productCode: 'TRAY-DARK', productName: 'dark', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-ALMOND', productName: 'dark almond', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-CASHEW', productName: 'dark cashew', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-DARK-PEANUT', productName: 'dark peanut', defaultUom: 'g'),
    ChocolateFinishedProduct(productCode: 'TRAY-MIXED-BOX', productName: 'mixed box', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-WHITE-BAR', productName: 'White bar', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-MILK-CHOCOLATE', productName: 'milk chocolate', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-CHOCOLATE-TRUFFLE', productName: 'chocolate truffle', defaultUom: 'kg'),
    ChocolateFinishedProduct(productCode: 'TRAY-HAZELNUT-PRALINE', productName: 'hazelnut praline', defaultUom: 'kg'),
  ];

  static const Map<String, String> _canonicalMap = {
    // Spoken Indian English & dialect adaptations
    'dhark': 'dark',
    'daark': 'dark',
    'darkk': 'dark',
    'allmond': 'almond',
    'aalmond': 'almond',
    'aamond': 'almond',
    'almonds': 'almond',
    'badam': 'almond',
    'baadam': 'almond',
    'kaju': 'cashew',
    'kaaju': 'cashew',
    'cashews': 'cashew',
    'cashu': 'cashew',
    'peenut': 'peanut',
    'peanuts': 'peanut',
    'peanut': 'peanut',
    'mungfali': 'peanut',
    'kadalai': 'peanut',
    'miksed': 'mixed',
    'vite': 'white',
    'safed': 'white',
    'whyt': 'white',
    'baar': 'bar',
    'baarr': 'bar',
    // Chocolate word forms
    'choc': 'chocolate',
    'choco': 'choco',
    'choclate': 'chocolate',
    'choclates': 'chocolate',
    'chocolate': 'chocolate',
    'chocolates': 'chocolate',
    // Truffle spellings & plural variations
    'truffel': 'truffle',
    'truffels': 'truffle',
    'truffle': 'truffle',
    'truffles': 'truffle',
    // Fruits & distinctive flavor terms
    'raspeeey': 'raspberry',
    'raspberry': 'raspberry',
    'raspy': 'raspberry',
    'strawberry': 'strawberry',
    'strawberries': 'strawberry',
    'blueberry': 'blueberry',
    'blueberries': 'blueberry',
    'cranberry': 'cranberry',
    'cranberries': 'cranberry',
    'hazelnut': 'hazelnut',
    'hazelnuts': 'hazelnut',
    'raisin': 'raisin',
    'raisins': 'raisin',
    'pistachio': 'pistachio',
    'pistachios': 'pistachio',
    'pista': 'pistachio',
    'mangao': 'mango',
    'mango': 'mango',
    'mangoes': 'mango',
    'valantine': 'valentine',
    'valentine': 'valentine',
    'gahana': 'ghana',
    'ghana': 'ghana',
    'kunafa': 'kunafa',
    'knafeh': 'kunafa',
    'kanafeh': 'kunafa',
    'kunaafa': 'kunafa',
    'amaretto': 'amaretto',
    'amretto': 'amaretto',
    'inaya': 'inaya',
    'inaaya': 'inaya',
    'inayah': 'inaya',
    'alunga': 'alunga',
    'alonga': 'alunga',
    'nutties': 'nutties',
    'nuties': 'nutties',
    'nutribon': 'nutribon',
    'butterscotch': 'butterscotch',
    'persent': 'percent',
    'percentage': 'percent',
  };

  /// Distinctive keyword dictionary: Higher weights for brand-defining or unique words
  static const Map<String, double> _distinctiveTokenWeights = {
    'kunafa': 3.5,
    'amaretto': 3.5,
    'arabian': 3.0,
    'valantine': 3.5,
    'valentine': 3.5,
    'venezuela': 3.5,
    'inaya': 3.5,
    'ecuador': 3.5,
    'gahana': 3.5,
    'malaga': 3.5,
    'sol': 3.5,
    'alto': 3.0,
    'alunga': 3.5,
    'nutribon': 3.5,
    'nutties': 3.5,
    'biscuit': 3.0,
    'maple': 3.0,
    'glazed': 3.0,
    'fudge': 3.5,
    'excellence': 3.5,
    'harmony': 3.0,
    'reserve': 3.0,
    'luxe': 3.0,
    'bliss': 2.8,
    'velvet': 2.8,
    'swirl': 2.8,
    'silk': 2.8,
    'estate': 3.0,
    'origin': 3.0,
    'single': 2.5,
    '70': 3.5,
    '46': 3.5,
    '3': 3.0,
    '2': 2.5,
    '250g': 3.5,
    '100gms': 3.5,
    'pineapple': 3.0,
    'raspeeey': 3.5,
    'raspberry': 3.0,
    'cranberry': 3.0,
    'blueberry': 3.0,
    'strawberry': 3.0,
    'mangao': 3.5,
    'mango': 3.0,
    'passion': 3.0,
    'chilli': 3.5,
    'espresso': 3.5,
    'coffee': 3.0,
    'wine': 3.5,
    'rum': 3.5,
    'brandy': 3.5,
    'plum': 3.0,
    'mint': 3.5,
    'fig': 3.0,
    'dates': 3.0,
    'walnut': 3.0,
    'pistachio': 3.0,
    'cashew': 2.8,
    'almond': 2.5,
    'peanut': 2.5,
    'hazelnut': 2.8,
    // Generic tokens have lower weight
    'chocolate': 0.6,
    'choco': 0.6,
    'truffle': 0.8,
    'truffles': 0.8,
    'truffels': 0.8,
    'crunch': 1.0,
    'cream': 1.0,
    'classic': 1.2,
    'dark': 1.5,
    'milk': 1.5,
    'white': 1.5,
    'percent': 1.2,
  };

  List<ChocolateFinishedProduct> _cachedVocabulary = List.from(defaultVocabulary);
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  List<ChocolateFinishedProduct> get currentVocabulary => List.unmodifiable(_cachedVocabulary);

  /// Load finished goods vocabulary from Supabase tables (storage_products and chocolate_ocr_ledger)
  Future<List<ChocolateFinishedProduct>> loadVocabulary({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
        _cachedVocabulary.isNotEmpty) {
      return _cachedVocabulary;
    }

    try {
      final client = SupabaseConfig.client;
      final Map<String, ChocolateFinishedProduct> productsMap = {};

      // 1. Seed with default baseline (all 78 canonical products + base goods)
      for (final p in defaultVocabulary) {
        productsMap[p.productName.toLowerCase().trim()] = p;
      }

      // 2. Fetch from storage_products (finished chocolate goods)
      try {
        final storageRes = await client
            .from('storage_products')
            .select('product_code, product_name, category, uom')
            .eq('category', 'CHOCOLATE');

        for (final row in storageRes) {
          final name = (row['product_name'] ?? '').toString().trim();
          final code = (row['product_code'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            productsMap[name.toLowerCase()] = ChocolateFinishedProduct(
              productCode: code.isNotEmpty ? code : 'TRAY-${name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-')}',
              productName: name,
              category: 'CHOCOLATE',
              defaultUom: (row['uom'] ?? 'kg').toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('Warning: Could not fetch from storage_products: $e');
      }

      // 3. Fetch distinct product names from chocolate_ocr_ledger
      try {
        final ledgerRes = await client
            .from('chocolate_ocr_ledger')
            .select('description, product_code, unit')
            .order('confirmed_at', ascending: false)
            .limit(100);

        for (final row in ledgerRes) {
          final desc = (row['description'] ?? '').toString().trim();
          final code = (row['product_code'] ?? '').toString().trim();
          if (desc.isNotEmpty) {
            final lower = desc.toLowerCase();
            if (!productsMap.containsKey(lower)) {
              productsMap[lower] = ChocolateFinishedProduct(
                productCode: code.isNotEmpty ? code : 'TRAY-${desc.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-')}',
                productName: desc,
                category: 'CHOCOLATE',
                defaultUom: (row['unit'] ?? 'kg').toString().toLowerCase(),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Warning: Could not fetch from chocolate_ocr_ledger: $e');
      }

      if (productsMap.isNotEmpty) {
        _cachedVocabulary = productsMap.values.toList();
        _lastFetchTime = DateTime.now();
      }
    } catch (err) {
      debugPrint('Error loading chocolate vocabulary: $err. Using cached fallback.');
    }

    return _cachedVocabulary;
  }

  /// Normalizes raw speech text by:
  /// 1. Stripping punctuation and conversational prefixes
  /// 2. Converting spoken numbers to digits ("seventy" -> "70", "three in one" -> "3 in 1")
  /// 3. Normalizing percentages ("percent", "%") and weights ("250g", "100gms")
  static String normalizeSpeechText(String spokenText) {
    if (spokenText.trim().isEmpty) return '';

    String text = spokenText.toLowerCase().trim();

    // Trim harmless whitespace
    text = text.trim();

    // Strip common operator conversational filler phrases at start
    text = text.replaceFirst(
      RegExp(r'^(please\s+)?(can\s+you\s+)?(i\s+want\s+to\s+)?(add\s+|enter\s+|select\s+|give\s+me\s+|take\s+|entry\s+for\s+|this\s+is\s+|it\s+is\s+|item\s+|product\s+|tray\s+of\s+|box\s+of\s+)'),
      '',
    );

    // Replace harmless punctuation with space (preserve % and digits)
    text = text.replaceAll(RegExp(r'[,\.\-_\/\\#\$\*\(\)\[\]]'), ' ');

    // Normalize percent
    text = text.replaceAll(RegExp(r'\bper\s*cent\b'), 'percent');
    text = text.replaceAll('%', ' percent');

    // Spoken numbers to digits
    text = text.replaceAll(RegExp(r'\bseventy\b'), '70');
    text = text.replaceAll(RegExp(r'\bforty\s*six\b'), '46');
    text = text.replaceAll(RegExp(r'\bfortysix\b'), '46');
    text = text.replaceAll(RegExp(r'\bthree\s*in\s*one\b'), '3 in 1');
    text = text.replaceAll(RegExp(r'\btwo\s*in\s*one\b'), '2 in 1');
    text = text.replaceAll(RegExp(r'\btwo\s*hundred\s*(and\s*)?fifty\b'), '250');
    text = text.replaceAll(RegExp(r'\btwo\s*fifty\b'), '250');
    text = text.replaceAll(RegExp(r'\bone\s*hundred\b'), '100');
    text = text.replaceAll(RegExp(r'\bhundred\b'), '100');

    // Weights: 250 grams, 100 gms
    text = text.replaceAll(RegExp(r'\b250\s*(grams?|gms?|g)\b'), '250g');
    text = text.replaceAll(RegExp(r'\b100\s*(grams?|gms?|g)\b'), '100gms');

    // "blue berry" to "blueberry", "butter scotch" to "butter scotch" (keep tokens separate for word matching)
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Two-Stage Recognition Pipeline: Stage B Decision Classifier
  ///
  /// Distinguishes between three outcomes:
  /// 1. [MatchConfidenceLevel.high]: Clear winner (score >= 0.82 or exact, and distinct separation).
  ///    Safe to auto-select and fill canonical product name.
  /// 2. [MatchConfidenceLevel.ambiguous]: Multiple candidates are similarly plausible.
  ///    Returns candidate options for operator manual selection.
  /// 3. [MatchConfidenceLevel.none]: No reliable match found (query noise or below threshold).
  ProductMatchResult matchProduct(String spokenQuery) {
    final cleanRaw = spokenQuery.trim();
    if (cleanRaw.isEmpty) {
      return ProductMatchResult(
        confidence: MatchConfidenceLevel.none,
        rawQuery: spokenQuery,
        normalizedQuery: '',
        reason: 'Empty speech query',
      );
    }

    final normalized = normalizeSpeechText(cleanRaw);
    final suggestions = findMatches(normalized, minConfidence: 0.40);

    if (suggestions.isEmpty) {
      return ProductMatchResult(
        confidence: MatchConfidenceLevel.none,
        rawQuery: spokenQuery,
        normalizedQuery: normalized,
        reason: 'No catalog candidates matched above threshold',
      );
    }

    final topMatch = suggestions.first;
    final topScore = topMatch.score;

    // Minimum baseline threshold for any consideration
    if (topScore < 0.52) {
      return ProductMatchResult(
        confidence: MatchConfidenceLevel.none,
        candidates: suggestions.take(3).toList(),
        rawQuery: spokenQuery,
        normalizedQuery: normalized,
        reason: 'Confidence too low ($topScore < 0.52)',
      );
    }

    // Check competitor candidate separation (ambiguity guardrail)
    if (suggestions.length >= 2) {
      final runnerUp = suggestions[1];
      final margin = topScore - runnerUp.score;

      // If top match is not exact and competitor is within 0.12 score difference:
      if (!topMatch.isExact && margin < 0.12 && topScore < 0.95) {
        // Find all candidates closely competing within 0.15 of top score
        final ambiguousCandidates = suggestions
            .where((s) => (topScore - s.score) <= 0.15)
            .take(4)
            .toList();

        return ProductMatchResult(
          confidence: MatchConfidenceLevel.ambiguous,
          candidates: ambiguousCandidates,
          rawQuery: spokenQuery,
          normalizedQuery: normalized,
          reason: 'Multiple plausible products ($margin margin between top 2)',
        );
      }
    }

    // High confidence validation
    if (topMatch.isExact || topScore >= 0.82) {
      return ProductMatchResult(
        confidence: MatchConfidenceLevel.high,
        selectedProduct: topMatch.product,
        candidates: suggestions.take(3).toList(),
        rawQuery: spokenQuery,
        normalizedQuery: normalized,
        reason: topMatch.isExact ? 'Exact registered match' : 'High confidence distinctive match ($topScore)',
      );
    }

    // Moderate confidence (0.52 to 0.81) without clear high margin
    if (topScore >= 0.70 && suggestions.length == 1) {
      return ProductMatchResult(
        confidence: MatchConfidenceLevel.high,
        selectedProduct: topMatch.product,
        candidates: suggestions,
        rawQuery: spokenQuery,
        normalizedQuery: normalized,
        reason: 'Solitary distinctive match',
      );
    }

    // Otherwise flag as ambiguous for operator safety
    return ProductMatchResult(
      confidence: MatchConfidenceLevel.ambiguous,
      candidates: suggestions.take(4).toList(),
      rawQuery: spokenQuery,
      normalizedQuery: normalized,
      reason: 'Moderate score ($topScore) requires operator verification',
    );
  }

  /// Finds matching candidate products for a spoken text query.
  ///
  /// CRITICAL SAFETY GUARANTEE:
  /// This method NEVER modifies or mutates the user query.
  /// It returns a list of suggestions ranked by confidence score (0.0 to 1.0).
  List<VocabularyMatchSuggestion> findMatches(String spokenQuery, {double minConfidence = 0.50}) {
    final cleanQuery = spokenQuery.trim();
    if (cleanQuery.isEmpty) return const [];

    final normalized = normalizeSpeechText(cleanQuery);
    final rawTokens = _tokenize(normalized);
    final queryTokens = _canonicalizeTokens(rawTokens);
    final queryPhonetic = _toPhoneticKey(queryTokens.join(' '));

    final suggestions = <VocabularyMatchSuggestion>[];

    for (final prod in _cachedVocabulary) {
      final prodNormalized = normalizeSpeechText(prod.productName);
      final prodTokens = _canonicalizeTokens(_tokenize(prodNormalized));
      final prodPhonetic = _toPhoneticKey(prodTokens.join(' '));

      // 1. Exact match (case-insensitive, canonicalized tokens)
      if (queryTokens.join(' ') == prodTokens.join(' ')) {
        suggestions.add(VocabularyMatchSuggestion(
          product: prod,
          score: 1.0,
          isExact: true,
          matchReason: 'exact',
        ));
        continue;
      }

      // 2. Conflicting keyterm check (Mutually exclusive base, nut, flavor, or number)
      if (_hasConflictingKeyterms(queryTokens, prodTokens)) {
        continue;
      }

      // 3. Exact phrase containment check
      final queryStr = queryTokens.join(' ');
      final prodStr = prodTokens.join(' ');
      final isQueryContainedInProd = prodStr.contains(queryStr);
      final isProdContainedInQuery = queryStr.contains(prodStr);

      // 4. Token metrics & Distinctive Token weighting
      final intersection = queryTokens.toSet().intersection(prodTokens.toSet());
      if (intersection.isEmpty && !isQueryContainedInProd && !isProdContainedInQuery) {
        // If no tokens overlap at all, calculate string-level similarity cautiously
        final levSim = _calculateLevenshteinSimilarity(queryStr, prodStr);
        final phonSim = _calculatePhoneticSimilarity(queryPhonetic, prodPhonetic);
        final score = (levSim * 0.60) + (phonSim * 0.40);
        if (score >= minConfidence && score >= 0.70) {
          suggestions.add(VocabularyMatchSuggestion(
            product: prod,
            score: double.parse(score.clamp(0.0, 1.0).toStringAsFixed(3)),
            isExact: false,
            matchReason: 'phonetic',
          ));
        }
        continue;
      }

      // Distinctive token coverage calculation
      double matchedWeight = 0.0;
      double totalProdWeight = 0.0;
      for (final t in prodTokens) {
        final w = _distinctiveTokenWeights[t] ?? 1.5;
        totalProdWeight += w;
        if (queryTokens.contains(t)) {
          matchedWeight += w;
        }
      }

      final double weightedRecall = totalProdWeight > 0 ? (matchedWeight / totalProdWeight) : 0.0;
      final jaccard = _calculateJaccardSimilarity(queryTokens, prodTokens);
      final levSim = _calculateLevenshteinSimilarity(queryStr, prodStr);
      final phoneticSim = _calculatePhoneticSimilarity(queryPhonetic, prodPhonetic);

      // Check if all product tokens were spoken (with possible filler words like "please", "chocolate")
      final allProdTokensSpoken = prodTokens.every((t) => queryTokens.contains(t));
      final allQueryTokensInProd = queryTokens.every((t) => prodTokens.contains(t));

      double score = 0.0;
      String reason = 'fuzzy';

      if (allProdTokensSpoken && queryTokens.length >= prodTokens.length) {
        // High confidence match: user said all words of product plus natural word
        score = 0.88 + (0.10 * (prodTokens.length / queryTokens.length));
        reason = 'token';
      } else if (allQueryTokensInProd && prodTokens.length > queryTokens.length) {
        // User spoke a valid prefix or shorthand (e.g. "classic milk" for "CLASSIC MILK CHOCOLATE")
        score = 0.75 + (0.15 * weightedRecall);
        reason = 'prefix';
      } else if (phoneticSim >= 0.92) {
        score = max(phoneticSim, (weightedRecall * 0.7) + (phoneticSim * 0.3));
        reason = 'phonetic';
      } else {
        score = (weightedRecall * 0.45) + (jaccard * 0.25) + (levSim * 0.15) + (phoneticSim * 0.15);
      }

      if (score >= minConfidence) {
        suggestions.add(VocabularyMatchSuggestion(
          product: prod,
          score: double.parse(score.clamp(0.0, 1.0).toStringAsFixed(3)),
          isExact: false,
          matchReason: reason,
        ));
      }
    }

    // Sort: Exact match first, then highest score descending, then raw string similarity tie-breaker
    suggestions.sort((a, b) {
      if (a.isExact && !b.isExact) return -1;
      if (!a.isExact && b.isExact) return 1;
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      final rawSimA = _calculateLevenshteinSimilarity(cleanQuery.toLowerCase(), a.product.productName.toLowerCase());
      final rawSimB = _calculateLevenshteinSimilarity(cleanQuery.toLowerCase(), b.product.productName.toLowerCase());
      return rawSimB.compareTo(rawSimA);
    });

    return suggestions;
  }

  static List<String> _tokenize(String text) {
    if (text.isEmpty) return const [];
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static List<String> _canonicalizeTokens(List<String> tokens) {
    return tokens.map((t) => _canonicalMap[t] ?? t).toList();
  }

  /// Levenshtein Distance similarity (0.0 to 1.0)
  static double _calculateLevenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;

    final dist = _levenshteinDistance(s1, s2);
    return max(0.0, 1.0 - (dist / maxLen));
  }

  static int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    List<int> prev = List.generate(n + 1, (i) => i);
    List<int> curr = List.filled(n + 1, 0);

    for (int i = 0; i < m; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < n; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1, // insertion
          min(
            prev[j + 1] + 1, // deletion
            prev[j] + cost, // substitution
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[n];
  }

  /// Jaccard Similarity (Intersection over Union of tokens)
  static double _calculateJaccardSimilarity(List<String> t1, List<String> t2) {
    if (t1.isEmpty || t2.isEmpty) return 0.0;
    final set1 = t1.toSet();
    final set2 = t2.toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    if (union == 0) return 0.0;
    return intersection / union;
  }

  /// Custom phonetic key algorithm designed for Indian English and confectionery terminology
  static String _toPhoneticKey(String text) {
    String s = text.toLowerCase();

    // Remove non-alphanumeric
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (s.isEmpty) return '';

    // Step 1: Aspirated & silent sounds common in Indian accents
    s = s.replaceAll('dh', 'd');
    s = s.replaceAll('bh', 'b');
    s = s.replaceAll('th', 't');
    s = s.replaceAll('kh', 'k');
    s = s.replaceAll('gh', 'g');
    s = s.replaceAll('ph', 'f');
    s = s.replaceAll('ck', 'k');
    s = s.replaceAll('c', 'k');
    s = s.replaceAll('q', 'k');
    s = s.replaceAll('x', 'ks');

    // Step 2: Vowel normalizations
    s = s.replaceAll('ee', 'i');
    s = s.replaceAll('ea', 'i');
    s = s.replaceAll('oo', 'u');
    s = s.replaceAll('ou', 'u');
    s = s.replaceAll('aa', 'a');
    s = s.replaceAll('ai', 'a');
    s = s.replaceAll('ay', 'a');
    s = s.replaceAll('ie', 'i');
    s = s.replaceAll('y', 'i');

    // Step 3: W/V equivalence common in Indian English
    s = s.replaceAll('v', 'w');

    // Step 4: Collapse repeated consecutive characters (e.g. "allmond" -> "almond")
    final buffer = StringBuffer();
    String? prev;
    for (int i = 0; i < s.length; i++) {
      final char = s[i];
      if (char != prev) {
        buffer.write(char);
        prev = char;
      }
    }

    return buffer.toString();
  }

  static double _calculatePhoneticSimilarity(String p1, String p2) {
    if (p1 == p2) return 1.0;
    if (p1.isEmpty || p2.isEmpty) return 0.0;
    return _calculateLevenshteinSimilarity(p1, p2);
  }

  /// Safety check: Ensures two mutually exclusive nut, base, flavor, or numeric types do NOT falsely match.
  /// Protects similar product names per Section 4.
  static bool _hasConflictingKeyterms(List<String> t1, List<String> t2) {
    // Category 1: Mutually exclusive chocolate bases (unless product is a hybrid like WHITE HEART MILK CHOCOLATE)
    const baseGroups = [
      {'dark', 'black'},
      {'milk'},
      {'white', 'safed', 'vite'},
    ];

    final hasDark1 = t1.contains('dark') || t1.contains('black');
    final hasMilk1 = t1.contains('milk');
    final hasWhite1 = t1.contains('white') || t1.contains('safed') || t1.contains('vite');

    final hasDark2 = t2.contains('dark') || t2.contains('black');
    final hasMilk2 = t2.contains('milk');
    final hasWhite2 = t2.contains('white') || t2.contains('safed') || t2.contains('vite');

    // If query specified milk and not dark, but product is dark (and not milk) -> conflict!
    if (hasMilk1 && !hasDark1 && hasDark2 && !hasMilk2) return true;
    // If query specified dark and not milk, but product is milk (and not dark) -> conflict!
    if (hasDark1 && !hasMilk1 && hasMilk2 && !hasDark2) return true;
    // If query specified white, but product does not have white -> conflict!
    if (hasWhite1 && !hasWhite2) return true;
    // If query specified dark or milk (and not white), but product is pure white -> conflict!
    if ((hasDark1 || hasMilk1) && !hasWhite1 && hasWhite2 && !hasDark2 && !hasMilk2) return true;

    // Category 2: Mutually exclusive nut types
    const nutGroups = [
      {'almond', 'badam', 'allmond', 'aamond'},
      {'cashew', 'kaju', 'kaaju', 'cashu'},
      {'peanut', 'peanuts', 'groundnut', 'mungfali', 'kadalai', 'peenut'},
      {'hazelnut', 'hazelnuts'},
      {'walnut', 'walnuts'},
      {'pistachio', 'pistachios', 'pista'},
    ];

    for (int i = 0; i < nutGroups.length; i++) {
      final g1 = nutGroups[i];
      if (t1.any((t) => g1.contains(t))) {
        for (int j = 0; j < nutGroups.length; j++) {
          if (i == j) continue;
          final g2 = nutGroups[j];
          // If query mentions nut i, and candidate mentions nut j, but candidate does NOT contain nut i
          if (t2.any((t) => g2.contains(t)) && !t2.any((t) => g1.contains(t))) {
            return true;
          }
        }
      }
    }

    // Category 3: Mutually exclusive distinctive fruits & flavors
    const flavorGroups = [
      {'mint'},
      {'strawberry'},
      {'blueberry'},
      {'raspberry', 'raspeeey', 'raspy'},
      {'cranberry'},
      {'mango', 'mangao'},
      {'pineapple'},
      {'coffee', 'espresso'},
      {'chilli'},
      {'wine'},
      {'rum'},
      {'brandy'},
      {'coconut'},
    ];

    for (int i = 0; i < flavorGroups.length; i++) {
      final f1 = flavorGroups[i];
      if (t1.any((t) => f1.contains(t))) {
        for (int j = 0; j < flavorGroups.length; j++) {
          if (i == j) continue;
          final f2 = flavorGroups[j];
          if (t2.any((t) => f2.contains(t)) && !t2.any((t) => f1.contains(t))) {
            return true;
          }
        }
      }
    }

    // Special Protection: "MINT TRUFFLES" vs "MILK TRUFFLE"
    // "mint" and "milk" sound similar phonetically, but represent totally different products
    if (t1.contains('mint') && !t2.contains('mint')) return true;
    if (t2.contains('mint') && !t1.contains('mint') && t1.contains('milk')) return true;

    // Category 4: Numbers and percentages
    final has70In1 = t1.contains('70');
    final has46In1 = t1.contains('46');
    final has70In2 = t2.contains('70');
    final has46In2 = t2.contains('46');
    if (has70In1 && has46In2) return true;
    if (has46In1 && has70In2) return true;

    // "3 in 1" vs "2 in 1"
    final has3In1 = t1.contains('3');
    final has2In1 = t1.contains('2');
    final has3In2 = t2.contains('3');
    final has2In2 = t2.contains('2');
    if (has3In1 && has2In2 && !t1.contains('2')) return true;
    if (has2In1 && has3In2 && !t1.contains('3')) return true;

    // Weights: 100gms vs 250g
    if (t1.contains('100gms') && t2.contains('250g')) return true;
    if (t1.contains('250g') && t2.contains('100gms')) return true;

    return false;
  }
}
