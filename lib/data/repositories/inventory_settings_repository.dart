import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/inventory_settings_model.dart';

class InventorySettingsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<InventorySettingsModel> fetchSettings() async {
    try {
      final res = await _client.rpc('get_inventory_settings');
      if (res is Map) {
        return InventorySettingsModel.fromJson(Map<String, dynamic>.from(res));
      }

      // Fallback query to system_settings directly
      final rows = await _client
          .from('system_settings')
          .select('key, value')
          .inFilter('key', ['invoice_material_expiry_alert_days', 'storage_product_expiry_alert_days']);

      int invDays = 30;
      int storDays = 30;

      for (final r in rows as List) {
        final key = r['key']?.toString();
        final val = r['value'];
        final parsed = val is num ? val.toInt() : int.tryParse(val?.toString() ?? '') ?? 30;
        if (key == 'invoice_material_expiry_alert_days') {
          invDays = parsed;
        } else if (key == 'storage_product_expiry_alert_days') {
          storDays = parsed;
        }
      }

      return InventorySettingsModel(
        invoiceMaterialExpiryAlertDays: invDays,
        storageProductExpiryAlertDays: storDays,
      );
    } catch (e) {
      debugPrint('Error fetching inventory settings: $e');
      return const InventorySettingsModel(); // Return defaults on offline or initial setup
    }
  }

  Future<InventorySettingsModel> updateSettings({
    required int invoiceMaterialExpiryAlertDays,
    required int storageProductExpiryAlertDays,
  }) async {
    if (invoiceMaterialExpiryAlertDays < 0) {
      throw AppException('Invoice Material Expiry Alert Days cannot be negative.');
    }
    if (storageProductExpiryAlertDays < 0) {
      throw AppException('Storage Product Expiry Alert Days cannot be negative.');
    }

    try {
      final res = await _client.rpc('update_inventory_settings', params: {
        'p_invoice_days': invoiceMaterialExpiryAlertDays,
        'p_storage_days': storageProductExpiryAlertDays,
      });

      if (res is Map) {
        return InventorySettingsModel.fromJson(Map<String, dynamic>.from(res));
      }

      return InventorySettingsModel(
        invoiceMaterialExpiryAlertDays: invoiceMaterialExpiryAlertDays,
        storageProductExpiryAlertDays: storageProductExpiryAlertDays,
      );
    } catch (e) {
      debugPrint('Error updating inventory settings: $e');
      throw AppException.from(e);
    }
  }
}
