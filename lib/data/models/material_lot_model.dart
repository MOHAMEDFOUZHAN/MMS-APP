import '../../core/formatters/quantity_formatter.dart';

class MaterialLotModel {
  final int id;
  final int materialId;
  final String materialCode;
  final String lotNo;
  final DateTime lotDate;
  final double initialQuantity;
  final double availableQuantity;
  final String uom;
  final int? invoiceId;
  final DateTime? createdAt;
  final DateTime? receivedAt;
  final String grade;
  final DateTime? expiryDate;

  MaterialLotModel({
    required this.id,
    this.materialId = 0,
    required this.materialCode,
    required this.lotNo,
    required this.lotDate,
    required this.initialQuantity,
    required this.availableQuantity,
    this.uom = 'kg',
    this.invoiceId,
    this.createdAt,
    this.receivedAt,
    this.grade = '',
    this.expiryDate,
  });

  bool get isDepleted => availableQuantity <= 0.0001;

  double get opening => initialQuantity;
  double get currentAvailability => availableQuantity;
  DateTime get purchaseDate => lotDate;

  /// Strictly formats as DD/MM/YYYY
  String get formattedPurchaseDate => QuantityFormatter.formatDate(lotDate);

  /// Strictly formats as DD/MM/YYYY or '—'
  String get formattedExpiryDate =>
      expiryDate != null ? QuantityFormatter.formatDate(expiryDate) : '—';

  factory MaterialLotModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime? parseDateNullable(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return null;
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return MaterialLotModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      materialId: (json['material_id'] as num?)?.toInt() ?? 0,
      materialCode: json['material_code']?.toString() ?? '',
      lotNo: json['lot_no']?.toString() ?? '',
      lotDate: parseDate(json['lot_date'] ?? json['purchase_date']),
      initialQuantity: parseDouble(json['initial_quantity'] ?? json['opening']),
      availableQuantity: parseDouble(json['available_quantity'] ?? json['current_availability'] ?? json['quantity']),
      uom: json['uom']?.toString() ?? json['unit']?.toString() ?? 'kg',
      invoiceId: (json['invoice_id'] as num?)?.toInt(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      receivedAt: parseDateNullable(json['received_at']) ??
          (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
      grade: json['grade']?.toString() ?? '',
      expiryDate: parseDateNullable(json['expiry_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_id': materialId,
      'material_code': materialCode,
      'lot_no': lotNo,
      'lot_date': lotDate.toIso8601String().split('T')[0],
      'initial_quantity': initialQuantity,
      'available_quantity': availableQuantity,
      'uom': uom,
      'invoice_id': invoiceId,
      'received_at': receivedAt?.toIso8601String(),
      'grade': grade,
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
    };
  }
}

