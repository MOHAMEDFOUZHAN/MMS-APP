import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/category_location_model.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../../data/models/dispatch_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/material_model.dart';
import '../../data/models/report_models.dart';
import '../../data/models/stock_adjustment_model.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/vendor_model.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/batches_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/dispatches_repository.dart';
import '../../data/repositories/invoices_repository.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/repositories/stock_adjustments_repository.dart';
import '../../data/repositories/transfers_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/repositories/vendors_repository.dart';
import '../../data/repositories/warehouse_repository.dart';

// ── Repository Providers ───────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) => MaterialsRepository());
final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) => InvoicesRepository(ref));
final batchesRepositoryProvider = Provider<BatchesRepository>((ref) => BatchesRepository());
final dispatchesRepositoryProvider = Provider<DispatchesRepository>((ref) => DispatchesRepository(ref));
final transfersRepositoryProvider = Provider<TransfersRepository>((ref) => TransfersRepository(ref));
final stockAdjustmentsRepositoryProvider = Provider<StockAdjustmentsRepository>((ref) => StockAdjustmentsRepository(ref));
final vendorsRepositoryProvider = Provider<VendorsRepository>((ref) => VendorsRepository());
final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) => WarehouseRepository());
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository());
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository());
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) => UserProfileRepository());

// ── Auth Notifier ──────────────────────────────────────────────────────────
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? userEmail;

  AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.userEmail,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? userEmail,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(AuthState()) {
    checkInitialSession();
  }

  void checkInitialSession() {
    if (_repo.isAuthenticated) {
      state = AuthState(
        status: AuthStatus.authenticated,
        userEmail: _repo.currentUser?.email ?? 'User',
      );
      // Initialize realtime sync automatically
      try {
        _ref.read(realtimeSyncServiceProvider);
      } catch (_) {}
    } else {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn(String usernameOrEmail, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final res = await _repo.signIn(usernameOrEmail: usernameOrEmail, password: password);
      state = AuthState(
        status: AuthStatus.authenticated,
        userEmail: res.user?.email ?? usernameOrEmail,
      );
      // Initialize realtime sync
      try {
        _ref.read(realtimeSyncServiceProvider);
      } catch (_) {}
      _ref.invalidate(currentUserProfileProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});

// ── Notifications Providers ────────────────────────────────────────────────
final notificationsListProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.fetchNotifications();
});

final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getUnreadCount();
});

// ── User Profile & Permissions Providers ───────────────────────────────────
final currentUserProfileProvider = FutureProvider.autoDispose<UserProfileModel?>((ref) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.fetchCurrentProfile();
});

final hasPermissionProvider = Provider.autoDispose.family<bool, String>((ref, perm) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return true;
  return profile.hasPermission(perm);
});

// ── Dashboard Provider ─────────────────────────────────────────────────────
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummaryModel>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchDashboardSummary();
});

// ── Materials Filter & List Provider ───────────────────────────────────────
class MaterialsFilter {
  final String search;
  final String category;
  final String status; // 'all', 'reorder', 'expiring', 'out_of_stock'

  MaterialsFilter({
    this.search = '',
    this.category = 'All',
    this.status = 'all',
  });

  MaterialsFilter copyWith({
    String? search,
    String? category,
    String? status,
  }) {
    return MaterialsFilter(
      search: search ?? this.search,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }
}

final materialsFilterProvider = StateProvider<MaterialsFilter>((ref) => MaterialsFilter());

final materialsListProvider = FutureProvider.autoDispose<List<MaterialModel>>((ref) async {
  final filter = ref.watch(materialsFilterProvider);
  final repo = ref.watch(materialsRepositoryProvider);

  return repo.fetchMaterials(
    search: filter.search,
    category: filter.category,
    status: filter.status,
  );
});

final categoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(materialsRepositoryProvider);
  return repo.fetchCategories();
});

final materialLotsProvider = FutureProvider.autoDispose.family<List<MaterialModel>, String>((ref, code) async {
  final repo = ref.watch(materialsRepositoryProvider);
  return repo.fetchMaterialLots(code);
});

class InvoicesFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const InvoicesFilter({this.search, this.fromDate, this.toDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoicesFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

class BatchesFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const BatchesFilter({this.search, this.fromDate, this.toDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchesFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

class DispatchesFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const DispatchesFilter({this.search, this.fromDate, this.toDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DispatchesFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

class TransfersFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const TransfersFilter({this.search, this.fromDate, this.toDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransfersFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

// ── Invoices Provider ──────────────────────────────────────────────────────
final invoicesListProvider = FutureProvider.autoDispose.family<List<InvoiceModel>, dynamic>((ref, param) async {
  final repo = ref.watch(invoicesRepositoryProvider);
  if (param is InvoicesFilter) {
    return repo.fetchInvoices(search: param.search, fromDate: param.fromDate, toDate: param.toDate);
  } else if (param is String) {
    return repo.fetchInvoices(search: param.isNotEmpty ? param : null);
  }
  return repo.fetchInvoices();
});

final invoiceDetailsProvider = FutureProvider.autoDispose.family<InvoiceModel, int>((ref, invoiceId) async {
  final repo = ref.watch(invoicesRepositoryProvider);
  return repo.fetchInvoiceDetails(invoiceId);
});

// ── Batches Provider ───────────────────────────────────────────────────────
final activeBatchesProvider = FutureProvider.autoDispose.family<List<BatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(batchesRepositoryProvider);
  if (param is BatchesFilter) {
    return repo.fetchActiveBatches(search: param.search, fromDate: param.fromDate, toDate: param.toDate);
  } else if (param is String) {
    return repo.fetchActiveBatches(search: param.isNotEmpty ? param : null);
  }
  return repo.fetchActiveBatches();
});

final inwardHistoryProvider = FutureProvider.autoDispose.family<List<BatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(batchesRepositoryProvider);
  if (param is BatchesFilter) {
    return repo.fetchInwardHistory(search: param.search, fromDate: param.fromDate, toDate: param.toDate);
  } else if (param is String) {
    return repo.fetchInwardHistory(search: param.isNotEmpty ? param : null);
  }
  return repo.fetchInwardHistory();
});

// ── Dispatches Provider ────────────────────────────────────────────────────
final dispatchesListProvider = FutureProvider.autoDispose.family<List<DispatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(dispatchesRepositoryProvider);
  if (param is DispatchesFilter) {
    return repo.fetchDispatches(search: param.search, fromDate: param.fromDate, toDate: param.toDate);
  } else if (param is String) {
    return repo.fetchDispatches(search: param.isNotEmpty ? param : null);
  }
  return repo.fetchDispatches();
});

// ── Transfers Provider ─────────────────────────────────────────────────────
final transfersListProvider = FutureProvider.autoDispose.family<List<TransferModel>, dynamic>((ref, param) async {
  final repo = ref.watch(transfersRepositoryProvider);
  if (param is TransfersFilter) {
    return repo.fetchTransfers(search: param.search, fromDate: param.fromDate, toDate: param.toDate);
  } else if (param is String) {
    return repo.fetchTransfers(search: param.isNotEmpty ? param : null);
  }
  return repo.fetchTransfers();
});

// ── Stock Adjustments Provider ─────────────────────────────────────────────
final stockAdjustmentsListProvider = FutureProvider.autoDispose<List<StockAdjustmentModel>>((ref) async {
  final repo = ref.watch(stockAdjustmentsRepositoryProvider);
  return repo.fetchAdjustments();
});

// ── Vendors Provider ───────────────────────────────────────────────────────
final vendorsListProvider = FutureProvider.autoDispose.family<List<VendorModel>, String?>((ref, search) async {
  final repo = ref.watch(vendorsRepositoryProvider);
  return repo.fetchVendors(search: search);
});

// ── Warehouse Category Shelf Mapping Provider ──────────────────────────────
final categoryLocationsProvider = FutureProvider.autoDispose<List<CategoryLocationModel>>((ref) async {
  final repo = ref.watch(warehouseRepositoryProvider);
  return repo.fetchCategoryLocations();
});

// ── Reports Providers ──────────────────────────────────────────────────────
final materialDirectoryReportProvider = FutureProvider.autoDispose<List<MaterialDirectoryRow>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.fetchMaterialDirectory();
});

final dailyLedgerReportProvider = FutureProvider.autoDispose.family<List<DailyLedgerRow>, DateTime>((ref, date) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.fetchDailyStockLedger(date);
});

final departmentConsumptionReportProvider = FutureProvider.autoDispose.family<List<DepartmentConsumptionRow>, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final from = params['from'] as DateTime;
  final to = params['to'] as DateTime;
  final dept = params['department'] as String?;
  return repo.fetchDepartmentConsumption(from, to, department: dept);
});

final murReportProvider = FutureProvider.autoDispose.family<List<MurReportRow>, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final start = params['start'] as DateTime;
  final end = params['end'] as DateTime;
  final cat = params['category'] as String?;
  return repo.fetchMurReport(startDate: start, endDate: end, category: cat);
});
