class CategoryStock {
  final String category;
  final double totalQuantity;
  final int itemCount;

  CategoryStock({
    required this.category,
    required this.totalQuantity,
    required this.itemCount,
  });

  factory CategoryStock.fromJson(Map<String, dynamic> json) {
    return CategoryStock(
      category: json['category']?.toString() ?? 'Uncategorized',
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopMaterialItem {
  final String materialCode;
  final String description;
  final double quantity;
  final String unit;

  TopMaterialItem({
    required this.materialCode,
    required this.description,
    required this.quantity,
    required this.unit,
  });

  factory TopMaterialItem.fromJson(Map<String, dynamic> json) {
    return TopMaterialItem(
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
    );
  }
}

class DashboardSummaryModel {
  final int totalMaterials;
  final int reorderItems;
  final int expiringSoon;
  final int outOfStock;
  final int pendingInvoices;
  final int activeBatches;
  final double todayPurchaseValue;
  final int todayDispatches;
  final int todayTransfers;
  final List<CategoryStock> categoryBreakdown;
  final List<TopMaterialItem> topMaterials;

  DashboardSummaryModel({
    this.totalMaterials = 0,
    this.reorderItems = 0,
    this.expiringSoon = 0,
    this.outOfStock = 0,
    this.pendingInvoices = 0,
    this.activeBatches = 0,
    this.todayPurchaseValue = 0.0,
    this.todayDispatches = 0,
    this.todayTransfers = 0,
    this.categoryBreakdown = const [],
    this.topMaterials = const [],
  });

  factory DashboardSummaryModel.empty() {
    return DashboardSummaryModel();
  }
}
