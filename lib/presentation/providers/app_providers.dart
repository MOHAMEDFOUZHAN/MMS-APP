import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/category_location_model.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../../data/models/dispatch_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/material_lot_model.dart';
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
import '../../data/models/storage_product_model.dart';
import '../../data/repositories/storage_products_repository.dart';
import '../../data/repositories/transfers_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/repositories/vendors_repository.dart';
import 'inventory_settings_provider.dart';
import '../../data/repositories/warehouse_repository.dart';

// ── Repository Providers ───────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) => MaterialsRepository());
final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) => InvoicesRepository(ref));
final batchesRepositoryProvider = Provider<BatchesRepository>((ref) => BatchesRepository());
final dispatchesRepositoryProvider = Provider<DispatchesRepository>((ref) => DispatchesRepository(ref));
final storageProductsRepositoryProvider = Provider<StorageProductsRepository>((ref) => StorageProductsRepository());
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

final isTeaUserProvider = Provider<bool>((ref) {
  // 1. In-memory auth user (sync, 0ms latency)
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    final email = (user.email ?? '').toLowerCase();
    final username = email.split('@').first;
    final role = user.userMetadata?['role']?.toString().toUpperCase();
    final metaUsername = user.userMetadata?['username']?.toString().toLowerCase();
    if (email == 'bm@benchmarkmms.com' ||
        username == 'bm' ||
        username == 'tea' ||
        username == 'tea123' ||
        metaUsername == 'bm' ||
        metaUsername == 'tea' ||
        metaUsername == 'tea123' ||
        role == 'TEA_USER' ||
        role == 'TEA') {
      return true;
    }
  }

  // 2. AuthNotifier state
  final authEmail = (ref.watch(authNotifierProvider).userEmail ?? '').toLowerCase();
  if (authEmail.startsWith('bm@') ||
      authEmail == 'bm' ||
      authEmail.startsWith('tea@') ||
      authEmail == 'tea' ||
      authEmail.startsWith('tea123@') ||
      authEmail == 'tea123') {
    return true;
  }

  // 3. UserProfile from DB
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile != null && profile.isTeaUser) {
    return true;
  }

  return false;
});

// ── Dashboard Provider ─────────────────────────────────────────────────────
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummaryModel>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final settings = ref.watch(inventorySettingsProvider).valueOrNull;
  final invDays = settings?.invoiceMaterialExpiryAlertDays ?? 30;
  return repo.fetchDashboardSummary(invoiceMaterialExpiryAlertDays: invDays);
});

// ── Materials Filter & List Provider ───────────────────────────────────────
class MaterialsFilter {
  final String search;
  final String category;
  final String grade;
  final String status; // 'all', 'reorder', 'expiring', 'out_of_stock'
  final DateTime? fromDate;
  final DateTime? toDate;

  MaterialsFilter({
    this.search = '',
    this.category = 'All',
    this.grade = 'All',
    this.status = 'all',
    this.fromDate,
    this.toDate,
  });

  MaterialsFilter copyWith({
    String? search,
    String? category,
    String? grade,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates = false,
  }) {
    return MaterialsFilter(
      search: search ?? this.search,
      category: category ?? this.category,
      grade: grade ?? this.grade,
      status: status ?? this.status,
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
    );
  }
}

final materialsFilterProvider = StateProvider<MaterialsFilter>((ref) => MaterialsFilter());

final materialsListProvider = FutureProvider.autoDispose<List<MaterialModel>>((ref) async {
  final filter = ref.watch(materialsFilterProvider);
  final repo = ref.watch(materialsRepositoryProvider);
  final settings = ref.watch(inventorySettingsProvider).valueOrNull;
  final invDays = settings?.invoiceMaterialExpiryAlertDays ?? 30;

  return repo.fetchLiveMaterialsSummary(
    search: filter.search,
    category: filter.category,
    grade: filter.grade,
    status: filter.status,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    expiryDays: invDays,
  );
});

final categoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(materialsRepositoryProvider);
  return repo.fetchCategories();
});

final gradesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(materialsRepositoryProvider);
  return repo.fetchGrades();
});

