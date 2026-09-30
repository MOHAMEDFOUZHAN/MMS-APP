class MaterialDirectoryRow {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final double currentStock;
  final double reorderLevel;
  final String shelfLocation;

  MaterialDirectoryRow({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.reorderLevel,
    required this.shelfLocation,
  });

  factory MaterialDirectoryRow.fromJson(Map<String, dynamic> json) {
    return MaterialDirectoryRow(
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      unit: json['unit']?.toString() ?? 'kg',
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 0.0,
      shelfLocation: json['shelf_location']?.toString() ?? 'Not Assigned',
    );
  }
}

class DailyLedgerRow {
  final String materialCode;
  final String description;
  final String unit;
  final double openingStock;
  final double purchased;
  final double transferOut;
  final double returnIn;
  final double dispatched;
  final double closingStock;

  DailyLedgerRow({
    required this.materialCode,
    required this.description,
    required this.unit,
    required this.openingStock,
    required this.purchased,
    required this.transferOut,
    required this.returnIn,
    required this.dispatched,
    required this.closingStock,
  });

  factory DailyLedgerRow.fromJson(Map<String, dynamic> json) {
    return DailyLedgerRow(
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'kg',
      openingStock: (json['opening_stock'] as num?)?.toDouble() ?? 0.0,
      purchased: (json['purchased'] as num?)?.toDouble() ?? 0.0,
      transferOut: (json['transfer_out'] as num?)?.toDouble() ?? 0.0,
      returnIn: (json['return_in'] as num?)?.toDouble() ?? 0.0,
      dispatched: (json['dispatched'] as num?)?.toDouble() ?? 0.0,
      closingStock: (json['closing_stock'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DepartmentConsumptionRow {
  final String department;
  final String materialCode;
  final String description;
  final String unit;
  final double totalOutward;
  final double totalReturn;
  final double netConsumed;

  DepartmentConsumptionRow({
    required this.department,
    required this.materialCode,
    required this.description,
    required this.unit,
    required this.totalOutward,
    required this.totalReturn,
    required this.netConsumed,
  });

  factory DepartmentConsumptionRow.fromJson(Map<String, dynamic> json) {
    return DepartmentConsumptionRow(
      department: json['department']?.toString() ?? 'General',
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'kg',
      totalOutward: (json['total_outward'] as num?)?.toDouble() ?? 0.0,
      totalReturn: (json['total_return'] as num?)?.toDouble() ?? 0.0,
      netConsumed: (json['net_consumed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MurReportRow {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final String shelfLocation;
  final double opening;
  final double purchased;
  final double used;
  final double closing;
  final double utilizationPercent;

  MurReportRow({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.shelfLocation,
    required this.opening,
    required this.purchased,
    required this.used,
    required this.closing,
    required this.utilizationPercent,
  });

  factory MurReportRow.fromJson(Map<String, dynamic> json) {
    return MurReportRow(
      materialCode: (json['material_code'] ?? json['code'])?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      unit: json['unit']?.toString() ?? 'kg',
      shelfLocation: json['shelf_location']?.toString() ?? 'Not Assigned',
      opening: (json['opening'] as num?)?.toDouble() ?? 0.0,
      purchased: (json['purchased'] as num?)?.toDouble() ?? 0.0,
      used: (json['used'] as num?)?.toDouble() ?? 0.0,
      closing: (json['closing'] as num?)?.toDouble() ?? 0.0,
      utilizationPercent: (json['utilization_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
