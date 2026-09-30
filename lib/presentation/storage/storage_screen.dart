import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/batch_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../../shared/widgets/uom_dropdown.dart';
import '../providers/app_providers.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteBatch(BatchModel b) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Batch ${b.batchNo}?',
      message: 'Are you sure you want to delete this batch record? Deleting is only allowed if no dispatches have been made against this batch.',
      confirmText: 'Yes, Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(batchesRepositoryProvider).safeDeleteBatch(b.id);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(inwardHistoryProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch deleted successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete batch: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewBatchDetails(BatchModel b) {
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.layers_rounded, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Batch ${b.batchNo} Details',
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
                _detailRow('Batch No', b.batchNo),
                _detailRow('Material Code', b.materialCode),
                _detailRow('Description', b.description.isNotEmpty ? b.description : b.materialCode),
                _detailRow('Department', b.department),
                _detailRow('UOM', b.uom),
                _detailRow('Received Qty', QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom)),
                _detailRow('Available Qty', QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom)),
                _detailRow('Status', b.isDepleted ? 'Depleted' : 'In Stock'),
                if (b.receivedDate != null)
                  _detailRow('Received Date', AppDateFormatter.format(b.receivedDate)),
                if (b.createdAt != null)
                  _detailRow('Created At', AppDateFormatter.format(b.createdAt)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Batch'),
              onPressed: () {
                Navigator.pop(context);
                _editBatch(b);
              },
            ),
          ],
        );
      },
    );
  }

  void _editBatch(BatchModel b) {
    final batchNoCtrl = TextEditingController(text: b.batchNo);
    final descCtrl = TextEditingController(text: b.description);
    final deptCtrl = TextEditingController(text: b.department);
    final recvCtrl = TextEditingController(text: b.receivedQuantity.toString());
    final availCtrl = TextEditingController(text: b.availableQuantity.toString());
    String selectedUom = b.uom;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit Batch ${b.batchNo}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: batchNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Batch Number *',
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Department / Storage Location',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      UomDropdown(
                        value: selectedUom,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedUom = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: recvCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Received Quantity ($selectedUom)',
                          prefixIcon: const Icon(Icons.input_rounded, size: 18),
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val < 0) return 'Enter valid quantity';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: availCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Available Stock ($selectedUom)',
                          prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val < 0) return 'Enter valid stock';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);

                    try {
                      await ref.read(batchesRepositoryProvider).updateBatchStock(
                        batchId: b.id,
                        batchNo: batchNoCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                        uom: selectedUom,
                        newReceived: double.tryParse(recvCtrl.text.trim()) ?? b.receivedQuantity,
                        newAvailable: double.tryParse(availCtrl.text.trim()) ?? b.availableQuantity,
                      );
                      ref.invalidate(activeBatchesProvider);
                      ref.invalidate(inwardHistoryProvider);
                      ref.invalidate(materialsListProvider);
                      ref.invalidate(dashboardSummaryProvider);

                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Batch updated successfully!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to update batch: $e'),
                            backgroundColor: AppColors.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = BatchesFilter(
      search: _search.isEmpty ? null : _search,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final activeAsync = ref.watch(activeBatchesProvider(filter));
    final historyAsync = ref.watch(inwardHistoryProvider(filter));
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return Scaffold(
      body: Column(
        children: [
          // Global Unified Search & Filter Header
          GlobalSearchFilterBar(
            hintText: 'Search batch no, material code, or item...',
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

          // Tab Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xB30F172A),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Active Batches (In Stock)'),
                Tab(text: 'Inward Storage History'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Active Batches
                activeAsync.when(
                  loading: () => const LoadingSkeletonList(count: 5),
                  error: (err, _) => Center(child: EmptyStateWidget(title: 'Error loading batches', message: err.toString())),
                  data: (batches) {
                    if (batches.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.layers_outlined,
                        title: 'No active batches available',
                        message: 'All received batches are either fully dispatched or depleted.',
                      );
                    }
                    return isTablet ? _buildTabletTable(batches) : _buildMobileBatchList(batches);
                  },
                ),

                // 2. Inward History
                historyAsync.when(
                  loading: () => const LoadingSkeletonList(count: 5),
                  error: (err, _) => Center(child: EmptyStateWidget(title: 'Error loading history', message: err.toString())),
                  data: (batches) {
                    if (batches.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.history_rounded,
                        title: 'No inward storage history',
                        message: 'Received batches will be logged here.',
                      );
                    }
                    return isTablet ? _buildTabletTable(batches) : _buildMobileBatchList(batches);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBatchList(List<BatchModel> batches) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: batches.length,
      itemBuilder: (context, i) {
        final b = batches[i];
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.batchNo,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryLight),
                      ),
                    ),
                    Text(
                      b.department,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.description.isNotEmpty ? b.description : b.materialCode,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (b.materialCode.isNotEmpty && b.description != b.materialCode) ...[
                  const SizedBox(height: 2),
                  Text(
                    b.materialCode,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Received Qty', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Available Stock', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: b.isDepleted ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (b.receivedDate != null) ...[
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date Received: ${AppDateFormatter.format(b.receivedDate)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      NeonPill(
                        label: b.isDepleted ? 'DEPLETED' : 'IN STOCK',
                        color: b.isDepleted ? AppColors.danger : AppColors.success,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Row actions: View, Edit, Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _viewBatchDetails(b),
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
                      onPressed: () => _editBatch(b),
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
                      onPressed: () => _deleteBatch(b),
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

  Widget _buildTabletTable(List<BatchModel> batches) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0x33020617)),
          columns: const [
            DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('UOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: batches.map((b) {
            return DataRow(
              cells: [
                DataCell(Text(b.batchNo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 12))),
                DataCell(Text(b.materialCode, style: const TextStyle(fontSize: 12))),
                DataCell(Text(b.description, style: const TextStyle(fontSize: 12))),
                DataCell(Text(QuantityFormatter.format3Decimals(b.receivedQuantity), style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  QuantityFormatter.format3Decimals(b.availableQuantity),
                  style: TextStyle(fontWeight: FontWeight.bold, color: b.isDepleted ? AppColors.danger : AppColors.success, fontSize: 12),
                )),
                DataCell(Text(b.uom, style: const TextStyle(fontSize: 12))),
                DataCell(Text(b.department, style: const TextStyle(fontSize: 12))),
                DataCell(Text(AppDateFormatter.format(b.receivedDate), style: const TextStyle(fontSize: 12))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryLight),
                        tooltip: 'View Details',
                        onPressed: () => _viewBatchDetails(b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondary),
                        tooltip: 'Edit Batch',
                        onPressed: () => _editBatch(b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                        tooltip: 'Delete Batch',
                        onPressed: () => _deleteBatch(b),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
