class StockAdjustmentModel {
  final int id;
  final String materialCode;
  final String description;
  final String unit;
  final String operation; // 'add' or 'subtract'
  final double amount;
  final String reason;
  final double beforeQty;
  final double afterQty;
  final String adjustedBy;
  final DateTime? createdAt;

  StockAdjustmentModel({
    required this.id,
    required this.materialCode,
    this.description = '',
    this.unit = 'kg',
    required this.operation,
    required this.amount,
    this.reason = '',
    required this.beforeQty,
    required this.afterQty,
    this.adjustedBy = '',
    this.createdAt,
  });

  bool get isAddition => operation.toLowerCase() == 'add';

  factory StockAdjustmentModel.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'kg',
      operation: json['operation']?.toString() ?? 'add',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? '',
      beforeQty: (json['before_qty'] as num?)?.toDouble() ?? 0.0,
      afterQty: (json['after_qty'] as num?)?.toDouble() ?? 0.0,
      adjustedBy: json['adjusted_by']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_code': materialCode,
      'operation': operation,
      'amount': amount,
      'reason': reason,
      'before_qty': beforeQty,
      'after_qty': afterQty,
      'adjusted_by': adjustedBy,
    };
  }
}
