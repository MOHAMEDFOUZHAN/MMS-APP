import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/owner_dashboard_model.dart';

class OwnerRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Authoritative server-side role verification for Owner privileges
  Future<Map<String, dynamic>> verifyOwnerAccess() async {
    try {
      final res = await _client.rpc('verify_owner_access');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'authorized': true};
    } catch (e) {
      debugPrint('Owner access verification failed: $e');
      throw AppException.from(e);
    }
  }

  /// Authoritative master summary aggregation for the Owner Executive Portal
  Future<OwnerDashboardSummary> fetchOwnerDashboardSummary({
    DateTime? fromDate,
    DateTime? toDate,
    int invoiceExpiryDays = 30,
    int storageExpiryDays = 30,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_invoice_expiry_days': invoiceExpiryDays,
        'p_storage_expiry_days': storageExpiryDays,
      };

      if (fromDate != null) {
        params['p_from_date'] = fromDate.toIso8601String().split('T')[0];
      }
      if (toDate != null) {
        params['p_to_date'] = toDate.toIso8601String().split('T')[0];
      }

      final res = await _client.rpc('get_owner_dashboard_summary', params: params);
      if (res is Map) {
        return OwnerDashboardSummary.fromJson(Map<String, dynamic>.from(res));
      }
      throw AppException('Invalid server response format for owner dashboard');
    } catch (e) {
      debugPrint('Error loading owner dashboard summary: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch full audit log trail for the Owner Activity & Audit section
  Future<List<OwnerActivityItem>> fetchAuditLogs({int limit = 100}) async {
    try {
      final res = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final dt = DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now();
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minuteStr = dt.minute.toString().padLeft(2, '0');
        map['time_ampm'] = '$hour:$minuteStr $ampm';
        map['date_str'] = dt.toIso8601String().split('T')[0];
        return OwnerActivityItem.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      throw AppException.from(e);
    }
  }
}
