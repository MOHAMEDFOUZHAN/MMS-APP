class TransferModel {
  final int id;
  final DateTime date;
  final String code;
  final String description;
  final String lotNo;
  final double outward;
  final String units;
  final String department;
  final String person;
  final double returnUnits;
  final double availability;
  final DateTime? createdAt;

  TransferModel({
    required this.id,
    required this.date,
    required this.code,
    this.description = '',
    this.lotNo = '',
    this.outward = 0.0,
    this.units = 'kg',
    this.department = '',
    this.person = '',
    this.returnUnits = 0.0,
    this.availability = 0.0,
    this.createdAt,
  });

  double get netChange => returnUnits - outward;

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return DateTime.now();
      }
    }

    return TransferModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date']),
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      lotNo: json['lot_no']?.toString() ?? '',
      outward: (json['outward'] as num?)?.toDouble() ?? 0.0,
      units: json['units']?.toString() ?? 'kg',
      department: json['department']?.toString() ?? '',
      person: json['person']?.toString() ?? '',
      returnUnits: (json['return_units'] as num?)?.toDouble() ?? 0.0,
      availability: (json['availability'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'code': code,
      'description': description,
      'lot_no': lotNo,
      'outward': outward,
      'units': units,
      'department': department,
      'person': person,
      'return_units': returnUnits,
      'availability': availability,
    };
  }
}
