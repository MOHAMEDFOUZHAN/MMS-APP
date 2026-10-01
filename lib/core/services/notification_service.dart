import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

class NotificationPayload {
  final String refType;
  final String refId;

  const NotificationPayload({required this.refType, required this.refId});

  factory NotificationPayload.parse(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return NotificationPayload(refType: parts[0], refId: parts.sublist(1).join(':'));
    }
    return NotificationPayload(refType: raw, refId: '');
  }

  @override
  String toString() => '$refType:$refId';
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final StreamController<NotificationPayload> _notificationSelectedController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationSelected =>
      _notificationSelectedController.stream;

  // Notification channels
  static const String channelStockAlerts = 'mms_stock_alerts';
  static const String channelInvoices = 'mms_invoices';
  static const String channelSystem = 'mms_system';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            debugPrint('>>> Notification tapped with payload: $payload');
            _notificationSelectedController.add(NotificationPayload.parse(payload));
          }
        },
      );

      // Create notification channels for Android 8.0+
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Request runtime permission for Android 13+ (API 33)
        await androidPlugin.requestNotificationsPermission();

        // 1. Stock & Expiry Alerts Channel (High Priority with Sound & Vibration)
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelStockAlerts,
            'Stock & Expiry Alerts',
            description: 'Critical notifications for low stock levels, depleted items, and expiring batches',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

        // 2. Invoices & Dispatches Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelInvoices,
            'Invoices, Dispatches & Transfers',
            description: 'Real-time updates when new invoices, dispatches, or material transfers are recorded',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

        // 3. System & Background Sync Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelSystem,
            'System & Sync Notifications',
            description: 'General system notifications, offline queue sync, and background alerts',
            importance: Importance.defaultImportance,
            enableVibration: false,
            playSound: false,
            showBadge: false,
          ),
        );
      }

      _isInitialized = true;
      debugPrint('>>> NotificationService successfully initialized with native Android channels');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Show a general notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelStockAlerts,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == channelStockAlerts
            ? 'Stock & Expiry Alerts'
            : channelId == channelInvoices
                ? 'Invoices, Dispatches & Transfers'
                : 'System & Sync Notifications',
        channelDescription: 'Benchmark MMS native push notification',
        importance: channelId == channelStockAlerts ? Importance.max : Importance.high,
        priority: channelId == channelStockAlerts ? Priority.high : Priority.defaultPriority,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(body),
        icon: '@mipmap/ic_launcher',
      );

      final details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Show Low Stock Alert Notification
  Future<void> showLowStockAlert({
    required String materialName,
    required double currentStock,
    required double minStock,
    required String uom,
    String? materialId,
  }) async {
    final title = '⚠️ Low Stock Alert: $materialName';
    final body =
        'Current stock is ${currentStock.toStringAsFixed(1)} $uom (below minimum threshold of ${minStock.toStringAsFixed(1)} $uom). Tap to inspect.';
    final id = (materialName.hashCode & 0x7FFFFFFF);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'material:${materialId ?? materialName}',
      channelId: channelStockAlerts,
    );
  }

  /// Show Expiry Alert Notification
  Future<void> showExpiryAlert({
    required String batchNumber,
    required String materialName,
    required int daysLeft,
    String? batchId,
  }) async {
    final title = daysLeft <= 0
        ? '🚨 Expired Batch: $batchNumber'
        : '⏳ Expiry Alert: $batchNumber ($daysLeft days left)';
    final body = daysLeft <= 0
        ? 'Batch $batchNumber for $materialName has expired. Immediate quarantine or disposition required.'
        : 'Batch $batchNumber for $materialName will expire in $daysLeft days. Tap to review storage.';
    final id = (batchNumber.hashCode & 0x7FFFFFFF);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'batch:${batchId ?? batchNumber}',
      channelId: channelStockAlerts,
    );
  }

  /// Show Invoice Notification
  Future<void> showInvoiceNotification({
    required String invoiceNumber,
    required String vendorName,
    required double totalAmount,
    String? invoiceId,
  }) async {
    final title = '📄 New Inward Invoice: $invoiceNumber';
    final body = 'Received from $vendorName. Total amount: ₹${totalAmount.toStringAsFixed(2)}. Tap to view details.';
    final id = (invoiceNumber.hashCode & 0x7FFFFFFF);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'invoice:${invoiceId ?? invoiceNumber}',
      channelId: channelInvoices,
    );
  }

  /// Show Dispatch Notification
  Future<void> showDispatchNotification({
    required String dispatchNumber,
    required String destination,
    required int itemCount,
    String? dispatchId,
  }) async {
    final title = '📦 Dispatch Completed: $dispatchNumber';
    final body = 'Sent $itemCount items to $destination. Tap to view dispatch records.';
    final id = (dispatchNumber.hashCode & 0x7FFFFFFF);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'dispatch:${dispatchId ?? dispatchNumber}',
      channelId: channelInvoices,
    );
  }

  /// Show Transfer Notification
  Future<void> showTransferNotification({
    required String transferNumber,
    required String sourceLoc,
    required String destLoc,
    String? transferId,
  }) async {
    final title = '🔄 Material Transfer: $transferNumber';
    final body = 'Transferred materials from $sourceLoc to $destLoc. Tap to review.';
    final id = (transferNumber.hashCode & 0x7FFFFFFF);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'transfer:${transferId ?? transferNumber}',
      channelId: channelInvoices,
    );
  }

  /// Show Alert from Supabase Notification Record
  Future<void> showFromNotificationRecord({
    required int id,
    required String title,
    required String message,
    String? refType,
    String? refId,
    String? alertType,
  }) async {
    final channel = (alertType == 'low_stock' || alertType == 'expiry')
        ? channelStockAlerts
        : channelInvoices;

    final payload = (refType != null && refType.isNotEmpty)
        ? '$refType:${refId ?? ""}'
        : null;

    await showNotification(
      id: id,
      title: title,
      body: message,
      payload: payload,
      channelId: channel,
    );
  }

  /// Sync FCM Device Token to Supabase device_tokens table
  Future<void> syncDeviceToken(String fcmToken) async {
    if (!SupabaseConfig.isInitialized) return;
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      await SupabaseConfig.client.from('device_tokens').upsert({
        'token': fcmToken,
        'user_id': user?.id,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
      debugPrint('>>> FCM token registered with Supabase successfully');
    } catch (e) {
      debugPrint('Warning syncing device token to Supabase: $e');
    }
  }

  void dispose() {
    _notificationSelectedController.close();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
