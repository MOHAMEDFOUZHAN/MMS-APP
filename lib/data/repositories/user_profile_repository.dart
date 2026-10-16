import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/user_profile_model.dart';

class UserProfileRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  UserProfileModel _fallbackProfile(User user) {
    final username = user.email?.split('@').first ?? 'user';
    final role = user.userMetadata?['role']?.toString().toUpperCase();
    final metaUsername = user.userMetadata?['username']?.toString().toLowerCase();
    final isBm = username == 'bm' ||
        username == 'tea' ||
        username == 'tea123' ||
        user.email == 'bm@benchmarkmms.com' ||
        role == 'TEA_USER' ||
        role == 'TEA' ||
        metaUsername == 'bm' ||
        metaUsername == 'tea' ||
        metaUsername == 'tea123';
    final isAdmin = username == 'admin' || user.email == 'admin@benchmarkmms.com';
    final isOwner = username == 'owner' || user.email == 'owner@benchmarkmms.com';

    if (isBm) {
      return UserProfileModel(
        id: user.id,
        username: 'bm',
        fullName: 'Tea Department',
        role: 'TEA_USER',
        permissions: const [
          'tea.*',
          'transfer.view',
          'transfer.create',
          'transfer.edit',
          'storage.view',
          'storage.create',
          'storage.edit',
          'dispatch.view',
          'dispatch.create',
          'dispatch.edit',
          'notifications.view'
        ],
      );
    }

    if (isOwner) {
      return UserProfileModel(
        id: user.id,
        username: 'owner',
        fullName: 'Management',
        role: 'OWNER',
        permissions: const ['owner.*', '*'],
      );
    }

    if (isAdmin) {
      return UserProfileModel(
        id: user.id,
        username: 'admin',
        fullName: 'Administrator',
        role: 'ADMIN',
        permissions: const ['*'],
      );
    }

    final isChocolate = username == 'chocolate' ||
        username == 'cho' ||
        username == 'choco' ||
        user.email == 'chocolate@benchmarkmms.com' ||
        role == 'CHOCOLATE_USER' ||
        role == 'CHOCOLATE' ||
        metaUsername == 'chocolate' ||
        metaUsername == 'cho';

    if (isChocolate) {
      return UserProfileModel(
        id: user.id,
        username: 'chocolate',
        fullName: 'Benchmark Chocolate Department',
        role: 'CHOCOLATE_USER',
        permissions: const [
          'chocolate.*',
          'ocr.*',
          'storage.*',
          'dispatch.*',
          'consign.*',
          'notifications.view'
        ],
      );
    }

    return UserProfileModel(
      id: user.id,
      username: username,
      fullName: user.userMetadata?['full_name'] ?? 'Staff User',
      role: 'STAFF',
      permissions: const ['materials.view', 'invoice.view', 'reports.view'],
    );
  }

  Future<UserProfileModel?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        return UserProfileModel.fromJson(res);
      }

      return _fallbackProfile(user);
    } catch (e) {
      // Safe fallback from in-memory user authentication state if DB query has network latency/error
      return _fallbackProfile(user);
    }
  }
}
