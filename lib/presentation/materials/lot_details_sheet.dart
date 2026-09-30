import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/app_providers.dart';

class LotDetailsSheet extends ConsumerStatefulWidget {
  final String materialCode;
  final bool isTabletEmbedded;

  const LotDetailsSheet({
    super.key,
    required this.materialCode,
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

  Future<void> _updateReorder(double currentReorder) async {
    _reorderController.text = currentReorder.toString();

    final newLevel = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Reorder Level'),
          content: TextField(
            controller: _reorderController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Reorder Level Threshold',
              suffixText: 'Units',
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
            content: Text('Reorder level updated to $newLevel'),
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

    Widget content = lotsAsync.when(
      loading: () => const LoadingSkeletonList(count: 3),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
      data: (lots) {
        if (lots.isEmpty) {
          return const Center(child: Text('No lots recorded for this material.', style: TextStyle(color: AppColors.textMuted)));
        }

        final primaryMat = lots.first;
        final totalStock = lots.fold<double>(0.0, (sum, item) => sum + item.quantity);
        final totalOpening = lots.fold<double>(0.0, (sum, item) => sum + item.openingStock);

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
                          ),
                          child: Text(
                            primaryMat.materialCode,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          ),
                        ),
                        InkWell(
                          onTap: () => _updateReorder(primaryMat.reorderLevel),
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 14, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                'Reorder: ${primaryMat.reorderLevel} ${primaryMat.unit}',
                                style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      primaryMat.description,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Category: ${primaryMat.category} • UOM: ${primaryMat.unit}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                              QuantityFormatter.formatDualUnit(totalOpening, primaryMat.unit),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Current Total Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              QuantityFormatter.formatDualUnit(totalStock, primaryMat.unit),
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

              // Lots List
              Text(
                'Individual Batches & Lots (${lots.length})',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

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
                              lot.lotNo.isNotEmpty ? 'Lot: ${lot.lotNo}' : 'Default Lot',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13),
                            ),
                            Text(
                              QuantityFormatter.formatDualUnit(lot.quantity, lot.unit),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: lot.isOutOfStock ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Purchased: ${QuantityFormatter.formatDate(lot.purchaseDate)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            if (lot.expiryDate != null)
                              Text(
                                'Expiry: ${QuantityFormatter.formatDate(lot.expiryDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: lot.isExpiringSoon ? const Color(0xFFF97316) : AppColors.textMuted,
                                  fontWeight: lot.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        if (lot.unitPrice > 0 || lot.grade.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (lot.unitPrice > 0)
                                Text(
                                  'Price: ${QuantityFormatter.formatCurrency(lot.unitPrice)} / ${lot.unit}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              if (lot.grade.isNotEmpty)
                                Text(
                                  'Grade: ${lot.grade}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ],
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
