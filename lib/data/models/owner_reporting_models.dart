import 'package:flutter/foundation.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';

@immutable
class OwnerAdminLiveStockItem {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final double adminStock;
  final double teaStock;
  final double chocolateStock;
  final double otherStock;
  final double totalTransferred;
  final double totalSystemStock;
  final DateTime? lastTransactionAt;

  const OwnerAdminLiveStockItem({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.adminStock,
    required this.teaStock,
    required this.chocolateStock,
    required this.otherStock,
    required this.totalTransferred,
    required this.totalSystemStock,
    this.lastTransactionAt,
  });

  bool get hasAdminStock => adminStock > 0.0001;
  bool get hasTransferred => totalTransferred > 0.0001;

  String get formattedAdminStock => QuantityFormatter.formatDualUnit(adminStock, unit);
  String get formattedTransferred => QuantityFormatter.formatDualUnit(totalTransferred, unit);
  String get formattedTotalStock => QuantityFormatter.formatDualUnit(totalSystemStock, unit);

  String get formattedTeaStock => QuantityFormatter.formatDualUnit(teaStock, unit);
  String get formattedChocolateStock => QuantityFormatter.formatDualUnit(chocolateStock, unit);

  String get formattedLastTxDate {
    if (lastTransactionAt == null) return '—';
    return AppDateFormatter.format(lastTransactionAt);
  }

  String get formattedLastTxTime {
    if (lastTransactionAt == null) return '—';
    return AppDateFormatter.formatTime(lastTransactionAt);
  }

  factory OwnerAdminLiveStockItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return OwnerAdminLiveStockItem(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
      unit: (json['unit'] ?? 'kg').toString().trim(),
      adminStock: (json['admin_stock'] as num?)?.toDouble() ?? 0.0,
      teaStock: (json['tea_stock'] as num?)?.toDouble() ?? 0.0,
      chocolateStock: (json['chocolate_stock'] as num?)?.toDouble() ?? 0.0,
      otherStock: (json['other_stock'] as num?)?.toDouble() ?? 0.0,
      totalTransferred: (json['total_transferred'] as num?)?.toDouble() ?? 0.0,
      totalSystemStock: (json['total_system_stock'] as num?)?.toDouble() ?? 0.0,
      lastTransactionAt: parseDate(json['last_transaction_at']),
    );
  }
}

@immutable
class OwnerChocolateLiveMaterialItem {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final double totalReceived;
  final double totalAccounted;
  final double currentBalance;
  final DateTime? latestActivity;
  final String status;
  final int transferCount;

  const OwnerChocolateLiveMaterialItem({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.totalReceived,
    required this.totalAccounted,
    required this.currentBalance,
    this.latestActivity,
    required this.status,
    required this.transferCount,
  });

  bool get hasStock => currentBalance > 0.0001;

  String get formattedReceived => QuantityFormatter.formatDualUnit(totalReceived, unit);
  String get formattedAccounted => QuantityFormatter.formatDualUnit(totalAccounted, unit);
  String get formattedBalance => QuantityFormatter.formatDualUnit(currentBalance, unit);

  String get formattedLastTxDate {
    if (latestActivity == null) return '—';
    return AppDateFormatter.format(latestActivity);
  }

  String get formattedLastTxTime {
    if (latestActivity == null) return '—';
    return AppDateFormatter.formatTime(latestActivity);
  }

  factory OwnerChocolateLiveMaterialItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return OwnerChocolateLiveMaterialItem(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'CHOCOLATE').toString().trim(),
      unit: (json['unit'] ?? 'kg').toString().trim(),
      totalReceived: (json['total_received'] as num?)?.toDouble() ?? 0.0,
      totalAccounted: (json['total_accounted'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      latestActivity: parseDate(json['latest_activity']),
      status: (json['status'] ?? 'IN_STOCK').toString(),
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class OwnerOutOfStockItem {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final String location;
  final double locationStock;
  final double adminStock;
  final double teaStock;
  final double chocolateStock;
  final double totalBusinessStock;
  final double reorderLevel;
  final DateTime? lastTransactionAt;
  final String stockStatus; // 'OUT_OF_STOCK_BUSINESS', 'OUT_OF_STOCK_LOCATION', 'IN_STOCK'
  final String statusMessage;

  const OwnerOutOfStockItem({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.location,
    required this.locationStock,
    required this.adminStock,
    required this.teaStock,
    required this.chocolateStock,
    required this.totalBusinessStock,
    required this.reorderLevel,
    this.lastTransactionAt,
    required this.stockStatus,
    required this.statusMessage,
  });

  bool get isDepletedBusinessWide => totalBusinessStock <= 0.0001;
  bool get isDepletedLocationOnly => locationStock <= 0.0001 && totalBusinessStock > 0.0001;

  String get formattedLocationStock => QuantityFormatter.formatDualUnit(locationStock, unit);
  String get formattedBusinessStock => QuantityFormatter.formatDualUnit(totalBusinessStock, unit);
  String get formattedAdminStock => QuantityFormatter.formatDualUnit(adminStock, unit);
  String get formattedTeaStock => QuantityFormatter.formatDualUnit(teaStock, unit);
  String get formattedChocolateStock => QuantityFormatter.formatDualUnit(chocolateStock, unit);

  String get formattedLastTxDate {
    if (lastTransactionAt == null) return '—';
    return AppDateFormatter.format(lastTransactionAt);
  }

  String get formattedLastTxTime {
    if (lastTransactionAt == null) return '—';
    return AppDateFormatter.formatTime(lastTransactionAt);
  }

  factory OwnerOutOfStockItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return OwnerOutOfStockItem(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
      unit: (json['unit'] ?? 'kg').toString().trim(),
      location: (json['location'] ?? 'Business-Wide').toString().trim(),
      locationStock: (json['location_stock'] as num?)?.toDouble() ?? 0.0,
      adminStock: (json['admin_stock'] as num?)?.toDouble() ?? 0.0,
      teaStock: (json['tea_stock'] as num?)?.toDouble() ?? 0.0,
      chocolateStock: (json['chocolate_stock'] as num?)?.toDouble() ?? 0.0,
      totalBusinessStock: (json['total_business_stock'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 0.0,
      lastTransactionAt: parseDate(json['last_transaction_at']),
      stockStatus: (json['stock_status'] ?? 'OUT_OF_STOCK_BUSINESS').toString(),
      statusMessage: (json['status_message'] ?? '').toString().trim(),
    );
  }
}

@immutable
class OwnerReorderItem {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final String location;
  final double availableStock;
  final double totalBusinessStock;
  final double adminStock;
  final double teaStock;
  final double chocolateStock;
  final double reorderLevel;
  final double? targetStock;
  final double? suggestedReplenishment;
  final String status; // 'REORDER_REQUIRED', 'NORMAL', 'NOT_CONFIGURED'
  final String statusMessage;
  final DateTime? lastUpdated;

  const OwnerReorderItem({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.location,
    required this.availableStock,
    required this.totalBusinessStock,
    required this.adminStock,
    required this.teaStock,
    required this.chocolateStock,
    required this.reorderLevel,
    this.targetStock,
    this.suggestedReplenishment,
    required this.status,
    required this.statusMessage,
    this.lastUpdated,
  });

  bool get isReorderRequired => status == 'REORDER_REQUIRED';
  bool get isNormal => status == 'NORMAL';
  bool get isNotConfigured => status == 'NOT_CONFIGURED';

  double get currentStock => totalBusinessStock > 0.0001 ? totalBusinessStock : availableStock;

  String get formattedAvailableStock => QuantityFormatter.formatDualUnit(availableStock, unit);
  String get formattedTotalBusinessStock => QuantityFormatter.formatDualUnit(totalBusinessStock, unit);
  String get formattedReorderLevel => reorderLevel > 0 ? QuantityFormatter.formatDualUnit(reorderLevel, unit) : 'Not Set';
  String get formattedTargetStock => (targetStock != null && targetStock! > 0)
      ? QuantityFormatter.formatDualUnit(targetStock!, unit)
      : 'Not Set';
  String get formattedSuggestedReplenishment => (suggestedReplenishment != null && suggestedReplenishment! > 0)
      ? QuantityFormatter.formatDualUnit(suggestedReplenishment!, unit)
      : '— (Target Not Set)';

  String get formattedLastUpdatedDate {
    if (lastUpdated == null) return '—';
    return AppDateFormatter.format(lastUpdated);
  }

  String get formattedLastUpdatedTime {
    if (lastUpdated == null) return '—';
    return AppDateFormatter.formatTime(lastUpdated);
  }

  factory OwnerReorderItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final effectiveStock = (json['current_stock'] ?? json['total_business_stock'] ?? json['available_stock'] as num?)?.toDouble() ?? 0.0;

    return OwnerReorderItem(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
      unit: (json['unit'] ?? 'kg').toString().trim(),
      location: (json['location'] ?? json['department'] ?? 'Business-Wide').toString().trim(),
      availableStock: effectiveStock,
      totalBusinessStock: (json['total_business_stock'] ?? effectiveStock as num?)?.toDouble() ?? 0.0,
      adminStock: (json['admin_stock'] as num?)?.toDouble() ?? 0.0,
      teaStock: (json['tea_stock'] as num?)?.toDouble() ?? 0.0,
      chocolateStock: (json['chocolate_stock'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 0.0,
      targetStock: (json['target_stock'] as num?)?.toDouble(),
      suggestedReplenishment: (json['suggested_replenishment'] as num?)?.toDouble(),
      status: (json['status'] ?? 'NORMAL').toString(),
      statusMessage: (json['status_message'] ?? '').toString().trim(),
      lastUpdated: parseDate(json['last_updated']),
    );
  }
}
@immutable
class OwnerExpiryListItem {
  final String materialCode;
  final String description;
  final String? batchOrLot;
  final DateTime expiryDate;
  final double quantity;
  final String unit;
  final int daysLeft;
  final bool isExpired;

  const OwnerExpiryListItem({
    required this.materialCode,
    required this.description,
    this.batchOrLot,
    required this.expiryDate,
    required this.quantity,
    required this.unit,
    required this.daysLeft,
    required this.isExpired,
  });

  String get formattedExpiryDate => AppDateFormatter.format(expiryDate);
  String get formattedQuantity => QuantityFormatter.formatDualUnit(quantity, unit);

  String get statusBadgeText {
    if (isExpired || daysLeft <= 0) return 'EXPIRED';
    if (daysLeft == 1) return '1 Day Left';
    return '$daysLeft Days Left';
  }

  factory OwnerExpiryListItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    final dLeft = (json['days_left'] as num?)?.toInt() ?? 0;
    final exp = json['is_expired'] == true || dLeft <= 0;

    return OwnerExpiryListItem(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      batchOrLot: json['batch_or_lot']?.toString().trim(),
      expiryDate: parseDate(json['expiry_date']),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: (json['unit'] ?? 'kg').toString().trim(),
      daysLeft: dLeft,
      isExpired: exp,
    );
  }
}
