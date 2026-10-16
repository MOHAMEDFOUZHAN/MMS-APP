import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/tea_consumption_model.dart';
import '../../data/models/tea_material_received_model.dart';
import '../../data/repositories/tea_consumption_repository.dart';

class TeaConsumptionFilter {
  final String? search;
  final DateTime? fromDate;
  final DateTime? toDate;

  const TeaConsumptionFilter({
    this.search,
    this.fromDate,
    this.toDate,
  });

  TeaConsumptionFilter copyWith({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return TeaConsumptionFilter(
      search: search ?? this.search,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeaConsumptionFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(search, fromDate, toDate);
}

final teaConsumptionRepositoryProvider = Provider<TeaConsumptionRepository>((ref) {
  return TeaConsumptionRepository();
});

final teaTransferredMaterialsProvider = FutureProvider.autoDispose<List<TeaTransferredMaterial>>((ref) async {
  final repo = ref.watch(teaConsumptionRepositoryProvider);
  return repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);
});

final teaConsumptionFilterProvider = StateProvider<TeaConsumptionFilter>((ref) {
  return const TeaConsumptionFilter();
});

final teaConsumptionListProvider = FutureProvider.family<List<TeaConsumptionModel>, TeaConsumptionFilter>((ref, filter) async {
  final repo = ref.watch(teaConsumptionRepositoryProvider);
  return repo.fetchConsumptionEntries(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    search: filter.search,
  );
});

final teaDepartmentSummaryProvider = FutureProvider.autoDispose<TeaDepartmentSummary>((ref) async {
  final repo = ref.watch(teaConsumptionRepositoryProvider);
  return repo.fetchTeaDepartmentSummary();
});

class TeaMaterialReceivedFilter {
  final String? search;
  final String? category;
  final bool onlyWithBalance;

  const TeaMaterialReceivedFilter({
    this.search,
    this.category,
    this.onlyWithBalance = false,
  });

  TeaMaterialReceivedFilter copyWith({
    String? search,
    String? category,
    bool? onlyWithBalance,
  }) {
    return TeaMaterialReceivedFilter(
      search: search ?? this.search,
      category: category ?? this.category,
      onlyWithBalance: onlyWithBalance ?? this.onlyWithBalance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeaMaterialReceivedFilter &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          category == other.category &&
          onlyWithBalance == other.onlyWithBalance;

  @override
  int get hashCode => Object.hash(search, category, onlyWithBalance);
}

final teaMaterialReceivedFilterProvider = StateProvider<TeaMaterialReceivedFilter>((ref) {
  return const TeaMaterialReceivedFilter();
});

final teaMaterialReceivedListProvider = FutureProvider.family<List<TeaMaterialReceivedModel>, TeaMaterialReceivedFilter>((ref, filter) async {
  final repo = ref.watch(teaConsumptionRepositoryProvider);
  return repo.fetchTeaMaterialReceivedStock(
    search: filter.search,
    category: filter.category,
    onlyWithBalance: filter.onlyWithBalance,
  );
});

