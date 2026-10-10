class InventorySettingsModel {
  final int invoiceMaterialExpiryAlertDays;
  final int storageProductExpiryAlertDays;

  const InventorySettingsModel({
    this.invoiceMaterialExpiryAlertDays = 30,
    this.storageProductExpiryAlertDays = 30,
  });

  InventorySettingsModel copyWith({
    int? invoiceMaterialExpiryAlertDays,
    int? storageProductExpiryAlertDays,
  }) {
    return InventorySettingsModel(
      invoiceMaterialExpiryAlertDays: invoiceMaterialExpiryAlertDays ?? this.invoiceMaterialExpiryAlertDays,
      storageProductExpiryAlertDays: storageProductExpiryAlertDays ?? this.storageProductExpiryAlertDays,
    );
  }

  factory InventorySettingsModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    return InventorySettingsModel(
      invoiceMaterialExpiryAlertDays: parseInt(
        json['invoice_material_expiry_alert_days'] ?? json['invoice_days'],
        30,
      ),
      storageProductExpiryAlertDays: parseInt(
        json['storage_product_expiry_alert_days'] ?? json['storage_days'],
        30,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'invoice_material_expiry_alert_days': invoiceMaterialExpiryAlertDays,
    'storage_product_expiry_alert_days': storageProductExpiryAlertDays,
  };
}
