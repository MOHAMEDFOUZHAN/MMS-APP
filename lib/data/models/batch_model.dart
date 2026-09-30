class BatchModel {
  final int id;
  final String batchNo;
  final String materialCode;
  final String description;
  final double receivedQuantity;
  final double availableQuantity;
  final String uom;
  final String department;
  final DateTime? receivedDate;
  final int? invoiceId;
  final DateTime? createdAt;

  BatchModel({
    required this.id,
    required this.batchNo,
    this.materialCode = '',
    this.description = '',
    this.receivedQuantity = 0.0,
    this.availableQuantity = 0.0,
    this.uom = 'kg',
    this.department = 'General Storage',
    this.receivedDate,
    this.invoiceId,
    this.createdAt,
  });

  bool get isDepleted => availableQuantity <= 0.0001;

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

    return BatchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      batchNo: json['batch_no']?.toString() ?? '',
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: (json['available_quantity'] as num?)?.toDouble() ?? 0.0,
      uom: json['uom']?.toString() ?? 'kg',
      department: json['department']?.toString() ?? 'General Storage',
      receivedDate: parseDate(json['received_date']),
      invoiceId: (json['invoice_id'] as num?)?.toInt(),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_no': batchNo,
      'material_code': materialCode,
      'description': description,
      'received_quantity': receivedQuantity,
      'available_quantity': availableQuantity,
      'uom': uom,
      'department': department,
      'received_date': receivedDate?.toIso8601String().split('T')[0],
      'invoice_id': invoiceId,
    };
  }
}
