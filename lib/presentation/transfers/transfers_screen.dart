import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/services/pdf_export_service.dart';
import '../../data/models/transfer_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../providers/app_providers.dart';
import 'add_transfer_screen.dart';

class TransfersScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final bool readOnlyActions;
  final String? departmentFilter;
  const TransfersScreen({
    super.key,
    this.isEmbedded = false,
    this.readOnlyActions = false,
    this.departmentFilter,
  });

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _deleteTransfer(TransferModel t) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Transfer #${t.id}?',
      message: 'This will reverse the net stock change of ${t.netChange > 0 ? "+${t.netChange}" : t.netChange} ${t.units} on material ${t.code}. Are you sure?',
      confirmText: 'Yes, Reverse & Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(transfersRepositoryProvider).deleteTransfer(t.id);
      ref.invalidate(transfersListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer deleted and lot stock reverted!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete transfer: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewTransferDetails(TransferModel t) {
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
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transfer #${t.id} Details',
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
                _detailRow('Material Code', t.code),
                _detailRow('Description', t.description.isNotEmpty ? t.description : t.code),
                if (t.lotNo.isNotEmpty) _detailRow('Lot No', t.lotNo),
                _detailRow('Department', t.department.isNotEmpty ? t.department : 'General'),
                _detailRow('Handled Person', t.person.isNotEmpty ? t.person : '—'),
                _detailRow('Date & Time', AppDateFormatter.formatWithTime(t.createdAt ?? t.date)),
                if (t.allocations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Lot Allocations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 4),
                  ...t.allocations.map((a) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• ${a.lotNo}: ${QuantityFormatter.formatClean(a.quantity)} ${t.units}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textSecondary)),
                  )),
                ],
                const Divider(height: 20),
                _detailRow(
                  (ref.read(isTeaUserProvider) || widget.departmentFilter == 'TEA') ? 'Received from Admin' : 'Outward Issued',
                  QuantityFormatter.formatDualUnit(t.outward, t.units),
                ),
                _detailRow('Returned In', QuantityFormatter.formatDualUnit(t.returnUnits, t.units)),
                _detailRow('Current Stock', QuantityFormatter.formatDualUnit(t.availability, t.units)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (!widget.readOnlyActions && !ref.watch(isTeaUserProvider))
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existingTransfer: t)));
                },
              ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChocolate = ref.watch(isChocolateUserProvider);
    if (isChocolate) {
      return Scaffold(
        appBar: widget.isEmbedded ? null : AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block_rounded, size: 48, color: AppColors.danger),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  'Transfer module is not accessible for Chocolate department users.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTea = ref.watch(isTeaUserProvider) || widget.departmentFilter == 'TEA';
    final effectiveDept = isTea ? 'TEA' : widget.departmentFilter;
    final filter = TransfersFilter(
      search: _search.isNotEmpty ? _search : null,
      fromDate: _fromDate,
      toDate: _toDate,
      department: effectiveDept,
    );
    final transfersAsync = ref.watch(transfersListProvider(filter));

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Department Transfers & Returns'),
            ),
      floatingActionButton: (widget.readOnlyActions || ref.watch(isTeaUserProvider))
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('New Transfer'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransferScreen()));
              },
            ),
      body: AmbientBackground(
        child: Column(
          children: [
            GlobalSearchFilterBar(
              hintText: 'Search by Code, Description or Category',
              initialSearch: _search,
              initialFromDate: _fromDate,
              initialToDate: _toDate,
              trailingAction: transfersAsync.maybeWhen(
                data: (list) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight, size: 20),
                      tooltip: 'Print Transfers Register (PDF)',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          PdfExportService.printTransfersReport(list);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: AppColors.accent, size: 20),
                      tooltip: 'Share Transfers Register',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          PdfExportService.printTransfersReport(list, share: true);
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
              child: transfersAsync.when(
                loading: () => const LoadingSkeletonList(count: 5),
                error: (err, _) => Center(child: EmptyStateWidget(title: 'Error loading transfers', message: err.toString())),
                data: (transfers) {
                  if (transfers.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.swap_horiz_rounded,
                      title: 'No transfers recorded',
                      message: isTea
                          ? 'No transfers have been dispatched to the Tea department yet.'
                          : 'Record department outward transfers or kitchen/production returns.',
                      actionLabel: (widget.readOnlyActions || isTea) ? null : '+ Record Transfer',
                      onAction: (widget.readOnlyActions || isTea)
                          ? null
                          : () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransferScreen()));
                            },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: transfers.length,
                    itemBuilder: (context, i) {
                      final t = transfers[i];
                      return _buildTransferCard(t);
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

  Widget _buildTransferCard(TransferModel t) {
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
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.department.isNotEmpty ? t.department : 'General',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.accent),
                      ),
                    ),
                    if (t.outward == 0 && t.returnUnits > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'RETURN TO STORE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ),
                    ] else if (t.outward > 0 && t.returnUnits >= t.outward) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'FULLY RETURNED',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ] else if (t.outward > 0 && t.returnUnits > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'PARTIALLY RETURNED',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      AppDateFormatter.formatWithTime(t.createdAt ?? t.date),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                if (!widget.readOnlyActions && !ref.watch(isTeaUserProvider))
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    tooltip: 'Revert & Delete Transfer',
                    onPressed: () => _deleteTransfer(t),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.description.isNotEmpty ? t.description : t.code,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Code: ${t.code}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (t.lotNo.isNotEmpty)
                  Text('• Lot: ${t.lotNo}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                if (t.person.isNotEmpty)
                  Text('• Person: ${t.person}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ref.watch(isTeaUserProvider) || widget.departmentFilter == 'TEA') ? 'Received from Admin' : 'Outward Issued',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                    Text(
                      QuantityFormatter.formatDualUnit(t.outward, t.units),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Returned In', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      QuantityFormatter.formatDualUnit(t.returnUnits, t.units),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Current Stock', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      QuantityFormatter.formatDualUnit(t.availability, t.units),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
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
                  onPressed: () => _viewTransferDetails(t),
                ),
                if (!widget.readOnlyActions && !ref.watch(isTeaUserProvider)) ...[
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existingTransfer: t)));
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
                    onPressed: () => _deleteTransfer(t),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
