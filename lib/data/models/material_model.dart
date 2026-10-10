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
  final double purchased;
  final double transferOut;
  final double returnIn;
  final String shelvesBin;
  final int lotCount;

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
    this.purchased = 0.0,
    this.transferOut = 0.0,
    this.returnIn = 0.0,
    this.shelvesBin = '—',
    this.lotCount = 0,
  });

  double get closingStock => quantity;

  bool get isOutOfStock => quantity <= 0.0001;

  bool get isReorder => !isOutOfStock && reorderLevel > 0 && quantity <= reorderLevel;

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

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return MaterialModel(
      id: parseInt(json['id']),
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      openingStock: parseDouble(json['opening_stock']),
      quantity: json['closing_stock'] != null
          ? parseDouble(json['closing_stock'])
          : parseDouble(json['quantity']),
      reorderLevel: parseDouble(json['reorder_level']),
      purchaseDate: parseDate(json['purchase_date'] ?? json['lot_date']),
      expiryDate: parseDate(json['expiry_date'] ?? json['earliest_expiry']),
      lotNo: json['lot_no']?.toString() ?? '',
      unitPrice: parseDouble(json['unit_price']),
      unit: json['unit']?.toString() ?? 'kg',
      lastUpdated: parseDate(json['last_updated']),
      hsnSac: json['hsn_sac']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      purchased: parseDouble(json['purchased']),
      transferOut: parseDouble(json['transfer_out']),
      returnIn: parseDouble(json['return_in']),
      shelvesBin: (json['shelves_bin'] != null && json['shelves_bin'].toString().trim().isNotEmpty)
          ? json['shelves_bin'].toString()
          : '—',
      lotCount: parseInt(json['lot_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_code': materialCode,
      'description': description,
      'category': category,
      'opening_stock': openingStock,
      'quantity': quantity,
      'closing_stock': closingStock,
      'reorder_level': reorderLevel,
      'purchase_date': purchaseDate?.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'lot_no': lotNo,
      'unit_price': unitPrice,
      'unit': unit,
      'hsn_sac': hsnSac,
      'grade': grade,
      'purchased': purchased,
      'transfer_out': transferOut,
      'return_in': returnIn,
      'shelves_bin': shelvesBin,
      'lot_count': lotCount,
    };
  }
}