final materialLotsProvider = FutureProvider.autoDispose.family<List<MaterialLotModel>, String>((ref, code) async {
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
  final BatchViewMode viewMode;
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const BatchesFilter({
    this.viewMode = BatchViewMode.inStock,
    this.search,
    this.fromDate,
    this.toDate,
  });

  BatchesFilter copyWith({
    BatchViewMode? viewMode,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return BatchesFilter(
      viewMode: viewMode ?? this.viewMode,
      search: search ?? this.search,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchesFilter &&
          runtimeType == other.runtimeType &&
          viewMode == other.viewMode &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(viewMode, search, fromDate, toDate);
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
final batchesListProvider = FutureProvider.autoDispose.family<List<BatchModel>, BatchesFilter>((ref, filter) async {
  final repo = ref.watch(batchesRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  return repo.fetchBatches(
    viewMode: filter.viewMode,
    search: filter.search,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    category: isTeaUser ? 'TEA' : null,
  );
});

final activeBatchesProvider = FutureProvider.autoDispose.family<List<BatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(batchesRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  final cat = isTeaUser ? 'TEA' : null;
  if (param is BatchesFilter) {
    return repo.fetchActiveBatches(search: param.search, fromDate: param.fromDate, toDate: param.toDate, category: cat);
  } else if (param is String) {
    return repo.fetchActiveBatches(search: param.isNotEmpty ? param : null, category: cat);
  }
  return repo.fetchActiveBatches(category: cat);
});

final inwardHistoryProvider = FutureProvider.autoDispose.family<List<BatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(batchesRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  final cat = isTeaUser ? 'TEA' : null;
  if (param is BatchesFilter) {
    return repo.fetchInwardHistory(search: param.search, fromDate: param.fromDate, toDate: param.toDate, category: cat);
  } else if (param is String) {
    return repo.fetchInwardHistory(search: param.isNotEmpty ? param : null, category: cat);
  }
  return repo.fetchInwardHistory(category: cat);
});

// ── Dispatches Provider ────────────────────────────────────────────────────
final dispatchesListProvider = FutureProvider.autoDispose.family<List<DispatchModel>, dynamic>((ref, param) async {
  final repo = ref.watch(dispatchesRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  final cat = isTeaUser ? 'TEA' : null;
  if (param is DispatchesFilter) {
    return repo.fetchDispatches(search: param.search, fromDate: param.fromDate, toDate: param.toDate, category: cat);
  } else if (param is String) {
    return repo.fetchDispatches(search: param.isNotEmpty ? param : null, category: cat);
  }
  return repo.fetchDispatches(category: cat);
});

// ── Storage Products Provider ──────────────────────────────────────────────
final storageProductsListProvider = FutureProvider.autoDispose.family<List<StorageProductModel>, String?>((ref, query) async {
  final repo = ref.watch(storageProductsRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  return repo.searchStorageProducts(query, category: isTeaUser ? 'TEA' : null);
});

final dispatchAvailableProductsProvider = FutureProvider.autoDispose.family<List<DispatchAvailableProductModel>, String?>((ref, query) async {
  final repo = ref.watch(storageProductsRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  return repo.getDispatchAvailableProducts(search: query, category: isTeaUser ? 'TEA' : null);
});

// ── Transfers Provider ─────────────────────────────────────────────────────
final transfersListProvider = FutureProvider.autoDispose.family<List<TransferModel>, dynamic>((ref, param) async {
  final repo = ref.watch(transfersRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  final cat = isTeaUser ? 'TEA' : null;
  if (param is TransfersFilter) {
    return repo.fetchTransfers(search: param.search, fromDate: param.fromDate, toDate: param.toDate, category: cat);
  } else if (param is String) {
    return repo.fetchTransfers(search: param.isNotEmpty ? param : null, category: cat);
  }
  return repo.fetchTransfers(category: cat);
});

final transferMaterialsProvider = FutureProvider.autoDispose<List<MaterialModel>>((ref) async {
  final repo = ref.watch(transfersRepositoryProvider);
  final isTeaUser = ref.watch(isTeaUserProvider);
  return repo.fetchTransferMaterials(category: isTeaUser ? 'TEA' : null);
});

final transferMaterialLotsProvider = FutureProvider.autoDispose.family<List<MaterialLotModel>, String>((ref, code) async {
  final repo = ref.watch(transfersRepositoryProvider);
  return repo.fetchLotsForMaterial(code);
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
