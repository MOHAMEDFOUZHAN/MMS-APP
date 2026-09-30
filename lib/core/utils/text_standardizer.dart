import 'dart:math';
import 'package:flutter/services.dart';

/// Global text standardization and input normalization utilities for Benchmark MMS.
/// Enforces consistent uppercase casing, removes extra whitespace, and performs
/// dynamic fuzzy spelling correction against live master datasets.
class TextStandardizer {
  TextStandardizer._();

  /// Removes leading/trailing spaces and collapses consecutive whitespace into a single space.
  static String collapseSpaces(String? input) {
    if (input == null) return '';
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Normalizes a business text field:
  /// 1. Strips leading and trailing whitespace
  /// 2. Collapses consecutive internal whitespace into a single space
  /// 3. Converts to standard uppercase
  static String normalizeBusinessText(String? input) {
    if (input == null) return '';
    final cleaned = collapseSpaces(input);
    return cleaned.toUpperCase();
  }

  /// Normalizes material and system codes:
  /// Trims whitespace, removes internal spaces, and converts to uppercase.
  static String normalizeCode(String? code) {
    if (code == null) return '';
    return code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  /// Checks if a field name belongs to technical / case-sensitive data
  /// that should NOT be uppercased.
  static bool isTechnicalField(String fieldName) {
    final lower = fieldName.toLowerCase();
    const technicalKeywords = [
      'email',
      'url',
      'link',
      'api_key',
      'apikey',
      'password',
      'token',
      'secret',
      'id',
      'uuid',
      'path',
      'filename',
      'created_at',
      'updated_at',
      'last_updated',
      'timestamp',
    ];
    return technicalKeywords.any((k) => lower == k || lower.endsWith('_$k') || lower.contains('token'));
  }
}

/// An InputFormatter that automatically converts typed text to standard uppercase
/// and prevents accidental leading or excessive internal spaces.
class UpperCaseTextFormatter extends TextInputFormatter {
  final bool collapseMultipleSpaces;

  const UpperCaseTextFormatter({this.collapseMultipleSpaces = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase();
    if (collapseMultipleSpaces) {
      text = text.replaceAll(RegExp(r'\s+'), ' ');
    }

    return TextEditingValue(
      text: text,
      selection: newValue.selection,
    );
  }
}

/// Match confidence result returned by the fuzzy spelling engine.
class FuzzyMatchResult {
  final String query;
  final String suggestedMatch;
  final double confidence; // 0.0 to 1.0
  final bool isExactAfterNormalization;

  const FuzzyMatchResult({
    required this.query,
    required this.suggestedMatch,
    required this.confidence,
    required this.isExactAfterNormalization,
  });

  /// True if confidence is high enough to show as a suggestion
  bool get hasSuggestion => confidence >= 0.72 && !isExactAfterNormalization;

  /// True if suggestion is very high confidence (>= 0.88)
  bool get isHighConfidence => confidence >= 0.88;
}

/// Dynamic Fuzzy Spelling Engine using Levenshtein distance, Damerau transpositions,
/// and token-based similarity. Compares inputs dynamically against live reference datasets.
class FuzzySpellingEngine {
  /// Computes Damerau-Levenshtein distance (accounts for insertions, deletions, substitutions, and transpositions).
  static int damerauLevenshtein(String a, String b) {
    final lenA = a.length;
    final lenB = b.length;

    if (lenA == 0) return lenB;
    if (lenB == 0) return lenA;

    final matrix = List.generate(lenA + 1, (_) => List.filled(lenB + 1, 0));

    for (var i = 0; i <= lenA; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= lenB; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= lenA; i++) {
      for (var j = 1; j <= lenB; j++) {
        final cost = (a[i - 1] == b[j - 1]) ? 0 : 1;

        matrix[i][j] = min(
          matrix[i - 1][j] + 1, // deletion
          min(
            matrix[i][j - 1] + 1, // insertion
            matrix[i - 1][j - 1] + cost, // substitution
          ),
        );

        // Transposition check
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1);
        }
      }
    }

    return matrix[lenA][lenB];
  }

  /// Calculates normalized similarity score between 0.0 and 1.0.
  static double similarity(String s1, String s2) {
    final n1 = TextStandardizer.normalizeBusinessText(s1);
    final n2 = TextStandardizer.normalizeBusinessText(s2);

    if (n1.isEmpty && n2.isEmpty) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;
    if (n1 == n2) return 1.0;

    final maxLen = max(n1.length, n2.length);
    final dist = damerauLevenshtein(n1, n2);
    final rawSim = 1.0 - (dist / maxLen);

    // Boost score if one string contains the other as a whole word prefix
    if (n1.startsWith(n2) || n2.startsWith(n1)) {
      return min(1.0, rawSim + 0.10);
    }

    return rawSim.clamp(0.0, 1.0);
  }

  /// Finds the best spelling suggestion for [query] from a dynamic candidate list.
  /// Returns null if no candidates achieve the minimum confidence threshold.
  static FuzzyMatchResult? findBestSuggestion(
    String query,
    Iterable<String> candidates, {
    double minThreshold = 0.72,
  }) {
    final cleanQuery = TextStandardizer.normalizeBusinessText(query);
    if (cleanQuery.length < 2) return null;

    String? bestCandidate;
    double highestScore = 0.0;

    for (final rawCandidate in candidates) {
      final cleanCandidate = TextStandardizer.normalizeBusinessText(rawCandidate);
      if (cleanCandidate.isEmpty) continue;

      if (cleanQuery == cleanCandidate) {
        return FuzzyMatchResult(
          query: query,
          suggestedMatch: cleanCandidate,
          confidence: 1.0,
          isExactAfterNormalization: true,
        );
      }

      final score = similarity(cleanQuery, cleanCandidate);
      if (score > highestScore) {
        highestScore = score;
        bestCandidate = cleanCandidate;
      }
    }

    if (bestCandidate != null && highestScore >= minThreshold) {
      return FuzzyMatchResult(
        query: query,
        suggestedMatch: bestCandidate,
        confidence: highestScore,
        isExactAfterNormalization: false,
      );
    }

    return null;
  }
}
