import 'package:flutter/foundation.dart';

@immutable
class TeaMaterialReceivedModel {
  final String materialCode;
  final String description;
  final String category;
  final String unit;
  final double totalReceived;
  final double totalConsumed;
  final double totalReturned;
  final double currentBalance;
  final DateTime? latestTransactionAt;
  final String stockStatus; // 'IN_STOCK', 'LOW_STOCK', 'ZERO_BALANCE'

  const TeaMaterialReceivedModel({
    required this.materialCode,
    required this.description,
    required this.category,
    required this.unit,
    required this.totalReceived,
    required this.totalConsumed,
    required this.totalReturned,
    required this.currentBalance,
    this.latestTransactionAt,
    required this.stockStatus,
  });

  bool get hasStock => currentBalance > 0.0001;

  factory TeaMaterialReceivedModel.fromJson(Map<String, dynamic> json) {
    return TeaMaterialReceivedModel(
      materialCode: (json['material_code'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'TEA').toString().trim(),
      unit: (json['unit'] ?? 'kg').toString().trim(),
      totalReceived: (json['total_received'] as num?)?.toDouble() ?? 0.0,
      totalConsumed: (json['total_consumed'] as num?)?.toDouble() ?? 0.0,
      totalReturned: (json['total_returned'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      latestTransactionAt: json['latest_transaction_at'] != null
          ? DateTime.tryParse(json['latest_transaction_at'].toString())?.toLocal()
          : null,
      stockStatus: (json['stock_status'] ?? 'IN_STOCK').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_code': materialCode,
      'description': description,
      'category': category,
      'unit': unit,
      'total_received': totalReceived,
      'total_consumed': totalConsumed,
      'total_returned': totalReturned,
      'current_balance': currentBalance,
      'latest_transaction_at': latestTransactionAt?.toIso8601String(),
      'stock_status': stockStatus,
    };
  }

  TeaMaterialReceivedModel copyWith({
    String? materialCode,
    String? description,
    String? category,
    String? unit,
    double? totalReceived,
    double? totalConsumed,
    double? totalReturned,
    double? currentBalance,
    DateTime? latestTransactionAt,
    String? stockStatus,
  }) {
    return TeaMaterialReceivedModel(
      materialCode: materialCode ?? this.materialCode,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      totalReceived: totalReceived ?? this.totalReceived,
      totalConsumed: totalConsumed ?? this.totalConsumed,
      totalReturned: totalReturned ?? this.totalReturned,
      currentBalance: currentBalance ?? this.currentBalance,
      latestTransactionAt: latestTransactionAt ?? this.latestTransactionAt,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }
}
