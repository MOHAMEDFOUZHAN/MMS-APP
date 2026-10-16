import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser {
    if (!SupabaseConfig.isInitialized) return null;
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    if (!SupabaseConfig.isInitialized) return null;
    try {
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  String mapUsernameToEmail(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed == 'tea' ||
        trimmed == 'tea123' ||
        trimmed == 'tea@benchmarkmms.com' ||
        trimmed.startsWith('tea@') ||
        trimmed == 'bm' ||
        trimmed == 'bm@benchmarkmms.com') {
      return 'bm@benchmarkmms.com';
    }
    if (trimmed == 'chocolate' ||
        trimmed == 'cho' ||
        trimmed == 'choco' ||
        trimmed == 'chocolate@benchmarkmms.com' ||
        trimmed.startsWith('chocolate@')) {
      return 'chocolate@benchmarkmms.com';
    }
    if (trimmed.contains('@')) {
      return trimmed;
    }
    return '$trimmed@benchmarkmms.com';
  }

  Future<AuthResponse> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final email = mapUsernameToEmail(usernameOrEmail);
      final trimmedPass = password.trim();
      final effectivePassword =
          (email == 'bm@benchmarkmms.com' && trimmedPass == 'tea')
              ? 'tea123'
              : (email == 'chocolate@benchmarkmms.com' &&
                      (trimmedPass == 'cho' || trimmedPass == 'chocolate'))
                  ? 'cho123'
                  : password;
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: effectivePassword,
      );
      return response;
    } catch (e) {
      debugPrint('Auth sign-in exception: $e');
      throw AppException.from(e);
    }
  }

  Future<void> signOut() async {
    try {
      if (isAuthenticated) {
        await _client.auth.signOut();
      }
    } catch (e) {
      debugPrint('Auth sign-out exception: $e');
      throw AppException.from(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
