class BatchModel {
  final int id;
  final int? materialId;
  final int? productId;
  final String batchNo;
  final DateTime? batchDate;
  final String materialCode;
  final String description;
  final String category;
  final double receivedQuantity;
  final double availableQuantity;
  final String uom;
  final String department;
  final String grade;
  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final DateTime? receivedAt;
  final int? invoiceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BatchModel({
    required this.id,
    this.materialId,
    this.productId,
    required this.batchNo,
    this.batchDate,
    this.materialCode = '',
    this.description = '',
    this.category = 'General',
    this.receivedQuantity = 0.0,
    this.availableQuantity = 0.0,
    this.uom = 'kg',
    this.department = 'Finished Goods',
    this.grade = 'STANDARD',
    this.expiryDate,
    this.receivedDate,
    this.receivedAt,
    this.invoiceId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDepleted => availableQuantity <= 0.0001;
  bool get isActive => availableQuantity > 0.0001;
  double get consumedQuantity => (receivedQuantity - availableQuantity).clamp(0.0, double.infinity);
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  DateTime get effectiveDate => batchDate ?? receivedDate ?? receivedAt ?? createdAt ?? DateTime.now();
  DateTime get effectiveDateTime => receivedAt ?? createdAt ?? batchDate ?? receivedDate ?? DateTime.now();

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    DateTime? parseTimestamp(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final mId = (json['material_id'] as num?)?.toInt() ?? (json['product_id'] as num?)?.toInt();

    return BatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      materialId: mId,
      productId: mId,
      batchNo: json['batch_no']?.toString() ?? '',
      batchDate: parseDate(json['batch_date']) ?? parseDate(json['received_date']),
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: (json['available_quantity'] as num?)?.toDouble() ?? 0.0,
      uom: json['uom']?.toString() ?? 'kg',
      department: json['department']?.toString() ?? 'Finished Goods',
      grade: json['grade']?.toString() ?? 'STANDARD',
      expiryDate: parseDate(json['expiry_date']),
      receivedDate: parseDate(json['received_date']),
      receivedAt: parseTimestamp(json['received_at']) ?? parseTimestamp(json['created_at']),
      invoiceId: (json['invoice_id'] as num?)?.toInt(),
      createdAt: parseTimestamp(json['created_at']),
      updatedAt: parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (materialId != null) 'material_id': materialId,
      if (productId != null || materialId != null) 'product_id': materialId ?? productId,
      'batch_no': batchNo,
      if (batchDate != null) 'batch_date': batchDate?.toIso8601String().split('T')[0],
      'material_code': materialCode,
      'description': description,
      'category': category,
      'received_quantity': receivedQuantity,
      'available_quantity': availableQuantity,
      'uom': uom,
      'department': department,
      'grade': grade,
      if (expiryDate != null) 'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      if (receivedDate != null) 'received_date': receivedDate?.toIso8601String().split('T')[0],
      if (receivedAt != null) 'received_at': receivedAt?.toUtc().toIso8601String(),
      if (invoiceId != null) 'invoice_id': invoiceId,
    };
  }

  BatchModel copyWith({
    int? id,
    int? materialId,
    int? productId,
    String? batchNo,
    DateTime? batchDate,
    String? materialCode,
    String? description,
    String? category,
    double? receivedQuantity,
    double? availableQuantity,
    String? uom,
    String? department,
    String? grade,
    DateTime? expiryDate,
    DateTime? receivedDate,
    DateTime? receivedAt,
    int? invoiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BatchModel(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      productId: productId ?? this.productId,
      batchNo: batchNo ?? this.batchNo,
      batchDate: batchDate ?? this.batchDate,
      materialCode: materialCode ?? this.materialCode,
      description: description ?? this.description,
      category: category ?? this.category,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      uom: uom ?? this.uom,
      department: department ?? this.department,
      grade: grade ?? this.grade,
      expiryDate: expiryDate ?? this.expiryDate,
      receivedDate: receivedDate ?? this.receivedDate,
      receivedAt: receivedAt ?? this.receivedAt,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
