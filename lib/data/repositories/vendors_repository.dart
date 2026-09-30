import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/vendor_model.dart';

class VendorsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<VendorModel>> fetchVendors({String? search}) async {
    try {
      var query = _client.from('vendors').select();

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('name.ilike.%$term%,contact.ilike.%$term%,place.ilike.%$term%,gstin.ilike.%$term%,material.ilike.%$term%');
      }

      final response = await query.order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => VendorModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Map<String, dynamic> _standardizeVendorPayload(VendorModel vendor) {
    return {
      'name': TextStandardizer.normalizeBusinessText(vendor.name),
      'contact': vendor.contact.trim(),
      'place': TextStandardizer.normalizeBusinessText(vendor.place),
      'pincode': vendor.pincode.trim(),
      'gstin': TextStandardizer.normalizeCode(vendor.gstin),
      'material': TextStandardizer.normalizeBusinessText(vendor.material),
      'info': TextStandardizer.normalizeBusinessText(vendor.info),
    };
  }

  Future<void> addVendor(VendorModel vendor) async {
    try {
      await _client.from('vendors').insert(_standardizeVendorPayload(vendor));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateVendor(VendorModel vendor) async {
    try {
      await _client.from('vendors').update(_standardizeVendorPayload(vendor)).eq('id', vendor.id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteVendor(int id) async {
    try {
      await _client.from('vendors').delete().eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
