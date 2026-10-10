class StorageProductModel {
  final int id;
  final String productCode;
  final String productName;
  final String uom;
  final String grade;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StorageProductModel({
    required this.id,
    required this.productCode,
    required this.productName,
    this.uom = 'kg',
    this.grade = 'STANDARD',
    this.category = 'Finished Goods',
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => productName.isNotEmpty ? '$productName ($productCode)' : productCode;

  factory StorageProductModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return StorageProductModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productCode: json['product_code']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      uom: json['uom']?.toString() ?? 'kg',
      grade: json['grade']?.toString() ?? 'STANDARD',
      category: json['category']?.toString() ?? 'Finished Goods',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_code': productCode,
      'product_name': productName,
      'uom': uom,
      'grade': grade,
      'category': category,
    };
  }

  StorageProductModel copyWith({
    int? id,
    String? productCode,
    String? productName,
    String? uom,
    String? grade,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StorageProductModel(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      uom: uom ?? this.uom,
      grade: grade ?? this.grade,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DispatchAvailableProductModel {
  final String productCode;
  final String productName;
  final String uom;
  final String grade;
  final String category;
  final double totalAvailable;
  final int batchCount;

  DispatchAvailableProductModel({
    required this.productCode,
    required this.productName,
    required this.uom,
    required this.grade,
    required this.category,
    required this.totalAvailable,
    required this.batchCount,
  });

  String get displayName => productName.isNotEmpty ? '$productName ($productCode)' : productCode;

  factory DispatchAvailableProductModel.fromJson(Map<String, dynamic> json) {
    return DispatchAvailableProductModel(
      productCode: json['product_code']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      uom: json['uom']?.toString() ?? 'kg',
      grade: json['grade']?.toString() ?? 'STANDARD',
      category: json['category']?.toString() ?? 'Finished Goods',
      totalAvailable: (json['total_available'] as num?)?.toDouble() ?? 0.0,
      batchCount: (json['batch_count'] as num?)?.toInt() ?? 0,
    );
  }
}
