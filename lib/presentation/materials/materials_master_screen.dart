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

class MaterialsMasterScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const MaterialsMasterScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<MaterialsMasterScreen> createState() => _MaterialsMasterScreenState();
}

class _MaterialsMasterScreenState extends ConsumerState<MaterialsMasterScreen> {
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsListProvider);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Materials Master Data'),
            ),
      body: AmbientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(
                hintText: 'Search material to manage master UOM...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: materialsAsync.when(
                loading: () => const LoadingSkeletonList(count: 5),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
                data: (materials) {
                  final filtered = materials.where((m) {
                    if (_search.isEmpty) return true;
                    return m.materialCode.toLowerCase().contains(_search) ||
                        m.description.toLowerCase().contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No master materials found',
                      message: 'Search with another term.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final mat = filtered[i];
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
                              child: const Icon(Icons.sync_alt_rounded, color: AppColors.primaryLight, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mat.materialCode,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                                  ),
                                  Text(
                                    mat.description,
                                    maxLines: 1,
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
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
