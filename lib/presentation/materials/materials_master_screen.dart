import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';

import 'new_material_dialog.dart';

class MaterialsMasterScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const MaterialsMasterScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<MaterialsMasterScreen> createState() => _MaterialsMasterScreenState();
}

class _MaterialsMasterScreenState extends ConsumerState<MaterialsMasterScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentSearch = ref.read(materialsMasterFilterProvider).search;
    _searchController.text = currentSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleNewMaterial() async {
    final authorized = await PinAuthDialog.show(
      context,
      title: 'Material Registration Security',
      message: 'Enter Supervisor PIN to register a new material code.',
    );

    if (!authorized || !mounted) return;

    final created = await showDialog<dynamic>(
      context: context,
      builder: (context) => const NewMaterialDialog(),
    );

    if (created != null && created != false) {
      ref.invalidate(materialsMasterListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(gradesProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _handleUnitUpdate(MaterialModel mat) async {
    String selectedUnit = mat.unit;

    final newUnit = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Sync Master Unit: ${mat.materialCode}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item: ${mat.description}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select New Unit of Measurement (UOM):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    dropdownColor: AppColors.surface,
                    items: FactoryConstants.units.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedUnit = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Atomic Synchronization Notice:', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Changing this unit will automatically and atomically update related records across:', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        Text('• Materials Live Inventory (unit)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('• Storage Register & Batches (uom)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('• Historical Inward Invoices (unit)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('• Department Transfers & Returns (units)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('• Outward Dispatches (units)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GlassButton(
                  text: 'Synchronize Unit',
                  height: 40,
                  onPressed: () => Navigator.pop(context, selectedUnit),
                ),
              ],
            );
          },
        );
      },
    );

    if (newUnit != null && newUnit != mat.unit) {
      if (!mounted) return;
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Confirm Global Unit Sync',
        message: 'Synchronize unit for ${mat.materialCode} from "${mat.unit}" to "$newUnit" across all tables?',
        confirmText: 'Yes, Synchronize All',
      );

      if (!confirmed || !mounted) return;

      try {
        await ref.read(materialsRepositoryProvider).updateMaterialUnit(mat.materialCode, newUnit);
        ref.invalidate(materialsMasterListProvider);
        ref.invalidate(materialsListProvider);
        ref.invalidate(activeBatchesProvider);
        ref.invalidate(dispatchesListProvider);
        ref.invalidate(transfersListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unit updated to $newUnit for ${mat.materialCode} across all records.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to synchronize unit: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCategoryUpdate(MaterialModel mat) async {
    final categoriesAsync = ref.read(categoriesProvider);
    final existingCategories = categoriesAsync.maybeWhen(
      data: (cats) => cats.where((c) => c.isNotEmpty && c != 'All').toList(),
      orElse: () => <String>['General', 'RAW TEA', 'PACKAGING', 'FLAVOUR', 'SPICES', 'CHOCOLATE'],
    );

    String selectedCategory = mat.category.isNotEmpty ? mat.category : 'General';
    final customCatController = TextEditingController();
    bool isCustom = !existingCategories.contains(selectedCategory);
    if (isCustom) customCatController.text = selectedCategory;

    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Change Category: ${mat.materialCode}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item: ${mat.description}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select Category:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: isCustom ? '__custom__' : (existingCategories.contains(selectedCategory) ? selectedCategory : null),
                      dropdownColor: AppColors.surface,
                      items: [
                        ...existingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        const DropdownMenuItem(value: '__custom__', child: Text('+ Enter Custom Category...')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            if (val == '__custom__') {
                              isCustom = true;
                            } else {
                              isCustom = false;
                              selectedCategory = val;
                            }
                          });
                        }
                      },
                    ),
                    if (isCustom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customCatController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Custom Category Name',
                          hintText: 'e.g. HERBAL, PACKAGING',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GlassButton(
                  text: 'Save Category',
                  height: 40,
                  onPressed: () {
                    final result = isCustom ? customCatController.text.trim() : selectedCategory;
                    if (result.isNotEmpty) {
                      Navigator.pop(context, result);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (newCategory != null && newCategory.isNotEmpty && newCategory != mat.category) {
      if (!mounted) return;
      try {
        await ref.read(materialsRepositoryProvider).updateMaterialCategory(mat.materialCode, newCategory);
        ref.invalidate(materialsMasterListProvider);
        ref.invalidate(materialsListProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(dashboardSummaryProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category for ${mat.materialCode} updated to "$newCategory".'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update category: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(materialsMasterFilterProvider);
    final materialsAsync = ref.watch(materialsMasterListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Materials Master Data'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Register New Material',
                  onPressed: _handleNewMaterial,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Material'),
        onPressed: _handleNewMaterial,
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Controls header: Search bar and category chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SearchBarWidget(
                          hintText: 'Search code or name across all master items...',
                          onChanged: (val) {
                            ref.read(materialsMasterFilterProvider.notifier).state =
                                filter.copyWith(search: val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Category:',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryChip('All', filter.category),
                        ...categoriesAsync.maybeWhen(
                          data: (cats) => cats.map((c) => _buildCategoryChip(c, filter.category)),
                          orElse: () => const <Widget>[],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Master List view
            Expanded(
              child: materialsAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    title: 'Unable to load master materials',
                    message: '$err',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(materialsMasterListProvider),
                  ),
                ),
                data: (materials) {
                  if (materials.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.dataset_outlined,
                      title: 'No master materials found',
                      message: 'Try adjusting your search query or category filter.',
                      actionLabel: '+ Register New Material',
                      onAction: _handleNewMaterial,
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primaryLight,
                    backgroundColor: AppColors.backgroundDarker,
                    onRefresh: () async {
                      ref.invalidate(materialsMasterListProvider);
                      ref.invalidate(categoriesProvider);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Results status bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${materials.length} Materials in Master Catalogue',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                              if (filter.category != 'All')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    filter.category,
                                    style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                            itemCount: materials.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final mat = materials[i];
                              return GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.dataset_outlined, color: AppColors.primaryLight, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                mat.materialCode,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _handleCategoryUpdate(mat),
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceLight,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppColors.glassBorder),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        mat.category,
                                                        style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      const Icon(Icons.edit_outlined, size: 10, color: AppColors.accent),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            mat.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.glassBorder),
                                          ),
                                          child: Text(
                                            'UOM: ${mat.unit}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _handleUnitUpdate(mat),
                                          child: const Text(
                                            'Change Unit',
                                            style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _handleCategoryUpdate(mat),
                                          child: const Text(
                                            'Change Category',
                                            style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String cat, String current) {
    final isSelected = cat == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: NeonPill(
        label: cat,
        color: isSelected ? AppColors.accent : AppColors.textMuted,
        isSelected: isSelected,
        onTap: () {
          ref.read(materialsMasterFilterProvider.notifier).state =
              ref.read(materialsMasterFilterProvider).copyWith(category: cat);
        },
      ),
    );
  }
}
