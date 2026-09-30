import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/invoice_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../../shared/widgets/status_badge.dart';
import '../providers/app_providers.dart';
import '../../core/services/pdf_export_service.dart';
import 'add_invoice_screen.dart';
import 'multi_page_scan_screen.dart';
import 'ocr_scan_screen.dart';
import 'view_invoice_screen.dart';
import 'without_invoice_screen.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _deleteInvoice(InvoiceModel inv) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Invoice ${inv.invoiceNo}?',
      message: 'Deleting this inward invoice will atomically reverse and decrement the stock for all line items from live materials inventory. This action cannot be undone.',
      confirmText: 'Yes, Delete & Reverse Stock',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

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
      }
    } catch (e) {
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
    final filter = InvoicesFilter(
      search: _search.isNotEmpty ? _search : null,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final invoicesAsync = ref.watch(invoicesListProvider(filter));

    final hasInvoices = invoicesAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      floatingActionButton: hasInvoices
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Invoice'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen()));
              },
            )
          : null,
      body: Column(
        children: [
          // Unified Global Search & Date Filter Bar
          GlobalSearchFilterBar(
            hintText: 'Search by Code, Description or Category',
            initialSearch: _search,
            initialFromDate: _fromDate,
            initialToDate: _toDate,
            onSearchChanged: (val) => setState(() => _search = val.trim()),
            onApply: (search, from, to) {
              setState(() {
                _search = search;
                _fromDate = from;
                _toDate = to;
              });
            },
            onClear: () {
              setState(() {
                _search = '';
                _fromDate = null;
                _toDate = null;
              });
            },
          ),

          // Quick Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x660F172A),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GlassButton(
                    text: 'Scan Invoice',
                    height: 36,
                    icon: Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScanScreen()));
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    text: 'Multi-Page Scan',
                    height: 36,
                    icon: Icons.auto_stories_rounded,
                    color: const Color(0xFF6366F1),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiPageScanScreen()));
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    text: 'Fast Import',
                    height: 36,
                    icon: Icons.flash_on_rounded,
                    color: AppColors.success,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WithoutInvoiceScreen()));
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight, size: 20),
                    tooltip: 'Print Invoices Register (PDF)',
                    onPressed: () {
                      final list = invoicesAsync.asData?.value;
                      if (list != null && list.isNotEmpty) {
                        PdfExportService.printInvoicesReport(list);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No invoices available to export.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Invoice List
          Expanded(
            child: invoicesAsync.when(
              loading: () => const LoadingSkeletonList(count: 5),
              error: (err, _) => Center(
                child: EmptyStateWidget(
                  title: 'Unable to load invoices',
                  message: err.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(invoicesListProvider),
                ),
              ),
              data: (invoices) {
                if (invoices.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No purchase invoices found',
                    message: 'Record your inward supplier invoices or scan with OCR.',
                    actionLabel: '+ Add First Invoice',
                    onAction: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen()));
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: invoices.length,
                  itemBuilder: (context, i) {
                    final inv = invoices[i];
                    return _buildInvoiceCard(context, inv);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, InvoiceModel inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ViewInvoiceScreen(invoiceId: inv.id)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inv.invoiceNo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    if (inv.purchaseId.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${inv.purchaseId})',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
                StatusBadge(status: inv.paymentStatus),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    inv.vendor.isNotEmpty ? inv.vendor : 'Vendor Unspecified',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  QuantityFormatter.formatCurrency(inv.finalTotal > 0 ? inv.finalTotal : inv.grandTotal),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      AppDateFormatter.format(inv.date),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${inv.noOfItems} ${inv.noOfItems == 1 ? 'item' : 'items'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        try {
                          final details = await ref.read(invoicesRepositoryProvider).fetchInvoiceDetails(inv.id);
                          PdfExportService.printInvoice(details);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to load invoice details: $e')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.print_rounded, size: 16, color: AppColors.primaryLight),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        try {
                          final details = await ref.read(invoicesRepositoryProvider).fetchInvoiceDetails(inv.id);
                          PdfExportService.printInvoice(details, share: true);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to load invoice details: $e')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.share_rounded, size: 16, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    side: const BorderSide(color: AppColors.primaryLight, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewInvoiceScreen(invoiceId: inv.id)));
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      final details = await ref.read(invoicesRepositoryProvider).fetchInvoiceDetails(inv.id);
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddInvoiceScreen(existingInvoice: details)));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load invoice: $e')));
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _deleteInvoice(inv),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
