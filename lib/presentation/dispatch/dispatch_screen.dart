import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/services/pdf_export_service.dart';
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
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Reverse & Delete Dispatch #${d.id}?',
      message: 'This will restore the exact dispatched quantities back to their respective original FIFO batches in Storage. Are you sure?',
      confirmText: 'Yes, Restore Batches & Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(dispatchesRepositoryProvider).deleteDispatch(d.id);
      ref.invalidate(dispatchesListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispatch reversed and batch quantities restored to Storage!'),
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

  void _viewDispatchDetails(DispatchModel d) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispatch #${d.id} Details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Material Code', d.materialCode),
                _detailRow('Product Description', d.product),
                _detailRow('Department', d.department.isNotEmpty ? d.department : 'General Dispatch'),
                if (d.location.isNotEmpty) _detailRow('Location / Destination', d.location),
                _detailRow('Dispatched Quantity', QuantityFormatter.formatDualUnit(d.quantity, d.units)),
                _detailRow('Dispatch Date', AppDateFormatter.format(d.date)),
                const Divider(height: 20),
                Text(
                  'FIFO Batch Allocations (${d.allocations.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                if (d.allocations.isEmpty)
                  const Text('No individual batch allocations recorded.', style: TextStyle(fontSize: 11, color: AppColors.textMuted))
                else
                  ...d.allocations.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x33020617),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(a.batchNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
                            Text('${QuantityFormatter.formatClean(a.quantity)} ${d.units}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
              ),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
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

  Widget _detailRow(String label, String value) {
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('FIFO Dispatch'),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen()));
        },
      ),
      body: Column(
        children: [
          GlobalSearchFilterBar(
            hintText: 'Search by Code, Description or Category',
            initialSearch: _search,
            initialFromDate: _fromDate,
            initialToDate: _toDate,
            trailingAction: dispatchesAsync.maybeWhen(
              data: (list) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight, size: 20),
                    tooltip: 'Print Dispatches Register (PDF)',
                    onPressed: () {
                      if (list.isNotEmpty) {
                        PdfExportService.printDispatchesReport(list);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: AppColors.accent, size: 20),
                    tooltip: 'Share Dispatches Register',
                    onPressed: () {
                      if (list.isNotEmpty) {
                        PdfExportService.printDispatchesReport(list, share: true);
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
              loading: () => const LoadingSkeletonList(count: 5),
              error: (err, _) => Center(child: EmptyStateWidget(title: 'Error loading dispatches', message: err.toString())),
              data: (dispatches) {
                if (dispatches.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.local_shipping_outlined,
                    title: 'No dispatches recorded',
                    message: 'Record outward stock dispatches with automated FIFO batch deductions.',
                    actionLabel: '+ Record First Dispatch',
                    onAction: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDispatchScreen()));
                    },
                  );
                }

                if (isTablet) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 270,
                    ),
                    itemCount: dispatches.length,
                    itemBuilder: (context, i) => _buildDispatchCard(dispatches[i]),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: dispatches.length,
                  itemBuilder: (context, i) {
                    final d = dispatches[i];
                    return _buildDispatchCard(d);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchCard(DispatchModel d) {
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
                        'DISPATCH #${d.id}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      QuantityFormatter.formatDate(d.date),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  tooltip: 'Reverse & Restore Batches',
                  onPressed: () => _deleteDispatch(d),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              d.displayName,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dept / Dest: ${d.department.isNotEmpty ? d.department : "General Dispatch"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  QuantityFormatter.formatDualUnit(d.quantity, d.units),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.secondary),
                ),
              ],
            ),
            if (d.allocations.isNotEmpty) ...[
              const Divider(height: 16),
              const Text('FIFO Batch Allocations:', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
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
                      '${a.batchNo}: ${QuantityFormatter.formatClean(a.quantity)} ${d.units}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
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
                  onPressed: () => _deleteDispatch(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
