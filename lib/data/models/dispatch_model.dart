class DispatchBatchModel {
  final int id;
  final int dispatchId;
  final String batchNo;
  final int batchId;
  final double quantity;
  final double returnedQuantity;
  final double netQuantity;
  final String uom;
  final DateTime? batchDate;
  final DateTime? createdAt;

  DispatchBatchModel({
    required this.id,
    required this.dispatchId,
    required this.batchNo,
    required this.batchId,
    required this.quantity,
    this.returnedQuantity = 0.0,
    double? netQuantity,
    this.uom = 'kg',
    this.batchDate,
    this.createdAt,
  }) : netQuantity = netQuantity ?? (quantity - returnedQuantity);

  factory DispatchBatchModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    final gross = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final ret = (json['returned_quantity'] as num?)?.toDouble() ?? 0.0;
    final net = (json['net_quantity'] as num?)?.toDouble() ?? (gross - ret);

    return DispatchBatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dispatchId: (json['dispatch_id'] as num?)?.toInt() ?? 0,
      batchNo: json['batch_no']?.toString() ?? '',
      batchId: (json['batch_id'] as num?)?.toInt() ?? 0,
      quantity: gross,
      returnedQuantity: ret,
      netQuantity: net,
      uom: json['uom']?.toString() ?? 'kg',
      batchDate: parseDate(json['batch_date']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dispatch_id': dispatchId,
      'batch_no': batchNo,
      'batch_id': batchId,
      'quantity': quantity,
      'returned_quantity': returnedQuantity,
      'net_quantity': netQuantity,
      'uom': uom,
      if (batchDate != null) 'batch_date': batchDate?.toIso8601String().split('T')[0],
    };
  }
}

class DispatchModel {
  final int id;
  final DateTime date;
  final int? materialId;
  final int? storageProductId;
  final String materialCode;
  final String product;
  final String category;
  final String grade;
  final double quantity;
  final double returnQuantity;
  final double netQuantity;
  final String units;
  final String location;
  final String department;
  final String remarks;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<DispatchBatchModel> allocations;

  DispatchModel({
    required this.id,
    required this.date,
    this.materialId,
    this.storageProductId,
    required this.materialCode,
    this.product = '',
    this.category = 'General',
    this.grade = 'STANDARD',
    required this.quantity,
    this.returnQuantity = 0.0,
    double? netQuantity,
    this.units = 'kg',
    this.location = '',
    this.department = 'Dispatch',
    this.remarks = '',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.allocations = const [],
  }) : netQuantity = netQuantity ?? (quantity - returnQuantity);

  String get displayName => product.isNotEmpty ? product : materialCode;
  DateTime get effectiveDateTime => createdAt ?? date;

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return DateTime.now();
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

    final rawAllocations = json['dispatch_batches'] as List<dynamic>?;
    final parsedAllocations = rawAllocations != null
        ? rawAllocations.map((e) => DispatchBatchModel.fromJson(e as Map<String, dynamic>)).toList()
        : <DispatchBatchModel>[];

    final gross = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final ret = (json['return_quantity'] as num?)?.toDouble() ?? 0.0;
    final net = (json['net_quantity'] as num?)?.toDouble() ?? (gross - ret);

    return DispatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date'] ?? json['dispatch_date']),
      materialId: (json['material_id'] as num?)?.toInt(),
      storageProductId: (json['storage_product_id'] as num?)?.toInt(),
      materialCode: json['material_code']?.toString() ?? '',
      product: json['product']?.toString() ?? json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      grade: json['grade']?.toString() ?? 'STANDARD',
      quantity: gross,
      returnQuantity: ret,
      netQuantity: net,
      units: json['units']?.toString() ?? json['uom']?.toString() ?? 'kg',
      location: json['location']?.toString() ?? '',
      department: json['department']?.toString() ?? 'Dispatch',
      remarks: json['remarks']?.toString() ?? '',
      createdBy: json['created_by']?.toString(),
      createdAt: parseTimestamp(json['created_at']),
      updatedAt: parseTimestamp(json['updated_at']),
      allocations: parsedAllocations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      if (materialId != null) 'material_id': materialId,
      if (storageProductId != null) 'storage_product_id': storageProductId,
      'material_code': materialCode,
      'product': product,
      'category': category,
      'grade': grade,
      'quantity': quantity,
      'return_quantity': returnQuantity,
      'net_quantity': netQuantity,
      'units': units,
      'location': location,
      'department': department,
      'remarks': remarks,
    };
  }

  DispatchModel copyWith({
    int? id,
    DateTime? date,
    int? materialId,
    int? storageProductId,
    String? materialCode,
    String? product,
    String? category,
    String? grade,
    double? quantity,
    double? returnQuantity,
    double? netQuantity,
    String? units,
    String? location,
    String? department,
    String? remarks,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DispatchBatchModel>? allocations,
  }) {
    return DispatchModel(
      id: id ?? this.id,
      date: date ?? this.date,
      materialId: materialId ?? this.materialId,
      storageProductId: storageProductId ?? this.storageProductId,
      materialCode: materialCode ?? this.materialCode,
      product: product ?? this.product,
      category: category ?? this.category,
      grade: grade ?? this.grade,
      quantity: quantity ?? this.quantity,
      returnQuantity: returnQuantity ?? this.returnQuantity,
      netQuantity: netQuantity ?? this.netQuantity,
      units: units ?? this.units,
      location: location ?? this.location,
      department: department ?? this.department,
      remarks: remarks ?? this.remarks,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allocations: allocations ?? this.allocations,
    );
  }
}
