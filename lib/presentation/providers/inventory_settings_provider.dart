import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_settings_model.dart';
import '../../data/repositories/inventory_settings_repository.dart';
import 'app_providers.dart';

final inventorySettingsRepositoryProvider = Provider<InventorySettingsRepository>((ref) {
  return InventorySettingsRepository();
});

class InventorySettingsNotifier extends StateNotifier<AsyncValue<InventorySettingsModel>> {
  final InventorySettingsRepository _repository;
  final Ref _ref;

  InventorySettingsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(InventorySettingsModel())) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _repository.fetchSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveSettings({
    required int invoiceMaterialExpiryAlertDays,
    required int storageProductExpiryAlertDays,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateSettings(
        invoiceMaterialExpiryAlertDays: invoiceMaterialExpiryAlertDays,
        storageProductExpiryAlertDays: storageProductExpiryAlertDays,
      );
      state = AsyncValue.data(updated);

      // Invalidate dependent providers so UI immediately updates
      _ref.invalidate(dashboardSummaryProvider);
      _ref.invalidate(materialsListProvider);
      _ref.invalidate(batchesListProvider);
      _ref.invalidate(activeBatchesProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final inventorySettingsProvider =
    StateNotifierProvider<InventorySettingsNotifier, AsyncValue<InventorySettingsModel>>((ref) {
  final repo = ref.watch(inventorySettingsRepositoryProvider);
  return InventorySettingsNotifier(repo, ref);
});
