class MaterialModel {
  final int id;
  final String materialCode;
  final String description;
  final String category;
  final double openingStock;
  final double quantity;
  final double reorderLevel;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String lotNo;
  final double unitPrice;
  final String unit;
  final DateTime? lastUpdated;
  final String hsnSac;
  final String grade;

  MaterialModel({
    required this.id,
    required this.materialCode,
    this.description = '',
    this.category = 'General',
    this.openingStock = 0.0,
    this.quantity = 0.0,
    this.reorderLevel = 0.0,
    this.purchaseDate,
    this.expiryDate,
    this.lotNo = '',
    this.unitPrice = 0.0,
    this.unit = 'kg',
    this.lastUpdated,
    this.hsnSac = '',
    this.grade = '',
  });

  bool get isOutOfStock => quantity <= 0.0001;

  bool get isReorder => !isOutOfStock && quantity <= reorderLevel;

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate!.difference(now).inDays;
    return difference >= 0 && difference <= 30;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    return MaterialModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      openingStock: (json['opening_stock'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: parseDate(json['purchase_date']),
      expiryDate: parseDate(json['expiry_date']),
      lotNo: json['lot_no']?.toString() ?? '',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      lastUpdated: parseDate(json['last_updated']),
      hsnSac: json['hsn_sac']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_code': materialCode,
      'description': description,
      'category': category,
      'opening_stock': openingStock,
      'quantity': quantity,
      'reorder_level': reorderLevel,
      'purchase_date': purchaseDate?.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'lot_no': lotNo,
      'unit_price': unitPrice,
      'unit': unit,
      'hsn_sac': hsnSac,
      'grade': grade,
    };
  }
}
