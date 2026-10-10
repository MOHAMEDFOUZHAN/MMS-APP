import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/owner_dashboard_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/owner_repository.dart';
import 'app_providers.dart';
import 'inventory_settings_provider.dart';

// ── Repository Provider ──────────────────────────────────────────────────────
final ownerRepositoryProvider = Provider<OwnerRepository>((ref) => OwnerRepository());

// ── Date Filter Types ────────────────────────────────────────────────────────
enum OwnerDateFilterType {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  allTime,
  custom,
}

class OwnerDateFilter {
  final OwnerDateFilterType type;
  final DateTime? customFrom;
  final DateTime? customTo;

  const OwnerDateFilter({
    this.type = OwnerDateFilterType.allTime,
    this.customFrom,
    this.customTo,
  });

  String get label {
    switch (type) {
      case OwnerDateFilterType.today:
        return 'Today';
      case OwnerDateFilterType.yesterday:
        return 'Yesterday';
      case OwnerDateFilterType.last7Days:
        return '7 Days';
      case OwnerDateFilterType.last30Days:
        return '30 Days';
      case OwnerDateFilterType.thisMonth:
        return 'This Month';
      case OwnerDateFilterType.lastMonth:
        return 'Last Month';
      case OwnerDateFilterType.allTime:
        return 'All Time';
      case OwnerDateFilterType.custom:
        return 'Custom';
    }
  }

  ({DateTime? from, DateTime? to}) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (type) {
      case OwnerDateFilterType.today:
        return (from: today, to: today);
      case OwnerDateFilterType.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: y);
      case OwnerDateFilterType.last7Days:
        return (from: today.subtract(const Duration(days: 7)), to: today);
      case OwnerDateFilterType.last30Days:
        return (from: today.subtract(const Duration(days: 30)), to: today);
      case OwnerDateFilterType.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case OwnerDateFilterType.lastMonth:
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastDayOfPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        final firstDayOfPrevMonth = DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month, 1);
        return (from: firstDayOfPrevMonth, to: lastDayOfPrevMonth);
      case OwnerDateFilterType.allTime:
        return (from: null, to: null);
      case OwnerDateFilterType.custom:
        return (from: customFrom, to: customTo);
    }
  }
}

final ownerDateFilterProvider = StateProvider<OwnerDateFilter>((ref) => const OwnerDateFilter());

// ── Owner Auth State & Notifier ──────────────────────────────────────────────
enum OwnerAuthStatus { initial, authenticated, unauthenticated, loading }

class OwnerAuthState {
  final OwnerAuthStatus status;
  final String? errorMessage;
  final String? userEmail;
  final String? fullName;
  final String? role;

  OwnerAuthState({
    this.status = OwnerAuthStatus.initial,
    this.errorMessage,
    this.userEmail,
    this.fullName,
    this.role,
  });

  OwnerAuthState copyWith({
    OwnerAuthStatus? status,
    String? errorMessage,
    String? userEmail,
    String? fullName,
    String? role,
  }) {
    return OwnerAuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      userEmail: userEmail ?? this.userEmail,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
    );
  }
}

class OwnerAuthNotifier extends StateNotifier<OwnerAuthState> {
  final AuthRepository _authRepo;
  final OwnerRepository _ownerRepo;

  OwnerAuthNotifier(this._authRepo, this._ownerRepo) : super(OwnerAuthState()) {
    checkInitialSession();
  }

  Future<void> checkInitialSession() async {
    if (!_authRepo.isAuthenticated) {
      state = OwnerAuthState(status: OwnerAuthStatus.unauthenticated);
      return;
    }

    try {
      final verify = await _ownerRepo.verifyOwnerAccess();
      state = OwnerAuthState(
        status: OwnerAuthStatus.authenticated,
        userEmail: verify['email']?.toString() ?? _authRepo.currentUser?.email,
        fullName: verify['full_name']?.toString() ?? 'Owner',
        role: verify['role']?.toString() ?? 'OWNER',
      );
    } catch (_) {
      // User is logged in as a normal operator/staff, not an owner
      state = OwnerAuthState(status: OwnerAuthStatus.unauthenticated);
    }
  }

  Future<bool> signInOwner(String usernameOrEmail, String password) async {
    state = state.copyWith(status: OwnerAuthStatus.loading, errorMessage: null);

    try {
      // 1. Authenticate with Supabase Auth
      final authRes = await _authRepo.signIn(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      if (authRes.user == null) {
        state = state.copyWith(
          status: OwnerAuthStatus.unauthenticated,
          errorMessage: 'Authentication failed. Please verify credentials.',
        );
        return false;
      }

      // 2. Strict Server-Side Owner Role Verification
      try {
        final verify = await _ownerRepo.verifyOwnerAccess();
        state = OwnerAuthState(
          status: OwnerAuthStatus.authenticated,
          userEmail: verify['email']?.toString() ?? authRes.user?.email,
          fullName: verify['full_name']?.toString() ?? 'Owner',
          role: verify['role']?.toString() ?? 'OWNER',
        );
        return true;
      } catch (verifyError) {
        // Not an owner! Revoke session immediately for security
        await _authRepo.signOut();
        state = state.copyWith(
          status: OwnerAuthStatus.unauthenticated,
          errorMessage: 'ACCESS DENIED: You do not have executive owner privileges.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: OwnerAuthStatus.unauthenticated,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<void> signOutOwner() async {
    await _authRepo.signOut();
    state = OwnerAuthState(status: OwnerAuthStatus.unauthenticated);
  }
}

final ownerAuthNotifierProvider = StateNotifierProvider<OwnerAuthNotifier, OwnerAuthState>((ref) {
  return OwnerAuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(ownerRepositoryProvider),
  );
});

// ── Dashboard Master Summary Provider ────────────────────────────────────────
final ownerDashboardSummaryProvider = FutureProvider.autoDispose<OwnerDashboardSummary>((ref) async {
  final repo = ref.watch(ownerRepositoryProvider);
  final dateFilter = ref.watch(ownerDateFilterProvider);
  final range = dateFilter.range;

  final settings = ref.watch(inventorySettingsProvider).valueOrNull;
  final invDays = settings?.invoiceMaterialExpiryAlertDays ?? 30;
  final storDays = settings?.storageProductExpiryAlertDays ?? 30;

  return repo.fetchOwnerDashboardSummary(
    fromDate: range.from,
    toDate: range.to,
    invoiceExpiryDays: invDays,
    storageExpiryDays: storDays,
  );
});

// ── Audit Logs Provider ──────────────────────────────────────────────────────
final ownerAuditLogsProvider = FutureProvider.autoDispose<List<OwnerActivityItem>>((ref) async {
  final repo = ref.watch(ownerRepositoryProvider);
  return repo.fetchAuditLogs(limit: 100);
});
