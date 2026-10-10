/// Strongly typed data models for the Benchmark MMS Owner / Executive Portal.
class OwnerDashboardSummary {
  final DateTime timestamp;
  final OwnerKpiData kpi;
  final OwnerTodaySnapshot today;
  final OwnerHealthData health;
  final OwnerStorageData storage;
  final OwnerMaterialsData materials;
  final OwnerInvoicesData invoices;
  final OwnerDispatchesData dispatches;
  final OwnerTransfersData transfers;
  final OwnerTopLists topLists;
  final OwnerExpiryMonitor expiryMonitor;
  final List<OwnerActivityItem> recentActivity;
  final List<OwnerAlertItem> alerts;

  OwnerDashboardSummary({
    required this.timestamp,
    required this.kpi,
    required this.today,
    required this.health,
    required this.storage,
    required this.materials,
    required this.invoices,
    required this.dispatches,
    required this.transfers,
    required this.topLists,
    required this.expiryMonitor,
    required this.recentActivity,
    required this.alerts,
  });

  factory OwnerDashboardSummary.fromJson(Map<String, dynamic> json) {
    return OwnerDashboardSummary(
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      kpi: OwnerKpiData.fromJson(json['kpi'] as Map<String, dynamic>? ?? {}),
      today: OwnerTodaySnapshot.fromJson(json['today'] as Map<String, dynamic>? ?? {}),
      health: OwnerHealthData.fromJson(json['health'] as Map<String, dynamic>? ?? {}),
      storage: OwnerStorageData.fromJson(json['storage'] as Map<String, dynamic>? ?? {}),
      materials: OwnerMaterialsData.fromJson(json['materials'] as Map<String, dynamic>? ?? {}),
      invoices: OwnerInvoicesData.fromJson(json['invoices'] as Map<String, dynamic>? ?? {}),
      dispatches: OwnerDispatchesData.fromJson(json['dispatches'] as Map<String, dynamic>? ?? {}),
      transfers: OwnerTransfersData.fromJson(json['transfers'] as Map<String, dynamic>? ?? {}),
      topLists: OwnerTopLists.fromJson(json['top_lists'] as Map<String, dynamic>? ?? {}),
      expiryMonitor: OwnerExpiryMonitor.fromJson(json['expiry_monitor'] as Map<String, dynamic>? ?? {}),
      recentActivity: (json['recent_activity'] as List<dynamic>? ?? [])
          .map((e) => OwnerActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((e) => OwnerAlertItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OwnerKpiData {
  final int totalMaterials;
  final int activeStorageProducts;
  final double totalStorageStock;
  final double totalPurchasesVal;
  final int totalPurchasesCnt;
  final double totalDispatchedQty;
  final int totalDispatchedCnt;
  final double totalTransferredOut;
  final double totalTransferredRet;
  final double totalTransferredNet;
  final int outOfStockCnt;
  final int lowStockCnt;
  final int expiringSoonCnt;
  final int expiredCnt;
  final int pendingInvoicesCnt;
  final double pendingInvoicesVal;
  final int totalVendorsCnt;
  final int activeBatchesCnt;
  final int depletedBatchesCnt;
  final double totalMaterialsStock;

  OwnerKpiData({
    this.totalMaterials = 0,
    this.activeStorageProducts = 0,
    this.totalStorageStock = 0.0,
    this.totalPurchasesVal = 0.0,
    this.totalPurchasesCnt = 0,
    this.totalDispatchedQty = 0.0,
    this.totalDispatchedCnt = 0,
    this.totalTransferredOut = 0.0,
    this.totalTransferredRet = 0.0,
    this.totalTransferredNet = 0.0,
    this.outOfStockCnt = 0,
    this.lowStockCnt = 0,
    this.expiringSoonCnt = 0,
    this.expiredCnt = 0,
    this.pendingInvoicesCnt = 0,
    this.pendingInvoicesVal = 0.0,
    this.totalVendorsCnt = 0,
    this.activeBatchesCnt = 0,
    this.depletedBatchesCnt = 0,
    this.totalMaterialsStock = 0.0,
  });

  factory OwnerKpiData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerKpiData(
      totalMaterials: parseI(json['total_materials']),
      activeStorageProducts: parseI(json['active_storage_products']),
      totalStorageStock: parseD(json['total_storage_stock']),
      totalPurchasesVal: parseD(json['total_purchases_val']),
      totalPurchasesCnt: parseI(json['total_purchases_cnt']),
      totalDispatchedQty: parseD(json['total_dispatched_qty']),
      totalDispatchedCnt: parseI(json['total_dispatched_cnt']),
      totalTransferredOut: parseD(json['total_transferred_out']),
      totalTransferredRet: parseD(json['total_transferred_ret']),
      totalTransferredNet: parseD(json['total_transferred_net']),
      outOfStockCnt: parseI(json['out_of_stock_cnt']),
      lowStockCnt: parseI(json['low_stock_cnt']),
      expiringSoonCnt: parseI(json['expiring_soon_cnt']),
      expiredCnt: parseI(json['expired_cnt']),
      pendingInvoicesCnt: parseI(json['pending_invoices_cnt']),
      pendingInvoicesVal: parseD(json['pending_invoices_val']),
      totalVendorsCnt: parseI(json['total_vendors_cnt']),
      activeBatchesCnt: parseI(json['active_batches_cnt']),
      depletedBatchesCnt: parseI(json['depleted_batches_cnt']),
      totalMaterialsStock: parseD(json['total_materials_stock']),
    );
  }
}

class OwnerTodaySnapshot {
  final double todayPurchasesVal;
  final int todayPurchasesCnt;
  final double todayStockInQty;
  final int todayNewBatchesCnt;
  final double todayDispatchQty;
  final int todayDispatchCnt;
  final double todayTransferOut;
  final double todayTransferRet;
  final double todayClosingStock;
  final int todayInvoicesCnt;

  OwnerTodaySnapshot({
    this.todayPurchasesVal = 0.0,
    this.todayPurchasesCnt = 0,
    this.todayStockInQty = 0.0,
    this.todayNewBatchesCnt = 0,
    this.todayDispatchQty = 0.0,
    this.todayDispatchCnt = 0,
    this.todayTransferOut = 0.0,
    this.todayTransferRet = 0.0,
    this.todayClosingStock = 0.0,
    this.todayInvoicesCnt = 0,
  });

  factory OwnerTodaySnapshot.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerTodaySnapshot(
      todayPurchasesVal: parseD(json['today_purchases_val']),
      todayPurchasesCnt: parseI(json['today_purchases_cnt']),
      todayStockInQty: parseD(json['today_stock_in_qty']),
      todayNewBatchesCnt: parseI(json['today_new_batches_cnt']),
      todayDispatchQty: parseD(json['today_dispatch_qty']),
      todayDispatchCnt: parseI(json['today_dispatch_cnt']),
      todayTransferOut: parseD(json['today_transfer_out']),
      todayTransferRet: parseD(json['today_transfer_ret']),
      todayClosingStock: parseD(json['today_closing_stock']),
      todayInvoicesCnt: parseI(json['today_invoices_cnt']),
    );
  }
}

class OwnerHealthData {
  final int healthyStock;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;
  final int expired;
  final int activeBatches;
  final int depletedBatches;

  OwnerHealthData({
    this.healthyStock = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.expiringSoon = 0,
    this.expired = 0,
    this.activeBatches = 0,
    this.depletedBatches = 0,
  });

  factory OwnerHealthData.fromJson(Map<String, dynamic> json) {
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;
    return OwnerHealthData(
      healthyStock: parseI(json['healthy_stock']),
      lowStock: parseI(json['low_stock']),
      outOfStock: parseI(json['out_of_stock']),
      expiringSoon: parseI(json['expiring_soon']),
      expired: parseI(json['expired']),
      activeBatches: parseI(json['active_batches']),
      depletedBatches: parseI(json['depleted_batches']),
    );
  }
}

class OwnerStorageData {
  final double totalStorageStock;
  final int activeBatches;
  final int depletedBatches;
  final double todayStockIn;
  final double todayDispatch;
  final List<dynamic> topProducts;
  final List<dynamic> lowestProducts;
  final List<dynamic> expiringBatches;
  final List<dynamic> distribution;

  OwnerStorageData({
    this.totalStorageStock = 0.0,
    this.activeBatches = 0,
    this.depletedBatches = 0,
    this.todayStockIn = 0.0,
    this.todayDispatch = 0.0,
    this.topProducts = const [],
    this.lowestProducts = const [],
    this.expiringBatches = const [],
    this.distribution = const [],
  });

  factory OwnerStorageData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerStorageData(
      totalStorageStock: parseD(json['total_storage_stock']),
      activeBatches: parseI(json['active_batches']),
      depletedBatches: parseI(json['depleted_batches']),
      todayStockIn: parseD(json['today_stock_in']),
      todayDispatch: parseD(json['today_dispatch']),
      topProducts: (json['top_products'] as List<dynamic>?) ?? [],
      lowestProducts: (json['lowest_products'] as List<dynamic>?) ?? [],
      expiringBatches: (json['expiring_batches'] as List<dynamic>?) ?? [],
      distribution: (json['distribution'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerMaterialsData {
  final int totalMaterials;
  final double totalQuantity;
  final int lowStock;
  final int outOfStock;
  final double todayPurchases;
  final double todayTransferOut;
  final double todayReturns;
  final List<dynamic> highestStock;
  final List<dynamic> distribution;

  OwnerMaterialsData({
    this.totalMaterials = 0,
    this.totalQuantity = 0.0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.todayPurchases = 0.0,
    this.todayTransferOut = 0.0,
    this.todayReturns = 0.0,
    this.highestStock = const [],
    this.distribution = const [],
  });

  factory OwnerMaterialsData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerMaterialsData(
      totalMaterials: parseI(json['total_materials']),
      totalQuantity: parseD(json['total_quantity']),
      lowStock: parseI(json['low_stock']),
      outOfStock: parseI(json['out_of_stock']),
      todayPurchases: parseD(json['today_purchases']),
      todayTransferOut: parseD(json['today_transfer_out']),
      todayReturns: parseD(json['today_returns']),
      highestStock: (json['highest_stock'] as List<dynamic>?) ?? [],
      distribution: (json['distribution'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerInvoicesData {
  final int todayInvoicesCnt;
  final double todayInvoicesVal;
  final int weekInvoicesCnt;
  final double weekInvoicesVal;
  final int monthInvoicesCnt;
  final double monthInvoicesVal;
  final double totalPurchaseVal;
  final int pendingInvoicesCnt;
  final double pendingInvoicesVal;
  final List<dynamic> recentVendors;
  final List<dynamic> recentPurchases;
  final List<dynamic> purchaseTrend;

  OwnerInvoicesData({
    this.todayInvoicesCnt = 0,
    this.todayInvoicesVal = 0.0,
    this.weekInvoicesCnt = 0,
    this.weekInvoicesVal = 0.0,
    this.monthInvoicesCnt = 0,
    this.monthInvoicesVal = 0.0,
    this.totalPurchaseVal = 0.0,
    this.pendingInvoicesCnt = 0,
    this.pendingInvoicesVal = 0.0,
    this.recentVendors = const [],
    this.recentPurchases = const [],
    this.purchaseTrend = const [],
  });

  factory OwnerInvoicesData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerInvoicesData(
      todayInvoicesCnt: parseI(json['today_invoices_cnt']),
      todayInvoicesVal: parseD(json['today_invoices_val']),
      weekInvoicesCnt: parseI(json['week_invoices_cnt']),
      weekInvoicesVal: parseD(json['week_invoices_val']),
      monthInvoicesCnt: parseI(json['month_invoices_cnt']),
      monthInvoicesVal: parseD(json['month_invoices_val']),
      totalPurchaseVal: parseD(json['total_purchase_val']),
      pendingInvoicesCnt: parseI(json['pending_invoices_cnt']),
      pendingInvoicesVal: parseD(json['pending_invoices_val']),
      recentVendors: (json['recent_vendors'] as List<dynamic>?) ?? [],
      recentPurchases: (json['recent_purchases'] as List<dynamic>?) ?? [],
      purchaseTrend: (json['purchase_trend'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerDispatchesData {
  final int todayDispatchCnt;
  final double todayDispatchQty;
  final int weekDispatchCnt;
  final double weekDispatchQty;
  final int monthDispatchCnt;
  final double monthDispatchQty;
  final double totalDispatchQty;
  final List<dynamic> topDispatchedProducts;
  final List<dynamic> topDepartments;
  final List<dynamic> recentDispatches;
  final double returns;
  final List<dynamic> dispatchTrend;

  OwnerDispatchesData({
    this.todayDispatchCnt = 0,
    this.todayDispatchQty = 0.0,
    this.weekDispatchCnt = 0,
    this.weekDispatchQty = 0.0,
    this.monthDispatchCnt = 0,
    this.monthDispatchQty = 0.0,
    this.totalDispatchQty = 0.0,
    this.topDispatchedProducts = const [],
    this.topDepartments = const [],
    this.recentDispatches = const [],
    this.returns = 0.0,
    this.dispatchTrend = const [],
  });

  factory OwnerDispatchesData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    int parseI(dynamic v) => (v as num?)?.toInt() ?? 0;

    return OwnerDispatchesData(
      todayDispatchCnt: parseI(json['today_dispatch_cnt']),
      todayDispatchQty: parseD(json['today_dispatch_qty']),
      weekDispatchCnt: parseI(json['week_dispatch_cnt']),
      weekDispatchQty: parseD(json['week_dispatch_qty']),
      monthDispatchCnt: parseI(json['month_dispatch_cnt']),
      monthDispatchQty: parseD(json['month_dispatch_qty']),
      totalDispatchQty: parseD(json['total_dispatch_qty']),
      topDispatchedProducts: (json['top_dispatched_products'] as List<dynamic>?) ?? [],
      topDepartments: (json['top_departments'] as List<dynamic>?) ?? [],
      recentDispatches: (json['recent_dispatches'] as List<dynamic>?) ?? [],
      returns: parseD(json['returns']),
      dispatchTrend: (json['dispatch_trend'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerTransfersData {
  final double todayTransfersOut;
  final double todayTransfersRet;
  final double totalTransfersOut;
  final double totalTransfersRet;
  final double netConsumed;
  final List<dynamic> topDepartments;
  final List<dynamic> mostTransferredMaterials;
  final List<dynamic> transferTrend;

  OwnerTransfersData({
    this.todayTransfersOut = 0.0,
    this.todayTransfersRet = 0.0,
    this.totalTransfersOut = 0.0,
    this.totalTransfersRet = 0.0,
    this.netConsumed = 0.0,
    this.topDepartments = const [],
    this.mostTransferredMaterials = const [],
    this.transferTrend = const [],
  });

  factory OwnerTransfersData.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

    return OwnerTransfersData(
      todayTransfersOut: parseD(json['today_transfers_out']),
      todayTransfersRet: parseD(json['today_transfers_ret']),
      totalTransfersOut: parseD(json['total_transfers_out']),
      totalTransfersRet: parseD(json['total_transfers_ret']),
      netConsumed: parseD(json['net_consumed']),
      topDepartments: (json['top_departments'] as List<dynamic>?) ?? [],
      mostTransferredMaterials: (json['most_transferred_materials'] as List<dynamic>?) ?? [],
      transferTrend: (json['transfer_trend'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerTopLists {
  final List<dynamic> reorderRisk;
  final List<dynamic> highestStorage;
  final List<dynamic> highestMaterials;
  final List<dynamic> topDispatched;

  OwnerTopLists({
    this.reorderRisk = const [],
    this.highestStorage = const [],
    this.highestMaterials = const [],
    this.topDispatched = const [],
  });

  factory OwnerTopLists.fromJson(Map<String, dynamic> json) {
    return OwnerTopLists(
      reorderRisk: (json['reorder_risk'] as List<dynamic>?) ?? [],
      highestStorage: (json['highest_storage'] as List<dynamic>?) ?? [],
      highestMaterials: (json['highest_materials'] as List<dynamic>?) ?? [],
      topDispatched: (json['top_dispatched'] as List<dynamic>?) ?? [],
    );
  }
}

class OwnerExpiryMonitor {
  final List<dynamic> invoiceMaterials;
  final List<dynamic> storageProducts;
  final int invoiceThresholdDays;
  final int storageThresholdDays;

  OwnerExpiryMonitor({
    this.invoiceMaterials = const [],
    this.storageProducts = const [],
    this.invoiceThresholdDays = 30,
    this.storageThresholdDays = 30,
  });

  factory OwnerExpiryMonitor.fromJson(Map<String, dynamic> json) {
    return OwnerExpiryMonitor(
      invoiceMaterials: (json['invoice_materials'] as List<dynamic>?) ?? [],
      storageProducts: (json['storage_products'] as List<dynamic>?) ?? [],
      invoiceThresholdDays: (json['invoice_threshold_days'] as num?)?.toInt() ?? 30,
      storageThresholdDays: (json['storage_threshold_days'] as num?)?.toInt() ?? 30,
    );
  }
}

class OwnerActivityItem {
  final dynamic id;
  final String userEmail;
  final String operation;
  final String module;
  final String recordId;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String timeAmPm;
  final String dateStr;

  OwnerActivityItem({
    required this.id,
    required this.userEmail,
    required this.operation,
    required this.module,
    required this.recordId,
    required this.details,
    required this.createdAt,
    required this.timeAmPm,
    required this.dateStr,
  });

  factory OwnerActivityItem.fromJson(Map<String, dynamic> json) {
    return OwnerActivityItem(
      id: json['id'],
      userEmail: json['user_email']?.toString() ?? 'System',
      operation: json['operation']?.toString() ?? 'UPDATE',
      module: json['module']?.toString() ?? 'SYSTEM',
      recordId: json['record_id']?.toString() ?? '-',
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      timeAmPm: json['time_ampm']?.toString() ?? '',
      dateStr: json['date_str']?.toString() ?? '',
    );
  }
}

class OwnerAlertItem {
  final String severity; // 'CRITICAL', 'WARNING', 'INFO'
  final String title;
  final String message;
  final String referenceType;
  final String referenceId;
  final DateTime? alertTime;

  OwnerAlertItem({
    required this.severity,
    required this.title,
    required this.message,
    required this.referenceType,
    required this.referenceId,
    this.alertTime,
  });

  factory OwnerAlertItem.fromJson(Map<String, dynamic> json) {
    return OwnerAlertItem(
      severity: json['severity']?.toString().toUpperCase() ?? 'INFO',
      title: json['title']?.toString() ?? 'Alert',
      message: json['message']?.toString() ?? '',
      referenceType: json['reference_type']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      alertTime: json['alert_time'] != null ? DateTime.tryParse(json['alert_time'].toString()) : null,
    );
  }
}
