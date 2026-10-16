import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chocolate_ocr_ledger_model.dart';
import '../../data/repositories/chocolate_ocr_repository.dart';

final chocolateOcrRepositoryProvider = Provider<ChocolateOcrRepository>((ref) {
  return ChocolateOcrRepository();
});

final chocolateOcrLedgerProvider = FutureProvider<List<ChocolateOcrLedgerModel>>((ref) async {
  final repo = ref.watch(chocolateOcrRepositoryProvider);
  return repo.fetchLedger();
});
