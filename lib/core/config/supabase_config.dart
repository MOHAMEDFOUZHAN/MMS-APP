import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Default values can be passed via --dart-define or fallback to production config
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_URL',
      defaultValue: 'https://japxiaxyabhhhclphbqr.supabase.co',
    ),
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa',
    ),
  );

  static const String ocrApiUrl = String.fromEnvironment(
    'OCR_API_URL',
    defaultValue: '',
  );

  static bool get isConfigured =>
      url != 'https://placeholder-mms.supabase.co' &&
      anonKey != 'placeholder-anon-key' &&
      url.isNotEmpty &&
      anonKey.isNotEmpty;

  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: SharedPreferencesLocalStorage(
            persistSessionKey: 'mms_auth_session',
          ),
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      debugPrint('Supabase initialized with URL: $url');
    } catch (e) {
      debugPrint('Supabase initialization warning: $e');
    }
  }
}
