import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chocolate_consumption_model.dart';
import '../../data/repositories/chocolate_consumption_repository.dart';

class ChocolateConsumptionFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ChocolateConsumptionFilter({
    this.search,
    this.fromDate,
    this.toDate,
  });

  ChocolateConsumptionFilter copyWith({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return ChocolateConsumptionFilter(
      search: search ?? this.search,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChocolateConsumptionFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

final chocolateConsumptionRepositoryProvider = Provider<ChocolateConsumptionRepository>((ref) {
  return ChocolateConsumptionRepository(ref);
});

final chocolateTransferredMaterialsProvider = FutureProvider.autoDispose<List<ChocolateTransferredMaterial>>((ref) async {
  final repo = ref.watch(chocolateConsumptionRepositoryProvider);
  return repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);
});

final chocolateConsumptionFilterProvider = StateProvider<ChocolateConsumptionFilter>((ref) {
  return const ChocolateConsumptionFilter();
});

final chocolateConsumptionListProvider = FutureProvider.family<List<ChocolateConsumptionModel>, ChocolateConsumptionFilter>((ref, filter) async {
  final repo = ref.watch(chocolateConsumptionRepositoryProvider);
  return repo.fetchConsumptionEntries(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    search: filter.search,
  );
});

final chocolateDepartmentSummaryProvider = FutureProvider.autoDispose<ChocolateDepartmentSummary>((ref) async {
  final repo = ref.watch(chocolateConsumptionRepositoryProvider);
  return repo.fetchChocolateDepartmentSummary();
});
