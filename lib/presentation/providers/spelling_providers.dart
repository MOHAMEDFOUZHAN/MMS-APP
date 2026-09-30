import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/utils/text_standardizer.dart';
import 'app_providers.dart';

/// Dynamic reference provider for all existing Material Categories.
final dynamicCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final materialsRepo = ref.watch(materialsRepositoryProvider);
  final categories = await materialsRepo.fetchCategories();
  
  final set = <String>{};
  for (final c in categories) {
    final norm = TextStandardizer.normalizeBusinessText(c);
    if (norm.isNotEmpty) set.add(norm);
  }
  
  const defaultCategories = [
    'CHOCOLATE',
    'TEA',
    'SPICES',
    'DRY FRUITS',
    'OIL',
    'VARKEY FACTORY',
    'PACKING',
    'GENERAL',
  ];
  for (final c in defaultCategories) {
    set.add(c);
  }

  final list = set.toList()..sort();
  return list;
});

/// Dynamic reference provider for all existing Material Descriptions.
final dynamicDescriptionsProvider = FutureProvider<List<String>>((ref) async {
  final materials = await ref.watch(materialsListProvider.future);
  final set = <String>{};
  
  for (final m in materials) {
    final desc = TextStandardizer.normalizeBusinessText(m.description);
    if (desc.isNotEmpty) set.add(desc);
  }

  final list = set.toList()..sort();
  return list;
});

/// Dynamic reference provider for all existing Departments.
final dynamicDepartmentsProvider = Provider<List<String>>((ref) {
  final set = <String>{};
  for (final d in FactoryConstants.departments) {
    set.add(TextStandardizer.normalizeBusinessText(d));
  }
  return set.toList()..sort();
});

/// Dynamic reference provider for all existing UOM Units.
final dynamicUnitsProvider = Provider<List<String>>((ref) {
  final set = <String>{};
  for (final u in FactoryConstants.units) {
    set.add(TextStandardizer.normalizeBusinessText(u));
  }
  return set.toList()..sort();
});

/// Dynamic reference provider for existing Vendor Names.
final dynamicVendorsProvider = FutureProvider<List<String>>((ref) async {
  final vendors = await ref.watch(vendorsListProvider(null).future);
  final set = <String>{};
  for (final v in vendors) {
    final name = TextStandardizer.normalizeBusinessText(v.name);
    if (name.isNotEmpty) set.add(name);
  }
  return set.toList()..sort();
});

/// Dynamic reference provider for existing Warehouse Shelf Locations.
final dynamicLocationsProvider = FutureProvider<List<String>>((ref) async {
  final locs = await ref.watch(categoryLocationsProvider.future);
  final set = <String>{};
  for (final l in locs) {
    final loc = TextStandardizer.normalizeBusinessText(l.location);
    if (loc.isNotEmpty) set.add(loc);
  }
  return set.toList()..sort();
});
