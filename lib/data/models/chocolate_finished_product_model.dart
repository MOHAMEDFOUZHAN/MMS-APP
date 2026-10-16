class ChocolateFinishedProduct {
  final String productCode;
  final String productName;
  final String category;
  final String defaultUom;

  const ChocolateFinishedProduct({
    required this.productCode,
    required this.productName,
    this.category = 'CHOCOLATE',
    this.defaultUom = 'kg',
  });

  factory ChocolateFinishedProduct.fromJson(Map<String, dynamic> json) {
    return ChocolateFinishedProduct(
      productCode: json['product_code']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'CHOCOLATE',
      defaultUom: json['uom']?.toString() ?? json['unit']?.toString() ?? 'kg',
    );
  }

  Map<String, dynamic> toJson() => {
        'product_code': productCode,
        'product_name': productName,
        'category': category,
        'uom': defaultUom,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChocolateFinishedProduct &&
          runtimeType == other.runtimeType &&
          productCode == other.productCode;

  @override
  int get hashCode => productCode.hashCode;
}

class VocabularyMatchSuggestion {
  final ChocolateFinishedProduct product;
  final double score; // 0.0 to 1.0
  final bool isExact;
  final String matchReason; // 'exact', 'phonetic', 'token', 'fuzzy', 'number', 'distinctive'

  const VocabularyMatchSuggestion({
    required this.product,
    required this.score,
    required this.isExact,
    required this.matchReason,
  });
}

enum MatchConfidenceLevel {
  high,       // High-confidence match: safe to select and fill field automatically
  ambiguous,  // Ambiguous match: multiple candidates similarly plausible, operator must choose
  none,       // No reliable match in approved dataset
}

class ProductMatchResult {
  final MatchConfidenceLevel confidence;
  final ChocolateFinishedProduct? selectedProduct;
  final List<VocabularyMatchSuggestion> candidates;
  final String rawQuery;
  final String normalizedQuery;
  final String? reason;

  const ProductMatchResult({
    required this.confidence,
    this.selectedProduct,
    this.candidates = const [],
    required this.rawQuery,
    required this.normalizedQuery,
    this.reason,
  });

  bool get isHighConfidence =>
      confidence == MatchConfidenceLevel.high && selectedProduct != null;
  bool get isAmbiguous => confidence == MatchConfidenceLevel.ambiguous;
  bool get isNone => confidence == MatchConfidenceLevel.none;
}
