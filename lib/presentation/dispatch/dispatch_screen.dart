import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/dispatch_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../providers/app_providers.dart';
import 'add_dispatch_screen.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _deleteDispatch(DispatchModel d) async {
    final isChoc = ref.read(isChocolateUserProvider);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: isChoc ? 'Reverse & Delete Consignment #${d.id}?' : 'Reverse & Delete Dispatch #${d.id}?',
      message: isChoc
          ? 'This will atomically restore the exact consigned quantities back to their respective original Rack batches (${d.allocations.map((a) => "${a.batchNo}: ${QuantityFormatter.formatClean(a.quantity)} ${d.units}").join(", ")}). Are you sure?'
          : 'This will atomically restore the exact dispatched quantities back to their respective original Storage batches (${d.allocations.map((a) => "${a.batchNo}: ${QuantityFormatter.formatClean(a.quantity)} ${d.units}").join(", ")}). Are you sure?',
      confirmText: isChoc ? 'Yes, Restore Rack Batches & Delete' : 'Yes, Restore Storage Batches & Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(dispatchesRepositoryProvider).deleteDispatch(d.id);
      ref.invalidate(dispatchesListProvider);
      ref.invalidate(batchesListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(inwardHistoryProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChoc
                ? 'Consignment #${d.id} reversed and stock restored to Rack batches!'
                : 'Dispatch #${d.id} reversed and stock restored to Storage batches!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete dispatch: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Dedicated Read-Only View Dispatch Screen/Dialog
  void _viewDispatchDetails(DispatchModel d) {
    final isChoc = ref.read(isChocolateUserProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isChoc ? 'Consignment Record' : 'Dispatch Record',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    Text(
                      isChoc ? 'Rack Consignment Details (Read-Only)' : 'Storage Stock-Out Details (Read-Only)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dispatch Header Information
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        _detailRow(isChoc ? 'Consignment Date' : 'Dispatch Date', AppDateFormatter.format(d.date)),
                        _detailRow(isChoc ? 'Consignment Time' : 'Dispatch Time', AppDateFormatter.formatTime(d.effectiveDateTime)),
                        if (!isChoc)
                          _detailRow('Product Code', d.materialCode, isMono: true, color: AppColors.secondary),
                        _detailRow('Description', d.product.isNotEmpty ? d.product : d.materialCode),
                        if (d.category.isNotEmpty) _detailRow('Category', d.category),
                        if (d.grade.isNotEmpty && d.grade != 'STANDARD') _detailRow('Grade', d.grade),
                        if (d.ocrLedgerId != null)
                          _detailRow('OCR Origin', 'Scan #${d.ocrLedgerId} (Verified)', color: const Color(0xFFF59E0B)),
                        _detailRow(isChoc ? 'Consignment Quantity' : 'Dispatch Quantity', '${QuantityFormatter.formatClean(d.quantity)} ${d.units}'),
                        if (d.returnQuantity > 0)
                          _detailRow('Return Quantity', '${QuantityFormatter.formatClean(d.returnQuantity)} ${d.units}', color: AppColors.primaryLight),
                        _detailRow(isChoc ? 'Net Consignment' : 'Net Dispatch', '${QuantityFormatter.formatClean(d.netQuantity)} ${d.units}', isBold: true, color: AppColors.secondary),
                        _detailRow('UOM', d.units),
                        if (!isChoc)
                          _detailRow('Department', d.department.isNotEmpty ? d.department : 'Dispatch'),
                        if (d.location.isNotEmpty) _detailRow('Destination / Location', d.location),
                        if (d.remarks.isNotEmpty) _detailRow('Remarks', d.remarks),
                        if (d.createdAt != null) _detailRow('Created At', AppDateFormatter.formatWithTime(d.createdAt!)),
                        if (d.createdBy != null && d.createdBy!.isNotEmpty) _detailRow('Created By', d.createdBy!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Batch Allocation Breakdown
                  Text(
                    isChoc ? 'Rack Batch Allocations (${d.allocations.length}):' : 'Storage Batch Allocations (${d.allocations.length}):',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  if (d.allocations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x33020617),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Center(
                        child: Text('No individual batch allocations recorded.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(3),
                          2: FlexColumnWidth(4),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0x33020617),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                            ),
                            children: [
                              _tableHeader('Batch No'),
                              _tableHeader('Batch Date'),
                              _tableHeader('Allocated Qty', align: TextAlign.end),
                            ],
                          ),
                          ...d.allocations.map((a) {
                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: AppColors.glassBorder)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(
                                    a.batchNo,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(
                                    a.batchDate != null ? AppDateFormatter.format(a.batchDate!) : '-',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(
                                    '${QuantityFormatter.formatClean(a.quantity)} ${a.uom.isNotEmpty ? a.uom : d.units}',
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(isChoc ? 'Edit Consignment' : 'Edit Dispatch'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddDispatchScreen(existingDispatch: d)));
              },
            ),
          ],
        );
      },
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isMono = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: isMono
                  ? GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)
                  : TextStyle(
                      fontSize: 12,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: color ?? AppColors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = DispatchesFilter(
      search: _search.isNotEmpty ? _search : null,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final dispatchesAsync = ref.watch(dispatchesListProvider(filter));
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);
    final isChoc = ref.watch(isChocolateUserProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isChoc ? const Color(0xFFD97706) : AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(isChoc ? 'Record Consignment' : 'Record Dispatch'),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen()));
        },
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            GlobalSearchFilterBar(
              hintText: isChoc
                  ? 'Search by Description, Category, Location...'
                  : 'Search by Material Code, Description, Category, Location...',
              initialSearch: _search,
              initialFromDate: _fromDate,
              initialToDate: _toDate,
              trailingAction: dispatchesAsync.maybeWhen(
                data: (list) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight, size: 20),
                      tooltip: isChoc ? 'Print Consignment Register (PDF)' : 'Print Dispatches Register (PDF)',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          String subtitle = isChoc ? 'Chocolate Consignment Register' : 'Dispatches Register';
                          if (_fromDate != null || _toDate != null) {
                            subtitle += ' | Range: ${_fromDate != null ? AppDateFormatter.format(_fromDate) : "Start"} - ${_toDate != null ? AppDateFormatter.format(_toDate) : "End"}';
                          }
                          if (_search.isNotEmpty) {
                            subtitle += ' | Filter: "$_search"';
                          }
                          PdfExportService.printDispatchesReport(list, subtitle: subtitle);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: AppColors.accent, size: 20),
                      tooltip: isChoc ? 'Share Consignment Register' : 'Share Dispatches Register',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          String subtitle = isChoc ? 'Chocolate Consignment Register' : 'Dispatches Register';
                          if (_fromDate != null || _toDate != null) {
                            subtitle += ' | Range: ${_fromDate != null ? AppDateFormatter.format(_fromDate) : "Start"} - ${_toDate != null ? AppDateFormatter.format(_toDate) : "End"}';
                          }
                          if (_search.isNotEmpty) {
                            subtitle += ' | Filter: "$_search"';
                          }
                          PdfExportService.printDispatchesReport(list, subtitle: subtitle, share: true);
                        }
                      },
                    ),
                  ],
                ),
                orElse: () => null,
              ),
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
            Expanded(
              child: dispatchesAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    title: isChoc ? 'Error loading consignments' : 'Error loading dispatches',
                    message: err.toString(),
                  ),
                ),
                data: (dispatches) {
                  if (dispatches.isEmpty) {
                    return EmptyStateWidget(
                      icon: isChoc ? Icons.inventory_2_outlined : Icons.local_shipping_outlined,
                      title: isChoc ? 'No consignments recorded' : 'No dispatches recorded',
                      message: isChoc
                          ? 'Record outward chocolate stock deductions directly from available Chocolate Rack batches in FIFO sequence.'
                          : 'Record outward stock deductions directly from available Storage batches in FIFO sequence.',
                      actionLabel: isChoc ? '+ Record First Consignment' : '+ Record First Dispatch',
                      onAction: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen()));
                      },
                    );
                  }

                  return isTablet ? _buildDesktopTable(dispatches) : _buildMobileList(dispatches);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<DispatchModel> dispatches) {
    final isChoc = ref.watch(isChocolateUserProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0x33020617)),
              horizontalMargin: 16,
              columnSpacing: 18,
              columns: [
                const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Stock Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Return Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Net Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (!isChoc)
                  const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: dispatches.map((d) {
                return DataRow(
                  cells: [
                    DataCell(Text(AppDateFormatter.format(d.date), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(AppDateFormatter.formatTime(d.effectiveDateTime), style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: d.allocations.isEmpty
                            ? const Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted))
                            : Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: d.allocations.map((a) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${a.batchNo}: ${QuantityFormatter.formatClean(a.quantity)}',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d.product.isNotEmpty ? d.product : d.materialCode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isChoc && d.materialCode.isNotEmpty && d.materialCode != d.product)
                            Text(
                              d.materialCode,
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.primaryLight),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        QuantityFormatter.formatClean(d.quantity),
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    DataCell(
                      Text(
                        d.returnQuantity > 0 ? QuantityFormatter.formatClean(d.returnQuantity) : '-',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: d.returnQuantity > 0 ? FontWeight.bold : FontWeight.normal,
                          color: d.returnQuantity > 0 ? AppColors.primaryLight : AppColors.textMuted,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        QuantityFormatter.formatClean(d.netQuantity),
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ),
                    DataCell(Text(d.units, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(d.location.isNotEmpty ? d.location : '-', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    if (!isChoc)
                      DataCell(Text(d.department.isNotEmpty ? d.department : 'Dispatch', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryLight),
                            tooltip: 'View Dispatch',
                            onPressed: () => _viewDispatchDetails(d),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondary),
                            tooltip: 'Edit Dispatch',
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AddDispatchScreen(existingDispatch: d)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                            tooltip: 'Reverse & Restore Stock',
                            onPressed: () => _deleteDispatch(d),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<DispatchModel> dispatches) {
    final isChoc = ref.watch(isChocolateUserProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: dispatches.length,
      itemBuilder: (context, i) {
        final d = dispatches[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isChoc ? 'CONSIGNMENT' : 'DISPATCH',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${AppDateFormatter.format(d.date)} • ${AppDateFormatter.formatTime(d.effectiveDateTime)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        if (d.ocrLedgerId != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.document_scanner_rounded, size: 10, color: Color(0xFFF59E0B)),
                                SizedBox(width: 3),
                                Text('OCR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'Reverse & Restore Stock',
                      onPressed: () => _deleteDispatch(d),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (!isChoc) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          d.materialCode,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        d.displayName,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isChoc)
                      Expanded(
                        child: Text(
                          'Dept: ${d.department.isNotEmpty ? d.department : "Dispatch"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Net: ${QuantityFormatter.formatClean(d.netQuantity)} ${d.units}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.secondary),
                        ),
                        if (d.returnQuantity > 0)
                          Text(
                            '(Out: ${QuantityFormatter.formatClean(d.quantity)} | Ret: ${QuantityFormatter.formatClean(d.returnQuantity)})',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.primaryLight),
                          ),
                      ],
                    ),
                  ],
                ),
                if (d.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Destination: ${d.location}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (d.allocations.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text(
                    isChoc ? 'Rack Batches Consumed:' : 'Storage Batches Consumed:',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: d.allocations.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Batch ${a.batchNo}: ${QuantityFormatter.formatClean(a.quantity)} ${d.units}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textPrimary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                      onPressed: () => _viewDispatchDetails(d),
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
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddDispatchScreen(existingDispatch: d)));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
