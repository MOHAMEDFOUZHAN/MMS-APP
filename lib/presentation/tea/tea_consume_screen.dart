import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/tea_consumption_model.dart';
import '../../data/repositories/tea_consumption_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../providers/tea_consumption_providers.dart';

class TeaConsumeScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const TeaConsumeScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<TeaConsumeScreen> createState() => _TeaConsumeScreenState();
}

class _TeaConsumeScreenState extends ConsumerState<TeaConsumeScreen> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  void _openAddEntryDialog(List<TeaTransferredMaterial> transferredMaterials) {
    final availableMaterials = transferredMaterials.where((m) => m.currentBalance > 0.0001).toList();
    if (availableMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No materials with active stock balance currently held by Tea.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddConsumptionDialog(
        transferredMaterials: availableMaterials,
        onSaved: () {
          ref.invalidate(teaConsumptionListProvider);
          ref.invalidate(teaDepartmentSummaryProvider);
          ref.invalidate(teaTransferredMaterialsProvider);
          ref.invalidate(teaMaterialReceivedListProvider);
        },
      ),
    );
  }

  void _openEditNightBalanceDialog(TeaConsumptionModel entry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditNightBalanceDialog(
        entry: entry,
        onSaved: () {
          ref.invalidate(teaConsumptionListProvider);
          ref.invalidate(teaDepartmentSummaryProvider);
          ref.invalidate(teaTransferredMaterialsProvider);
          ref.invalidate(teaMaterialReceivedListProvider);
        },
      ),
    );
  }

  Future<void> _deleteEntry(TeaConsumptionModel entry) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Consumption Entry?',
      message: 'Remove consumption record for ${entry.description} (${entry.consumedQty} ${entry.unit})?',
      confirmText: 'Yes, Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(teaConsumptionRepositoryProvider).deleteEntry(entry.id);
      ref.invalidate(teaConsumptionListProvider);
      ref.invalidate(teaDepartmentSummaryProvider);
      ref.invalidate(teaTransferredMaterialsProvider);
      ref.invalidate(teaMaterialReceivedListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consumption record removed successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete entry: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = TeaConsumptionFilter(
      search: _search.isNotEmpty ? _search : null,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final entriesAsync = ref.watch(teaConsumptionListProvider(filter));
    // Kept alive for provider subscription
    ref.watch(teaDepartmentSummaryProvider);
    final materialsAsync = ref.watch(teaTransferredMaterialsProvider);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Tea Material Consumption & Balance'),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Record Material Taken'),
        onPressed: () {
          materialsAsync.when(
            data: (materials) => _openAddEntryDialog(materials),
            loading: () {},
            error: (e, _) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading materials: $e')),
              );
            },
          );
        },
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Search & Filter Bar
            GlobalSearchFilterBar(
              hintText: 'Search by Code, Description, or Operator',
              initialSearch: _search,
              initialFromDate: _fromDate,
              initialToDate: _toDate,
              onSearchChanged: (val) => setState(() => _search = val),
              onApply: (search, from, to) => setState(() {
                _search = search;
                _fromDate = from;
                _toDate = to;
              }),
              onClear: () => setState(() {
                _search = '';
                _fromDate = null;
                _toDate = null;
              }),
            ),

            // Ledger List
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading consumption ledger: $err',
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No Consumption Records',
                      message: 'Transferred materials taken for processing will appear here with daily night reconciliation.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 88),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return _buildLedgerCard(item);
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

  // ignore: unused_element
  Widget _buildSummaryCards(TeaDepartmentSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 650;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                label: 'Transferred In',
                value: '${QuantityFormatter.formatClean(summary.totalTransferredIn)} kg',
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF06B6D4),
                width: isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
              ),
              _summaryChip(
                label: 'Taken for Work',
                value: '${QuantityFormatter.formatClean(summary.totalTaken)} kg',
                icon: Icons.outbox_rounded,
                color: const Color(0xFFF59E0B),
                width: isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
              ),
              _summaryChip(
                label: 'Balance Returned',
                value: '${QuantityFormatter.formatClean(summary.totalBalanceReturned)} kg',
                icon: Icons.keyboard_return_rounded,
                color: const Color(0xFF8B5CF6),
                width: isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
              ),
              _summaryChip(
                label: 'Net Consumed',
                value: '${QuantityFormatter.formatClean(summary.totalNetConsumed)} kg',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                width: isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerCard(TeaConsumptionModel item) {
    final isClosed = item.status == 'CLOSED' || item.balanceQty > 0;
    final timeStr = DateFormat('hh:mm a').format(item.createdAt.toLocal());
    final dateStr = AppDateFormatter.format(item.date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClosed
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Description & Code + Date/Time & Operator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.eco_rounded, size: 16, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.description,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              'CODE: ${item.materialCode}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                timeStr,
                                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          if (item.operatorName.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 11, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 130),
                                  child: Text(
                                    item.operatorName,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 14, color: Color(0xFF1E293B)),

            // Metric Quantities Grid: Taken Qty | Returned Qty | Consumed Qty
            Row(
              children: [
                Expanded(
                  child: _quantityBox(
                    label: 'TAKEN QTY',
                    value: QuantityFormatter.formatClean(item.takenQty),
                    unit: item.unit,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quantityBox(
                    label: 'RETURNED QTY',
                    value: QuantityFormatter.formatClean(item.balanceQty),
                    unit: item.unit,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quantityBox(
                    label: 'CONSUMED QTY',
                    value: QuantityFormatter.formatClean(item.consumedQty),
                    unit: item.unit,
                    color: const Color(0xFF10B981),
                    isHighlighted: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Footer Status & Actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isClosed
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isClosed ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 11,
                        color: isClosed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isClosed ? 'Night Closed / Reconciled' : 'Pending Night Balance',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isClosed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B), width: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 14),
                      label: Text(
                        isClosed ? 'Edit Balance' : 'Enter Night Balance',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openEditNightBalanceDialog(item),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 17),
                      tooltip: 'Delete Record',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _deleteEntry(item),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityBox({
    required String label,
    required String value,
    required String unit,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.12)
            : const Color(0xFF030712).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.5 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ADD CONSUMPTION DIALOG ──────────────────────────────────────────────────
class _AddConsumptionDialog extends ConsumerStatefulWidget {
  final List<TeaTransferredMaterial> transferredMaterials;
  final VoidCallback onSaved;

  const _AddConsumptionDialog({
    required this.transferredMaterials,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddConsumptionDialog> createState() => _AddConsumptionDialogState();
}

class _AddConsumptionDialogState extends ConsumerState<_AddConsumptionDialog> {
  final _formKey = GlobalKey<FormState>();
  TeaTransferredMaterial? _selectedMaterial;
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _unitController = TextEditingController(text: 'kg');
  final _consumedQtyController = TextEditingController();
  final _physicalBalanceController = TextEditingController();
  final _operatorController = TextEditingController(text: 'Tea Operator');
  final _notesController = TextEditingController();

  double _expectedRemaining = 0.0;
  double _discrepancyVariance = 0.0;
  bool _hasDiscrepancy = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.transferredMaterials.isNotEmpty) {
      _selectMaterial(widget.transferredMaterials.first);
    }
  }

  void _selectMaterial(TeaTransferredMaterial mat) {
    setState(() {
      _selectedMaterial = mat;
      _codeController.text = mat.code;
      _descController.text = mat.description;
      _unitController.text = mat.units;
      _recalculate();
    });
  }

  void _recalculate() {
    final openingBalance = _selectedMaterial?.currentBalance ?? 0.0;
    final consumed = double.tryParse(_consumedQtyController.text.trim()) ?? 0.0;
    final physical = double.tryParse(_physicalBalanceController.text.trim());

    final expected = (openingBalance - consumed).clamp(0.0, double.infinity);

    setState(() {
      _expectedRemaining = expected;
      if (physical != null) {
        _discrepancyVariance = physical - expected;
        _hasDiscrepancy = _discrepancyVariance.abs() > 0.001;
      } else {
        _discrepancyVariance = 0.0;
        _hasDiscrepancy = false;
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _consumedQtyController.dispose();
    _physicalBalanceController.dispose();
    _operatorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null) return;
    if (_selectedMaterial!.currentBalance <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected material has zero available balance.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final openingBalance = _selectedMaterial!.currentBalance;
    final consumed = double.tryParse(_consumedQtyController.text.trim()) ?? 0.0;
    final physical = double.tryParse(_physicalBalanceController.text.trim()) ?? 0.0;
    final expected = (openingBalance - consumed).clamp(0.0, double.infinity);
    final variance = physical - expected;
    final hasDisc = variance.abs() > 0.001;

    setState(() => _isSaving = true);
    try {
      String auditNotes = _notesController.text.trim();
      if (hasDisc) {
        final discTag =
            '[DISCREPANCY: Expected ${QuantityFormatter.formatClean(expected)} ${_selectedMaterial!.units}, Measured ${QuantityFormatter.formatClean(physical)} ${_selectedMaterial!.units}, Variance ${variance > 0 ? "+" : ""}${QuantityFormatter.formatClean(variance)} ${_selectedMaterial!.units}]';
        auditNotes = auditNotes.isEmpty ? discTag : '$auditNotes | $discTag';
      }

      final newEntry = TeaConsumptionModel(
        id: 0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: _selectedMaterial!.code,
        description: _selectedMaterial!.description,
        category: 'TEA',
        department: 'TEA',
        unit: _selectedMaterial!.units,
        takenQty: openingBalance,
        balanceQty: physical,
        consumedQty: consumed,
        operatorName: _operatorController.text.trim(),
        status: 'CLOSED',
        notes: auditNotes,
      );

      await ref.read(teaConsumptionRepositoryProvider).createEntry(newEntry);
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded: Consumed ${QuantityFormatter.formatClean(consumed)} ${_selectedMaterial!.units} of ${_selectedMaterial!.description}. Measured remaining: ${QuantityFormatter.formatClean(physical)} ${_selectedMaterial!.units}.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save consumption record: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final openingBalance = _selectedMaterial?.currentBalance ?? 0.0;
    final unit = _selectedMaterial?.units ?? 'kg';

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Record Material Consumption',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Choose Available Material (Transferred to Tea Only with Active Balance)
                const Text('SELECT AVAILABLE MATERIAL *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TeaTransferredMaterial>(
                      value: _selectedMaterial,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F172A),
                      items: widget.transferredMaterials
                          .where((m) => m.currentBalance > 0.0001)
                          .map((m) {
                        return DropdownMenuItem<TeaTransferredMaterial>(
                          value: m,
                          child: Text(
                            '${m.description.toUpperCase()} (${m.code}) — Available: ${QuantityFormatter.formatClean(m.currentBalance)} ${m.units.toUpperCase()}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _selectMaterial(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Opening Available Balance Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Opening Available Balance:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '${QuantityFormatter.formatClean(openingBalance)} $unit',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Auto-filled Code & Unit Display
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MATERIAL CODE (AUTO)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codeController,
                            readOnly: true,
                            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF020617),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('UNIT (AUTO)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _unitController,
                            readOnly: true,
                            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF020617),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Quantity Consumed Input
                Text(
                  'QUANTITY CONSUMED *',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _consumedQtyController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Enter quantity consumed',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    suffixText: unit,
                    suffixStyle: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2)),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter quantity consumed';
                    final num = double.tryParse(val.trim());
                    if (num == null || num <= 0) return 'Must be greater than 0';
                    if (num > (openingBalance + 0.0001)) {
                      return 'Cannot exceed available balance (${QuantityFormatter.formatClean(openingBalance)} $unit)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 5. Live Expected Remaining Balance Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expected Remaining Balance:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '(Opening $openingBalance − Consumed)',
                            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      Text(
                        '${QuantityFormatter.formatClean(_expectedRemaining)} $unit',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Physically Measured Remaining Balance Input
                Text(
                  'PHYSICALLY MEASURED REMAINING BALANCE *',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _physicalBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Enter physically measured balance',
                    suffixText: unit,
                    suffixStyle: const TextStyle(color: Color(0xFF8B5CF6)),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter physical remaining balance';
                    final b = double.tryParse(val.trim());
                    if (b == null || b < 0) return 'Cannot be negative';
                    return null;
                  },
                ),

                // 7. Discrepancy Warning Alert
                if (_hasDiscrepancy) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C2D12).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF97316), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'DISCREPANCY WARNING',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFFF97316)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Expected remaining: ${QuantityFormatter.formatClean(_expectedRemaining)} $unit\n'
                          'Physically measured: ${_physicalBalanceController.text.trim()} $unit\n'
                          'Discrepancy Variance: ${_discrepancyVariance > 0 ? "+" : ""}${QuantityFormatter.formatClean(_discrepancyVariance)} $unit',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white, height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Notice: Physical remaining balance differs from expected. Both values will be preserved and flagged in the audit ledger.',
                          style: TextStyle(fontSize: 10, color: Color(0xFFFED7AA)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // 8. Operator Name
                const Text('OPERATOR / PERSON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _operatorController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Worker / Operator name',
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(height: 14),

                // 9. Notes / Remarks
                const Text('NOTES / REMARKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional remarks',
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ─── EDIT NIGHT BALANCE DIALOG ───────────────────────────────────────────────
class _EditNightBalanceDialog extends ConsumerStatefulWidget {
  final TeaConsumptionModel entry;
  final VoidCallback onSaved;

  const _EditNightBalanceDialog({
    required this.entry,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditNightBalanceDialog> createState() => _EditNightBalanceDialogState();
}

class _EditNightBalanceDialogState extends ConsumerState<_EditNightBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _takenController;
  late final TextEditingController _balanceController;
  late final TextEditingController _notesController;

  late double _calculatedConsumed;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _takenController = TextEditingController(text: QuantityFormatter.formatClean(widget.entry.takenQty));
    _balanceController = TextEditingController(text: QuantityFormatter.formatClean(widget.entry.balanceQty));
    _notesController = TextEditingController(text: widget.entry.notes);
    _calculatedConsumed = widget.entry.consumedQty;
  }

  void _recalculate() {
    final taken = double.tryParse(_takenController.text.trim()) ?? widget.entry.takenQty;
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    setState(() {
      _calculatedConsumed = (taken - balance).clamp(0.0, double.infinity);
    });
  }

  @override
  void dispose() {
    _takenController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final taken = double.tryParse(_takenController.text.trim()) ?? widget.entry.takenQty;
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final consumed = (taken - balance).clamp(0.0, double.infinity);

    setState(() => _isSaving = true);
    try {
      final updated = widget.entry.copyWith(
        takenQty: taken,
        balanceQty: balance,
        consumedQty: consumed,
        status: 'CLOSED', // Night balance entered and closed!
        notes: _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(teaConsumptionRepositoryProvider).updateEntry(updated);
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Night balance reconciled: Consumed $consumed ${widget.entry.unit} (Returned $balance ${widget.entry.unit})'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update night balance: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.nightlight_round, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Night Reconciliation',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                Text(
                  '${widget.entry.description} (${widget.entry.materialCode})',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Taken Qty
                Text('TAKEN FOR SHIFT (${widget.entry.unit})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _takenController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (_) => _recalculate(),
                ),
                const SizedBox(height: 14),

                // Balance Qty (Opposite to consume qty - remaining at night)
                Text(
                  'NIGHT BALANCE REMAINING / RETURNED (${widget.entry.unit}) *',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _balanceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Enter leftover balance quantity',
                    suffixText: widget.entry.unit,
                    suffixStyle: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter balance quantity';
                    final b = double.tryParse(val.trim());
                    if (b == null || b < 0) return 'Cannot be negative';
                    final t = double.tryParse(_takenController.text.trim()) ?? widget.entry.takenQty;
                    if (b > t) return 'Balance cannot exceed taken quantity ($t)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Net Consumed Result Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Calculated Consumed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('(Taken Qty − Night Balance)', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                      Text(
                        '${QuantityFormatter.formatClean(_calculatedConsumed)} ${widget.entry.unit}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('NOTES / REMARKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Returned to storage / leftover for next shift',
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save & Close Shift', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
