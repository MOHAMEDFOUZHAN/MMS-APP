import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/app_providers.dart';



class LotDetailsSheet extends ConsumerStatefulWidget {
  final String materialCode;
  final MaterialModel? material;
  final bool isTabletEmbedded;

  const LotDetailsSheet({
    super.key,
    required this.materialCode,
    this.material,
    this.isTabletEmbedded = false,
  });

  @override
  ConsumerState<LotDetailsSheet> createState() => _LotDetailsSheetState();
}

class _LotDetailsSheetState extends ConsumerState<LotDetailsSheet> {
  final _reorderController = TextEditingController();

  @override
  void dispose() {
    _reorderController.dispose();
    super.dispose();
  }

  Future<void> _updateReorder(double currentReorder, String unit) async {
    _reorderController.text = currentReorder.toString();

    final newLevel = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Reorder Level'),
          content: TextField(
            controller: _reorderController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Reorder Level Threshold',
              suffixText: unit,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            GlassButton(
              text: 'Save',
              height: 40,
              onPressed: () {
                final val = double.tryParse(_reorderController.text);
                if (val != null && val >= 0) {
                  Navigator.pop(context, val);
                }
              },
            ),
          ],
        );
      },
    );

    if (newLevel != null) {
      await ref.read(materialsRepositoryProvider).updateReorderLevel(widget.materialCode, newLevel);
      ref.invalidate(materialsListProvider);
      ref.invalidate(materialLotsProvider(widget.materialCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reorder level updated to $newLevel $unit'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lotsAsync = ref.watch(materialLotsProvider(widget.materialCode));
    final mat = widget.material;

    Widget content = lotsAsync.when(
      loading: () => const LoadingSkeletonList(count: 3),
      error: (err, _) => Center(
        child: Text('Unable to load lots: $err', style: const TextStyle(color: AppColors.danger)),
      ),
      data: (lots) {
        final unit = mat?.unit ?? (lots.isNotEmpty ? lots.first.uom : 'kg');
        final totalLotStock = lots.fold<double>(0.0, (sum, item) => sum + item.availableQuantity);
        final totalOpening = lots.fold<double>(0.0, (sum, item) => sum + item.initialQuantity);
        final closingStock = mat?.closingStock ?? totalLotStock;
        final hasDiscrepancy = (totalLotStock - closingStock).abs() > 0.005;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Card
              GlassCard(
                accentColor: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            widget.materialCode,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          ),
                        ),
                        if (mat != null)
                          InkWell(
                            onTap: () => _updateReorder(mat.reorderLevel, unit),
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 14, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Reorder: ${mat.reorderLevel} $unit',
                                  style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mat?.description.isNotEmpty == true ? mat!.description : 'Material Details',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Category: ${mat?.category ?? "General"} • Grade: ${mat?.grade.isNotEmpty == true ? mat!.grade : "—"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Opening Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              QuantityFormatter.formatDualUnit(mat?.openingStock ?? totalOpening, unit),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Closing Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              QuantityFormatter.formatDualUnit(closingStock, unit),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reconciliation Warning if needed
              if (hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data Consistency Notice: Sum of lots (${QuantityFormatter.formatDualUnit(totalLotStock, unit)}) does not match closing stock (${QuantityFormatter.formatDualUnit(closingStock, unit)}).',
                          style: const TextStyle(fontSize: 11, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),

              // Lots List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INDIVIDUAL LOTS / BATCHES (${lots.length})',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                  Text(
                    'Total Available: ${QuantityFormatter.formatDualUnit(totalLotStock, unit)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (lots.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text('No lots available for this material.', style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final lot = lots[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lot.lotNo.isNotEmpty ? lot.lotNo : 'Default Lot',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: lot.isDepleted ? AppColors.danger.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  QuantityFormatter.formatDualUnit(lot.availableQuantity, lot.uom),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: lot.isDepleted ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Grade: ${lot.grade.isNotEmpty ? lot.grade : (mat?.grade.isNotEmpty == true ? mat!.grade : "—")}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Purchase Date: ${lot.formattedPurchaseDate}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Opening: ${QuantityFormatter.formatDualUnit(lot.initialQuantity, lot.uom)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Expiry Date: ${lot.formattedExpiryDate}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );


    if (widget.isTabletEmbedded) {
      return content;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDarker,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
