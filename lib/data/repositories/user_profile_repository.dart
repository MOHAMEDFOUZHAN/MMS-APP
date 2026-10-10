import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/user_profile_model.dart';

class UserProfileRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<UserProfileModel?> fetchCurrentProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        return UserProfileModel.fromJson(res);
      }

      // Default fallback profile if not yet created in table
      final username = user.email?.split('@').first ?? 'user';
      final isBm = username == 'bm' || user.email == 'bm@benchmarkmms.com';
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
          fullName: 'System Owner',
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

      return UserProfileModel(
        id: user.id,
        username: username,
        fullName: user.userMetadata?['full_name'] ?? 'Staff User',
        role: 'STAFF',
        permissions: const ['materials.view', 'invoice.view', 'reports.view'],
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
