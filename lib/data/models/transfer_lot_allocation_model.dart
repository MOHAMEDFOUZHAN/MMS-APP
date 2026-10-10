class TransferLotAllocationModel {
  final int id;
  final int transferId;
  final int lotId;
  final String lotNo;
  final double quantity;
  final DateTime? createdAt;

  TransferLotAllocationModel({
    required this.id,
    required this.transferId,
    required this.lotId,
    required this.lotNo,
    required this.quantity,
    this.createdAt,
  });

  factory TransferLotAllocationModel.fromJson(Map<String, dynamic> json) {
    return TransferLotAllocationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      transferId: (json['transfer_id'] as num?)?.toInt() ?? 0,
      lotId: (json['lot_id'] as num?)?.toInt() ?? 0,
      lotNo: json['lot_no']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transfer_id': transferId,
      'lot_id': lotId,
      'lot_no': lotNo,
      'quantity': quantity,
    };
  }
}
