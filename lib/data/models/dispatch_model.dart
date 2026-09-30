class DispatchBatchModel {
  final int id;
  final int dispatchId;
  final String batchNo;
  final int batchId;
  final double quantity;
  final DateTime? createdAt;

  DispatchBatchModel({
    required this.id,
    required this.dispatchId,
    required this.batchNo,
    required this.batchId,
    required this.quantity,
    this.createdAt,
  });

  factory DispatchBatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchBatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dispatchId: (json['dispatch_id'] as num?)?.toInt() ?? 0,
      batchNo: json['batch_no']?.toString() ?? '',
      batchId: (json['batch_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class DispatchModel {
  final int id;
  final DateTime date;
  final String materialCode;
  final String product;
  final double quantity;
  final String units;
  final String location;
  final String department;
  final DateTime? createdAt;
  final List<DispatchBatchModel> allocations;

  DispatchModel({
    required this.id,
    required this.date,
    required this.materialCode,
    this.product = '',
    required this.quantity,
    this.units = 'kg',
    this.location = '',
    this.department = 'Dispatch',
    this.createdAt,
    this.allocations = const [],
  });

  String get displayName => product.isNotEmpty ? product : materialCode;

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

    final rawAllocations = json['dispatch_batches'] as List<dynamic>?;
    final parsedAllocations = rawAllocations != null
        ? rawAllocations.map((e) => DispatchBatchModel.fromJson(e as Map<String, dynamic>)).toList()
        : <DispatchBatchModel>[];

    return DispatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date']),
      materialCode: json['material_code']?.toString() ?? '',
      product: json['product']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      units: json['units']?.toString() ?? 'kg',
      location: json['location']?.toString() ?? '',
      department: json['department']?.toString() ?? 'Dispatch',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      allocations: parsedAllocations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'material_code': materialCode,
      'product': product,
      'quantity': quantity,
      'units': units,
      'location': location,
      'department': department,
    };
  }
}
