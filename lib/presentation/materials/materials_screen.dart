import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';

import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';
import 'materials_master_screen.dart';
import 'new_material_dialog.dart';
import 'widgets/material_summary_card.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  final Set<String> _expandedCodes = <String>{};

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
      ref.invalidate(materialsListProvider);
      ref.invalidate(materialsMasterListProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(gradesProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _pickDateRange() async {
    final currentFilter = ref.read(materialsFilterProvider);
    final initialRange = currentFilter.fromDate != null && currentFilter.toDate != null
        ? DateTimeRange(start: currentFilter.fromDate!, end: currentFilter.toDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.backgroundDarker,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.backgroundDarker,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(materialsFilterProvider.notifier).state = currentFilter.copyWith(
        fromDate: picked.start,
        toDate: picked.end,
      );
    }
  }

  void _clearDateRange() {
    ref.read(materialsFilterProvider.notifier).state =
        ref.read(materialsFilterProvider).copyWith(clearDates: true);
  }

  Future<void> _handlePrint(List<MaterialModel> materials) async {
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No materials found to print for the active filters.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final filter = ref.read(materialsFilterProvider);
    try {
      await PdfExportService.printLiveMaterialReport(
        materials,
        category: filter.category,
        searchQuery: filter.search,
        grade: filter.grade,
        status: filter.status,
        fromDate: filter.fromDate,
        toDate: filter.toDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(materialsFilterProvider);
    final materialsAsync = ref.watch(materialsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final gradesAsync = ref.watch(gradesProvider);
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);
    final hasDateFilter = filter.fromDate != null && filter.toDate != null;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Material'),
        onPressed: _handleNewMaterial,
      ),
      body: Column(
        children: [
          // Filter & Search Controls Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xB30F172A),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar, Print button and master sync button
                Row(
                  children: [
                    Expanded(
                      child: SearchBarWidget(
                        hintText: 'Search by material code, name, or lot...',
                        onChanged: (val) {
                          ref.read(materialsFilterProvider.notifier).state = filter.copyWith(search: val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Print Button (Category-filtered or All)
                    if (isTablet)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        ),
                        onPressed: () {
                          final list = materialsAsync.valueOrNull ?? [];
                          _handlePrint(list);
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: AppColors.accent),
                        tooltip: 'Print Live Material Report',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final list = materialsAsync.valueOrNull ?? [];
                          _handlePrint(list);
                        },
                      ),
                    const SizedBox(width: 8),
                    // Master data unit sync button
                    IconButton(
                      icon: const Icon(Icons.sync_alt_rounded, color: AppColors.primaryLight),
                      tooltip: 'Master Data / Unit Sync',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsMasterScreen()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Status & Date Filters Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filters
                      _buildStatusFilterChip('all', 'All', filter.status),
                      _buildStatusFilterChip('reorder', 'Reorder', filter.status),
                      _buildStatusFilterChip('expiring', 'Expiring', filter.status),
                      _buildStatusFilterChip('out_of_stock', 'Out of Stock', filter.status),

                      const SizedBox(width: 10),
                      Container(height: 20, width: 1, color: AppColors.glassBorder),
                      const SizedBox(width: 10),

                      // Date Range Picker Button
                      InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: hasDateFilter
                                ? AppColors.accent.withValues(alpha: 0.2)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: hasDateFilter ? AppColors.accent : AppColors.glassBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: hasDateFilter ? AppColors.accent : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasDateFilter
                                    ? '${QuantityFormatter.formatDate(filter.fromDate)} - ${QuantityFormatter.formatDate(filter.toDate)}'
                                    : 'Date Range',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: hasDateFilter ? AppColors.accent : AppColors.textSecondary,
                                ),
                              ),
                              if (hasDateFilter) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _clearDateRange,
                                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.accent),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Category & Grade Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Category Filter Label
                      const Text(
                        'Category:',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      // Categories
                      categoriesAsync.maybeWhen(
                        data: (cats) => Row(
                          children: [
                            _buildCategoryChip('All', filter.category),
                            ...cats.map((c) => _buildCategoryChip(c, filter.category)),
                          ],
                        ),
                        orElse: () => _buildCategoryChip('All', filter.category),
                      ),

                      const SizedBox(width: 12),
                      Container(height: 18, width: 1, color: AppColors.glassBorder),
                      const SizedBox(width: 12),

                      // Grade Filter Label
                      const Text(
                        'Grade:',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      // Grades
                      gradesAsync.maybeWhen(
                        data: (grades) => Row(
                          children: [
                            _buildGradeChip('All', filter.grade),
                            ...grades.map((g) => _buildGradeChip(g, filter.grade)),
                          ],
                        ),
                        orElse: () => _buildGradeChip('All', filter.grade),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Materials Content
          Expanded(
            child: materialsAsync.when(
              loading: () => const LoadingSkeletonList(count: 6),
              error: (err, _) => Center(
                child: EmptyStateWidget(
                  title: 'Unable to load materials',
                  message: 'Please verify your network connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(materialsListProvider),
                ),
              ),
              data: (materials) {
                if (materials.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No materials found',
                    message: 'Try adjusting your search term, category, or filter criteria.',
                    actionLabel: '+ Register New Material',
                    onAction: _handleNewMaterial,
                  );
                }

                // Auto-expand if single search result (e.g. search by lot or exact material)
                final isSingleSearchResult = materials.length == 1 && filter.search.trim().isNotEmpty;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 820 : double.infinity,
                    ),
                    child: RefreshIndicator(
                      color: AppColors.primaryLight,
                      backgroundColor: AppColors.backgroundDarker,
                      onRefresh: () async {
                        ref.invalidate(materialsListProvider);
                        ref.invalidate(categoriesProvider);
                        ref.invalidate(gradesProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                        itemCount: materials.length,
                        itemBuilder: (context, i) {
                          final mat = materials[i];
                          final isExpanded = isSingleSearchResult || _expandedCodes.contains(mat.materialCode);

                          return MaterialSummaryCard(
                            key: ValueKey(mat.materialCode),
                            material: mat,
                            isInitiallyExpanded: isExpanded,
                            onToggleExpand: () {
                              setState(() {
                                if (_expandedCodes.contains(mat.materialCode)) {
                                  _expandedCodes.remove(mat.materialCode);
                                } else {
                                  _expandedCodes.add(mat.materialCode);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String key, String label, String current) {
    final isSelected = key == current;
    final Color chipColor = switch (key) {
      'reorder' => AppColors.warning,
      'expiring' => const Color(0xFFF97316),
      'out_of_stock' => AppColors.danger,
      _ => AppColors.primary,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: NeonPill(
        label: label,
        color: isSelected ? chipColor : AppColors.textMuted,
        isSelected: isSelected,
        onTap: () {
          ref.read(materialsFilterProvider.notifier).state =
              ref.read(materialsFilterProvider).copyWith(status: key);
        },
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
          ref.read(materialsFilterProvider.notifier).state =
              ref.read(materialsFilterProvider).copyWith(category: cat);
        },
      ),
    );
  }

  Widget _buildGradeChip(String grade, String current) {
    final isSelected = grade == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: NeonPill(
        label: grade,
        color: isSelected ? AppColors.secondary : AppColors.textMuted,
        isSelected: isSelected,
        onTap: () {
          ref.read(materialsFilterProvider.notifier).state =
              ref.read(materialsFilterProvider).copyWith(grade: grade);
        },
      ),
    );
  }
}
