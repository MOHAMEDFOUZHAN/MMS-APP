import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../../shared/widgets/status_badge.dart';
import '../providers/app_providers.dart';
import 'lot_details_sheet.dart';
import 'materials_master_screen.dart';
import 'new_material_dialog.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  String? _selectedCodeForTablet;

  Future<void> _handleNewMaterial() async {
    final authorized = await PinAuthDialog.show(
      context,
      title: 'Material Registration Security',
      message: 'Enter Supervisor PIN to register a new material code.',
    );

    if (!authorized || !mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const NewMaterialDialog(),
    );

    if (created == true) {
      ref.invalidate(materialsListProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  void _openLotDetails(MaterialModel mat) {
    if (ResponsiveBreakpoints.isTabletOrLarger(context)) {
      setState(() {
        _selectedCodeForTablet = mat.materialCode;
      });
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LotDetailsSheet(materialCode: mat.materialCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(materialsFilterProvider);
    final materialsAsync = ref.watch(materialsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xB30F172A),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Column(
              children: [
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
                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filters
                      _buildStatusFilterChip('all', 'All Status', filter.status),
                      _buildStatusFilterChip('reorder', '⚠️ Reorder', filter.status),
                      _buildStatusFilterChip('expiring', '⏱️ Expiring', filter.status),
                      _buildStatusFilterChip('out_of_stock', '❌ Out of Stock', filter.status),
                      const SizedBox(width: 12),
                      Container(height: 20, width: 1, color: AppColors.glassBorder),
                      const SizedBox(width: 12),
                      // Category dropdown chips
                      categoriesAsync.maybeWhen(
                        data: (cats) => Row(
                          children: [
                            _buildCategoryChip('All', filter.category),
                            ...cats.map((c) => _buildCategoryChip(c, filter.category)),
                          ],
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: materialsAsync.when(
              loading: () => const LoadingSkeletonList(count: 6),
              error: (err, _) => Center(
                child: EmptyStateWidget(
                  title: 'Unable to load inventory',
                  message: err.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(materialsListProvider),
                ),
              ),
              data: (materials) {
                if (materials.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No materials found',
                    message: 'Try changing your search term or filter status.',
                    actionLabel: '+ Register New Material',
                    onAction: _handleNewMaterial,
                  );
                }

                // Auto-select first item on tablet if none selected
                if (isTablet && _selectedCodeForTablet == null && materials.isNotEmpty) {
                  _selectedCodeForTablet = materials.first.materialCode;
                }

                if (isTablet) {
                  return Row(
                    children: [
                      // Left Column: Searchable List
                      Expanded(
                        flex: 5,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: materials.length,
                          itemBuilder: (context, i) {
                            final mat = materials[i];
                            final isSelected = mat.materialCode == _selectedCodeForTablet;
                            return _buildMaterialCard(mat, isSelected: isSelected);
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.glassBorder),
                      // Right Column: Lot Inspector
                      Expanded(
                        flex: 5,
                        child: _selectedCodeForTablet != null
                            ? LotDetailsSheet(
                                materialCode: _selectedCodeForTablet!,
                                isTabletEmbedded: true,
                              )
                            : const Center(
                                child: Text('Select an item to inspect lots', style: TextStyle(color: AppColors.textMuted)),
                              ),
                      ),
                    ],
                  );
                }

                // Mobile Card List
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: materials.length,
                  itemBuilder: (context, i) {
                    final mat = materials[i];
                    return _buildMaterialCard(mat);
                  },
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: NeonPill(
        label: label,
        color: isSelected ? AppColors.primary : AppColors.textMuted,
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

  Widget _buildMaterialCard(MaterialModel mat, {bool isSelected = false}) {
    String status = 'in_stock';
    if (mat.isOutOfStock) {
      status = 'out_of_stock';
    } else if (mat.isReorder) {
      status = 'reorder';
    } else if (mat.isExpiringSoon) {
      status = 'expiring';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: isSelected ? AppColors.primary : null,
        boxShadow: isSelected ? AppColors.neonGlow(AppColors.primary, blur: 16) : null,
        onTap: () => _openLotDetails(mat),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          mat.materialCode,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      if (mat.grade.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Gr: ${mat.grade}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mat.description.isNotEmpty ? mat.description : 'Unnamed Material',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      mat.category,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Stock: ',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      QuantityFormatter.formatDualUnit(mat.quantity, mat.unit),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: mat.isOutOfStock ? AppColors.danger : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (mat.lotNo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lot: ${mat.lotNo}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  if (mat.expiryDate != null)
                    Text(
                      'Exp: ${QuantityFormatter.formatDate(mat.expiryDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: mat.isExpiringSoon ? const Color(0xFFF97316) : AppColors.textMuted,
                        fontWeight: mat.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
