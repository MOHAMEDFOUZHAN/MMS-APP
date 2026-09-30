import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/services/pdf_export_service.dart';
import '../../data/models/invoice_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/status_badge.dart';
import '../providers/app_providers.dart';
import 'add_invoice_screen.dart';

class ViewInvoiceScreen extends ConsumerStatefulWidget {
  final int invoiceId;

  const ViewInvoiceScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<ViewInvoiceScreen> createState() => _ViewInvoiceScreenState();
}

class _ViewInvoiceScreenState extends ConsumerState<ViewInvoiceScreen> {
  bool _isDeleting = false;

  Future<void> _deleteInvoice(InvoiceModel inv) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Invoice ${inv.invoiceNo}?',
      message: 'Deleting this inward invoice will atomically reverse and decrement the stock for all line items from live materials inventory. This action cannot be undone.',
      confirmText: 'Yes, Delete & Reverse Stock',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(invoicesRepositoryProvider).deleteInvoice(inv.id);
      ref.invalidate(invoicesListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice deleted and material stock reverted successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete invoice: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceDetailsProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          invoiceAsync.maybeWhen(
            data: (inv) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight),
                  tooltip: 'Print Tax Invoice (A4 PDF)',
                  onPressed: () => PdfExportService.printInvoice(inv),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                  tooltip: 'Share Invoice PDF',
                  onPressed: () => PdfExportService.printInvoice(inv, share: true),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
                  tooltip: 'Edit Invoice',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddInvoiceScreen(existingInvoice: inv)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Delete & Rollback Stock',
                  onPressed: _isDeleting ? null : () => _deleteInvoice(inv),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AmbientBackground(
        child: invoiceAsync.when(
          loading: () => const LoadingSkeletonList(count: 4),
          error: (err, _) => Center(
            child: EmptyStateWidget(
              title: 'Unable to load invoice',
              message: err.toString(),
            ),
          ),
          data: (inv) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
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
                                inv.invoiceNo,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                              ),
                            ),
                            StatusBadge(status: inv.paymentStatus),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          inv.vendor,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Date: ${QuantityFormatter.formatDate(inv.date)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (inv.purchaseId.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text('• Purchase ID: ${inv.purchaseId}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ],
                        ),
                        if (inv.remarks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Remarks: ${inv.remarks}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Line Items Section
                  Text(
                    'Line Items (${inv.items.length})',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: inv.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = inv.items[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.material,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryLight),
                                ),
                                Text(
                                  QuantityFormatter.formatCurrency(item.itemTotal),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Qty: ${QuantityFormatter.formatDualUnit(item.quantity, item.unit)} @ ${QuantityFormatter.formatCurrency(item.unitPrice)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'Tax: ${QuantityFormatter.formatCurrency(item.itemGstValue + item.itemIgstValue)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            if (item.batchNo.isNotEmpty || item.grade.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (item.batchNo.isNotEmpty)
                                    Text('Batch: ${item.batchNo}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  if (item.grade.isNotEmpty)
                                    Text('Grade: ${item.grade}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Financial Totals
                  GlassCard(
                    child: Column(
                      children: [
                        _buildRow('Subtotal (Excl. Tax)', QuantityFormatter.formatCurrency(inv.totalExclTax)),
                        const SizedBox(height: 6),
                        _buildRow('Total GST', QuantityFormatter.formatCurrency(inv.totalGst)),
                        const SizedBox(height: 6),
                        _buildRow('Total IGST', QuantityFormatter.formatCurrency(inv.totalIgst)),
                        const Divider(height: 16),
                        _buildRow('Grand Total', QuantityFormatter.formatCurrency(inv.grandTotal), isBold: true),
                        if (inv.roundOffValue != 0) ...[
                          const SizedBox(height: 6),
                          _buildRow('Round Off', QuantityFormatter.formatCurrency(inv.roundOffValue)),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Final Total', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text(
                              QuantityFormatter.formatCurrency(inv.finalTotal > 0 ? inv.finalTotal : inv.grandTotal),
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
