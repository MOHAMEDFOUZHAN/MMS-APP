import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../../core/utils/expiry_helper.dart';
import '../../../data/models/material_lot_model.dart';
import '../../../data/models/material_model.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../providers/app_providers.dart';
import '../../providers/inventory_settings_provider.dart';

class MaterialSummaryCard extends ConsumerStatefulWidget {
  final MaterialModel material;
  final bool isInitiallyExpanded;
  final VoidCallback? onToggleExpand;

  const MaterialSummaryCard({
    super.key,
    required this.material,
    this.isInitiallyExpanded = false,
    this.onToggleExpand,
  });

  @override
  ConsumerState<MaterialSummaryCard> createState() => _MaterialSummaryCardState();
}

class _MaterialSummaryCardState extends ConsumerState<MaterialSummaryCard> {
  late bool _isExpanded;
  final _reorderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant MaterialSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isInitiallyExpanded != widget.isInitiallyExpanded) {
      _isExpanded = widget.isInitiallyExpanded;
    }
  }

  @override
  void dispose() {
    _reorderController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onToggleExpand?.call();
  }

  Future<void> _handleEditReorder() async {
    final mat = widget.material;
    _reorderController.text = QuantityFormatter.formatClean(mat.reorderLevel);

    final newLevel = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundDarker,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primaryLight, size: 22),
              const SizedBox(width: 8),
              Text(
                'Edit Reorder Level',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mat.materialCode} — ${mat.description}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reorderController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Reorder Threshold (${mat.unit})',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  suffixText: mat.unit,
                  suffixStyle: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryLight),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            GlassButton(
              text: 'Save Changes',
              height: 40,
              onPressed: () {
                final val = double.tryParse(_reorderController.text.trim());
                if (val != null && val >= 0) {
                  Navigator.pop(dialogCtx, val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid non-negative number.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );

    if (newLevel != null && mounted) {
      try {
        await ref.read(materialsRepositoryProvider).updateReorderLevel(mat.materialCode, newLevel);
        ref.invalidate(materialsListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reorder level updated to ${QuantityFormatter.formatClean(newLevel)} ${mat.unit}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update reorder level: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  int get _invoiceThreshold => ref.watch(inventorySettingsProvider).valueOrNull?.invoiceMaterialExpiryAlertDays ?? 30;

  String _getStockStatusKey(MaterialModel mat, int alertDays) {
    if (mat.isOutOfStock) return 'out_of_stock';
    if (mat.isReorder) return 'reorder';
    if (mat.expiryDate != null) {
      final info = ExpiryHelper.calculate(expiryDate: mat.expiryDate, alertDaysThreshold: alertDays);
      if (info.state == ExpiryState.expired) return 'expired';
      if (info.state == ExpiryState.expiringSoon) return 'expiring';
    }
    return 'in_stock';
  }

  @override
  Widget build(BuildContext context) {
    final mat = widget.material;
    final statusKey = _getStockStatusKey(mat, _invoiceThreshold);
    final lotCount = mat.lotCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: _isExpanded ? AppColors.primary.withValues(alpha: 0.6) : null,
        boxShadow: _isExpanded ? AppColors.neonGlow(AppColors.primary, blur: 14) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Code, Grade & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Material Code Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          mat.materialCode,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Grade Pill
                      if (mat.grade.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(
                            'Grade: ${mat.grade}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge(status: statusKey),
              ],
            ),
            const SizedBox(height: 8),

            // Material Description
            Text(
              mat.description.isNotEmpty ? mat.description : 'Unnamed Material',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),

            // Category
            Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  'Category: ${mat.category.isNotEmpty ? mat.category : "General"}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.glassBorder),
            const SizedBox(height: 10),

            // Stock Summary Breakdown (Opening, Purchased, Transfer Out, Return In)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33020617),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Opening',
                          value: QuantityFormatter.formatDualUnit(mat.openingStock, mat.unit),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Purchased',
                          value: QuantityFormatter.formatDualUnit(mat.purchased, mat.unit),
                          color: mat.purchased > 0 ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Transfer Out',
                          value: QuantityFormatter.formatDualUnit(mat.transferOut, mat.unit),
                          color: mat.transferOut > 0 ? AppColors.warning : AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Return In',
                          value: QuantityFormatter.formatDualUnit(mat.returnIn, mat.unit),
                          color: mat.returnIn > 0 ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Closing Stock Row (Emphasized)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 6),
                    Text(
                      'Closing Stock',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  QuantityFormatter.formatDualUnit(mat.closingStock, mat.unit),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: mat.isOutOfStock ? AppColors.danger : AppColors.primaryLight,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Secondary Info: Shelves/Bin & Reorder Level
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shelves / Bin
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Shelves/Bin: ${mat.shelvesBin}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                // Reorder Level with tap-to-edit
                InkWell(
                  onTap: _handleEditReorder,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, size: 11, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Reorder: ${QuantityFormatter.formatClean(mat.reorderLevel)} ${mat.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (mat.expiryDate != null) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final expInfo = ExpiryHelper.calculate(
                  expiryDate: mat.expiryDate,
                  alertDaysThreshold: _invoiceThreshold,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: expInfo.badgeColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: expInfo.textColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            expInfo.isExpired ? Icons.warning_amber_rounded : Icons.timer_outlined,
                            size: 13,
                            color: expInfo.textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Expiry: ${QuantityFormatter.formatDate(mat.expiryDate!)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: expInfo.textColor),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            expInfo.daysLabel,
                            style: TextStyle(fontSize: 11, color: expInfo.textColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: expInfo.textColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expInfo.statusLabel,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: expInfo.textColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.glassBorder),

            // Toggle Expand Button
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                          size: 18,
                          color: _isExpanded ? AppColors.primaryLight : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lotCount > 0 ? 'Individual Lots ($lotCount)' : 'Individual Lots (0)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isExpanded ? AppColors.primaryLight : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _isExpanded ? 'Tap to collapse' : 'Tap to expand',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable Lots Breakdown Section
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedLotsSection(mat),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildExpandedLotsSection(MaterialModel mat) {
    final lotsAsync = ref.watch(materialLotsProvider(mat.materialCode));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x40020617),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: lotsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
            ),
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Unable to load lots: $err', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ],
          ),
        ),
        data: (lots) {
          if (lots.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No lots available for this material.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          final sumLotAvail = lots.fold<double>(0.0, (acc, l) => acc + l.availableQuantity);
          final hasDiscrepancy = (sumLotAvail - mat.closingStock).abs() > 0.005;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reconciliation check bar
              if (hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Stock Discrepancy: Lots total ${QuantityFormatter.formatDualUnit(sumLotAvail, mat.unit)} vs Material Closing ${QuantityFormatter.formatDualUnit(mat.closingStock, mat.unit)}',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Reconciled: ${QuantityFormatter.formatDualUnit(sumLotAvail, mat.unit)} across ${lots.length} ${lots.length == 1 ? "lot" : "lots"}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              // Individual Lot Cards
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final lot = lots[i];
                  return _buildLotItemCard(lot, mat.unit, mat.grade);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLotItemCard(MaterialLotModel lot, String defaultUnit, String defaultGrade) {
    final lotUnit = lot.uom.isNotEmpty ? lot.uom : defaultUnit;
    final displayGrade = lot.grade.isNotEmpty ? lot.grade : (defaultGrade.isNotEmpty ? defaultGrade : '—');

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lot No & Available Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_outlined, size: 13, color: AppColors.accent),
                  const SizedBox(width: 5),
                  Text(
                    lot.lotNo.isNotEmpty ? lot.lotNo : 'Default Lot',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: lot.isDepleted
                      ? AppColors.danger.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Available: ${QuantityFormatter.formatDualUnit(lot.availableQuantity, lotUnit)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: lot.isDepleted ? AppColors.danger : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Key metadata row 1: Grade & Purchase Date (DD/MM/YYYY)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Grade: $displayGrade',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  'Purchase Date: ${lot.formattedPurchaseDate}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // Key metadata row 2: Opening & Expiry Date (DD/MM/YYYY)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Opening: ${QuantityFormatter.formatDualUnit(lot.initialQuantity, lotUnit)}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ),
              Expanded(
                child: Builder(builder: (context) {
                  final lotExpInfo = lot.expiryDate != null
                      ? ExpiryHelper.calculate(
                          expiryDate: lot.expiryDate,
                          alertDaysThreshold: _invoiceThreshold,
                        )
                      : null;
                  return Text(
                    'Expiry Date: ${lot.formattedExpiryDate}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: (lotExpInfo?.hasAlert ?? false) ? lotExpInfo!.textColor : AppColors.textMuted,
                      fontWeight: (lotExpInfo?.hasAlert ?? false) ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }),
              ),
            ],
          ),

          // If lot has expiry alert, display days remaining and status badge cleanly without overflow
          if (lot.expiryDate != null)
            Builder(builder: (context) {
              final lotExpInfo = ExpiryHelper.calculate(
                expiryDate: lot.expiryDate,
                alertDaysThreshold: _invoiceThreshold,
              );
              if (!lotExpInfo.hasAlert) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      lotExpInfo.daysLabel,
                      style: TextStyle(fontSize: 10.0, color: lotExpInfo.textColor, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    ExpiryHelper.buildBadge(lotExpInfo),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
