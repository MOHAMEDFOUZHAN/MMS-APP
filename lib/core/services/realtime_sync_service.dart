import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../presentation/providers/app_providers.dart';

class RealtimeSyncService {
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;
  bool _isSubscribed = false;

  RealtimeSyncService(this._ref);

  void initialize() {
    if (!SupabaseConfig.isInitialized) return;
    if (_isSubscribed) return;

    final client = SupabaseConfig.client;

    try {
      _realtimeChannel = client.channel('public:mms_db_changes');

      // 1. Materials changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'materials',
        callback: (payload) {
          debugPrint('>>> Realtime: materials table changed (${payload.eventType})');
          _ref.invalidate(materialsListProvider);
          _ref.invalidate(dashboardSummaryProvider);
          _ref.invalidate(categoriesProvider);
        },
      );

      // 2. Invoices changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'invoices',
        callback: (payload) {
          debugPrint('>>> Realtime: invoices table changed (${payload.eventType})');
          _ref.invalidate(invoicesListProvider);
          _ref.invalidate(dashboardSummaryProvider);
        },
      );

      // 3. Batches changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'batches',
        callback: (payload) {
          debugPrint('>>> Realtime: batches table changed (${payload.eventType})');
          _ref.invalidate(activeBatchesProvider);
          _ref.invalidate(inwardHistoryProvider);
          _ref.invalidate(dashboardSummaryProvider);
        },
      );

      // 4. Dispatches changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dispatches',
        callback: (payload) {
          debugPrint('>>> Realtime: dispatches table changed (${payload.eventType})');
          _ref.invalidate(dispatchesListProvider);
          _ref.invalidate(dashboardSummaryProvider);
          _ref.invalidate(materialsListProvider);
        },
      );

      // 5. Transfers changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'transfers',
        callback: (payload) {
          debugPrint('>>> Realtime: transfers table changed (${payload.eventType})');
          _ref.invalidate(transfersListProvider);
          _ref.invalidate(dashboardSummaryProvider);
          _ref.invalidate(materialsListProvider);
        },
      );

      // 6. Stock adjustments changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'stock_adjustments',
        callback: (payload) {
          debugPrint('>>> Realtime: stock_adjustments table changed (${payload.eventType})');
          _ref.invalidate(stockAdjustmentsListProvider);
          _ref.invalidate(materialsListProvider);
          _ref.invalidate(dashboardSummaryProvider);
        },
      );

      // 7. Vendors changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'vendors',
        callback: (payload) {
          debugPrint('>>> Realtime: vendors table changed (${payload.eventType})');
          _ref.invalidate(vendorsListProvider);
        },
      );

      // 8. Category Locations changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'category_locations',
        callback: (payload) {
          debugPrint('>>> Realtime: category_locations table changed (${payload.eventType})');
          _ref.invalidate(categoryLocationsProvider);
        },
      );

      // 9. Notifications changes
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          debugPrint('>>> Realtime: notifications table changed (${payload.eventType})');
          _ref.invalidate(notificationsListProvider);
          _ref.invalidate(unreadNotificationsCountProvider);
        },
      );

      _realtimeChannel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('>>> Successfully subscribed to Supabase Realtime channel!');
          _isSubscribed = true;
        } else if (error != null) {
          debugPrint('>>> Realtime subscription warning: $error');
        }
      });
    } catch (e) {
      debugPrint('RealtimeSyncService initialization error: $e');
    }
  }

  void dispose() {
    if (_realtimeChannel != null && _isSubscribed) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
      _isSubscribed = false;
    }
  }
}

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
