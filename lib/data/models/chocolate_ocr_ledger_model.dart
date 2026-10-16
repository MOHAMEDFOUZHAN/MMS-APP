import '../../core/formatters/app_date_formatter.dart';

class ChocolateOcrLedgerModel {
  final int id;
  final String description;
  final double quantity;
  final String unit;
  final double rawOcrQuantity;
  final String? rawOcrText;
  final String? documentName;
  final String productCode;
  final String status;
  final DateTime confirmedAt;
  final String? idempotencyKey;
  final String? createdBy;
  final DateTime? createdAt;

  ChocolateOcrLedgerModel({
    required this.id,
    required this.description,
    String? productCode,
    required this.quantity,
    this.unit = 'KG',
    required this.rawOcrQuantity,
    this.rawOcrText,
    this.documentName,
    this.status = 'CONFIRMED',
    required this.confirmedAt,
    this.idempotencyKey,
    this.createdBy,
    this.createdAt,
  }) : productCode = (productCode != null && productCode.isNotEmpty)
            ? productCode
            : 'TRAY-${description.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';

  /// Formatted confirmation date strictly as DD/MM/YYYY in device local time zone
  String get formattedDate => AppDateFormatter.format(confirmedAt);

  /// Formatted confirmation time strictly as 12-hour hh:mm AM/PM in device local time zone
  String get formattedTime => AppDateFormatter.formatTime(confirmedAt);

  /// Display string for quantity with unit
  String get displayQuantity {
    if (quantity % 1 == 0) {
      return '${quantity.toInt()} $unit';
    }
    // For decimal quantities, display clean value without trailing zero bloat
    final s = quantity.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return '$s $unit';
  }

  factory ChocolateOcrLedgerModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value.toLocal();
      if (value is String && value.isNotEmpty) {
        return (DateTime.tryParse(value) ?? DateTime.now()).toLocal();
      }
      return DateTime.now().toLocal();
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final rawQty = parseDouble(json['raw_ocr_quantity'] ?? json['quantity']);
    final qty = parseDouble(json['quantity']);
    final desc = json['description']?.toString() ?? '';
    final rawCode = json['product_code']?.toString().trim();
    final cleanCode = (rawCode != null && rawCode.isNotEmpty)
        ? rawCode
        : 'TRAY-${desc.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';

    return ChocolateOcrLedgerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      description: desc,
      productCode: cleanCode,
      quantity: qty > 0 ? qty : rawQty,
      unit: (json['unit']?.toString() ?? 'KG').toUpperCase(),
      rawOcrQuantity: rawQty,
      rawOcrText: json['raw_ocr_text']?.toString(),
      documentName: json['document_name']?.toString(),
      status: json['status']?.toString() ?? 'CONFIRMED',
      confirmedAt: parseDate(json['confirmed_at'] ?? json['created_at']),
      idempotencyKey: json['idempotency_key']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'product_code': productCode,
      'quantity': quantity,
      'unit': unit,
      'raw_ocr_quantity': rawOcrQuantity,
      'raw_ocr_text': rawOcrText,
      'document_name': documentName,
      'status': status,
      'confirmed_at': confirmedAt.toUtc().toIso8601String(),
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
