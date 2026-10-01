import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<NotificationModel>> fetchNotifications({
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('notifications').select();

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      throw AppException.from(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> recalculateAlerts() async {
    try {
      await _client.rpc('generate_inventory_alerts');

      // Check unread critical or warning notifications to alert user natively
      final unreadAlerts = await fetchNotifications(unreadOnly: true, limit: 3);
      for (final alert in unreadAlerts) {
        if (alert.isCritical || alert.isWarning) {
          NotificationService.instance.showFromNotificationRecord(
            id: alert.id,
            title: alert.title,
            message: alert.message,
            refType: alert.referenceType,
            refId: alert.referenceId,
            alertType: alert.type,
          );
        }
      }
    } catch (e) {
      debugPrint('Warning running generate_inventory_alerts: $e');
    }
  }
}
