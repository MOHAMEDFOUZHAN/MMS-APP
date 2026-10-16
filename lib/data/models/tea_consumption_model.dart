class TeaConsumptionModel {
  final int id;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String materialCode;
  final String description;
  final String category;
  final String department;
  final String unit;
  final double takenQty;
  final double balanceQty;
  final double consumedQty;
  final String operatorName;
  final String shift;
  final String status; // 'TAKEN' or 'CLOSED'
  final String notes;

  TeaConsumptionModel({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.materialCode,
    required this.description,
    this.category = 'TEA',
    this.department = 'TEA',
    this.unit = 'kg',
    required this.takenQty,
    this.balanceQty = 0.0,
    required this.consumedQty,
    this.operatorName = '',
    this.shift = 'Day Shift',
    this.status = 'TAKEN',
    this.notes = '',
  });

  DateTime get effectiveDateTime => createdAt;

  factory TeaConsumptionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final taken = (json['taken_qty'] as num?)?.toDouble() ?? 0.0;
    final balance = (json['balance_qty'] as num?)?.toDouble() ?? 0.0;
    final consumed = (json['consumed_qty'] as num?)?.toDouble() ?? (taken - balance);

    return TeaConsumptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date']),
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      materialCode: json['material_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'TEA',
      department: json['department']?.toString() ?? 'TEA',
      unit: json['unit']?.toString() ?? 'kg',
      takenQty: taken,
      balanceQty: balance,
      consumedQty: consumed,
      operatorName: json['operator_name']?.toString() ?? '',
      shift: json['shift']?.toString() ?? 'Day Shift',
      status: json['status']?.toString() ?? (balance > 0 ? 'CLOSED' : 'TAKEN'),
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'date': date.toIso8601String().split('T')[0],
      'material_code': materialCode,
      'description': description,
      'category': category,
      'department': department,
      'unit': unit,
      'taken_qty': takenQty,
      'balance_qty': balanceQty,
      'consumed_qty': consumedQty,
      'operator_name': operatorName,
      'shift': shift,
      'status': status,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (includeId && id > 0) {
      map['id'] = id;
    }
    return map;
  }

  TeaConsumptionModel copyWith({
    int? id,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? materialCode,
    String? description,
    String? category,
    String? department,
    String? unit,
    double? takenQty,
    double? balanceQty,
    double? consumedQty,
    String? operatorName,
    String? shift,
    String? status,
    String? notes,
  }) {
    return TeaConsumptionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materialCode: materialCode ?? this.materialCode,
      description: description ?? this.description,
      category: category ?? this.category,
      department: department ?? this.department,
      unit: unit ?? this.unit,
      takenQty: takenQty ?? this.takenQty,
      balanceQty: balanceQty ?? this.balanceQty,
      consumedQty: consumedQty ?? this.consumedQty,
      operatorName: operatorName ?? this.operatorName,
      shift: shift ?? this.shift,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
