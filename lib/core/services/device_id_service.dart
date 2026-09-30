import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _key = 'mms_device_unique_id';
  static String? _cachedDeviceId;

  static String generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = 'DEV-${generateUuid().substring(0, 8).toUpperCase()}';
      await prefs.setString(_key, id);
    }
    _cachedDeviceId = id;
    return id;
  }
}
