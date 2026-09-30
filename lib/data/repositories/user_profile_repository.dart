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
      final username = user.email?.split('@').first ?? 'bm';
      final isBm = username == 'bm' || user.email == 'bm@benchmarkmms.com';

      return UserProfileModel(
        id: user.id,
        username: username,
        fullName: isBm ? 'Benchmark Manager' : (user.userMetadata?['full_name'] ?? 'User'),
        role: isBm ? 'ADMIN' : 'STAFF',
        permissions: isBm
            ? [
                'materials.*',
                'invoice.*',
                'transfer.*',
                'dispatch.*',
                'stock_adjustment.*',
                'reports.*',
                'users.manage',
                'settings.manage'
              ]
            : ['materials.view', 'invoice.view', 'reports.view'],
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
