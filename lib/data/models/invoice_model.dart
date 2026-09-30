class InvoiceItemModel {
  final int id;
  final int invoiceId;
  final String material;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountPercentage;
  final double gstPercentage;
  final double igstPercentage;
  final double itemSubtotal;
  final double itemGstValue;
  final double itemIgstValue;
  final double itemTotal;
  final String batchNo;
  final String hsnSac;
  final String grade;

  InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    required this.material,
    required this.quantity,
    this.unit = 'kg',
    this.unitPrice = 0.0,
    this.discountPercentage = 0.0,
    this.gstPercentage = 0.0,
    this.igstPercentage = 0.0,
    this.itemSubtotal = 0.0,
    this.itemGstValue = 0.0,
    this.itemIgstValue = 0.0,
    this.itemTotal = 0.0,
    this.batchNo = '',
    this.hsnSac = '',
    this.grade = '',
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      invoiceId: (json['invoice_id'] as num?)?.toInt() ?? 0,
      material: json['material']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble() ?? 0.0,
      gstPercentage: (json['gst_percentage'] as num?)?.toDouble() ?? 0.0,
      igstPercentage: (json['igst_percentage'] as num?)?.toDouble() ?? 0.0,
      itemSubtotal: (json['item_subtotal'] as num?)?.toDouble() ?? 0.0,
      itemGstValue: (json['item_gst_value'] as num?)?.toDouble() ?? 0.0,
      itemIgstValue: (json['item_igst_value'] as num?)?.toDouble() ?? 0.0,
      itemTotal: (json['item_total'] as num?)?.toDouble() ?? 0.0,
      batchNo: json['batch_no']?.toString() ?? '',
      hsnSac: json['hsn_sac']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'discount_percentage': discountPercentage,
      'gst_percentage': gstPercentage,
      'igst_percentage': igstPercentage,
      'item_subtotal': itemSubtotal,
      'item_gst_value': itemGstValue,
      'item_igst_value': itemIgstValue,
      'item_total': itemTotal,
      'batch_no': batchNo,
      'hsn_sac': hsnSac,
      'grade': grade,
    };
  }
}

class InvoiceModel {
  final int id;
  final String purchaseId;
  final DateTime date;
  final String invoiceNo;
  final String vendor;
  final int noOfItems;
  final double totalExclTax;
  final double totalGst;
  final double totalIgst;
  final double cgstPercent;
  final double sgstPercent;
  final double roundOffValue;
  final double grandTotal;
  final double finalTotal;
  final String paymentStatus;
  final String remarks;
  final DateTime? createdAt;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    required this.id,
    this.purchaseId = '',
    required this.date,
    required this.invoiceNo,
    this.vendor = '',
    this.noOfItems = 1,
    this.totalExclTax = 0.0,
    this.totalGst = 0.0,
    this.totalIgst = 0.0,
    this.cgstPercent = 0.0,
    this.sgstPercent = 0.0,
    this.roundOffValue = 0.0,
    this.grandTotal = 0.0,
    this.finalTotal = 0.0,
    this.paymentStatus = 'Pending',
    this.remarks = '',
    this.createdAt,
    this.items = const [],
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        final str = val.toString().split(' ')[0];
        return DateTime.parse(str);
      } catch (_) {
        return DateTime.now();
      }
    }

    final rawItems = json['invoice_items'] as List<dynamic>?;
    final parsedItems = rawItems != null
        ? rawItems.map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>)).toList()
        : <InvoiceItemModel>[];

    return InvoiceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      purchaseId: json['purchase_id']?.toString() ?? '',
      date: parseDate(json['date']),
      invoiceNo: json['invoice_no']?.toString() ?? '',
      vendor: json['vendor']?.toString() ?? '',
      noOfItems: (json['no_of_items'] as num?)?.toInt() ?? 1,
      totalExclTax: (json['total_excl_tax'] as num?)?.toDouble() ?? 0.0,
      totalGst: (json['total_gst'] as num?)?.toDouble() ?? 0.0,
      totalIgst: (json['total_igst'] as num?)?.toDouble() ?? 0.0,
      cgstPercent: (json['cgst_percent'] as num?)?.toDouble() ?? 0.0,
      sgstPercent: (json['sgst_percent'] as num?)?.toDouble() ?? 0.0,
      roundOffValue: (json['round_off_value'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      finalTotal: (json['final_total'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status']?.toString() ?? 'Pending',
      remarks: json['remarks']?.toString() ?? '',
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : null,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchase_id': purchaseId,
      'date': date.toIso8601String().split('T')[0],
      'invoice_no': invoiceNo,
      'vendor': vendor,
      'no_of_items': noOfItems,
      'total_excl_tax': totalExclTax,
      'total_gst': totalGst,
      'total_igst': totalIgst,
      'cgst_percent': cgstPercent,
      'sgst_percent': sgstPercent,
      'round_off_value': roundOffValue,
      'grand_total': grandTotal,
      'final_total': finalTotal,
      'payment_status': paymentStatus,
      'remarks': remarks,
    };
  }
}
