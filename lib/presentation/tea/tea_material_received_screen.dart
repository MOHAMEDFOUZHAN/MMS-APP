import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/tea_material_received_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/global_search_filter_bar.dart';
import '../providers/app_providers.dart';
import '../providers/tea_consumption_providers.dart';

class TeaMaterialReceivedScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const TeaMaterialReceivedScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<TeaMaterialReceivedScreen> createState() => _TeaMaterialReceivedScreenState();
}

class _TeaMaterialReceivedScreenState extends ConsumerState<TeaMaterialReceivedScreen> {
  String _search = '';
  String _selectedCategory = 'All';
  bool _onlyWithBalance = false;

  void _openReturnDialog(TeaMaterialReceivedModel item) {
    if (item.currentBalance <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot return material with zero available balance.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReturnToAdminDialog(
        item: item,
        onSuccess: () {
          ref.invalidate(teaMaterialReceivedListProvider);
          ref.invalidate(teaTransferredMaterialsProvider);
          ref.invalidate(teaDepartmentSummaryProvider);
          ref.invalidate(transfersListProvider);
          ref.invalidate(materialsListProvider);
          ref.invalidate(dashboardSummaryProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = TeaMaterialReceivedFilter(
      search: _search.isNotEmpty ? _search : null,
      category: _selectedCategory != 'All' ? _selectedCategory : null,
      onlyWithBalance: _onlyWithBalance,
    );

    final receivedAsync = ref.watch(teaMaterialReceivedListProvider(filter));

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Tea Material Received Live Stock'),
            ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Search and Category Bar
            GlobalSearchFilterBar(
              hintText: 'Search by Code or Description',
              initialSearch: _search,
              trailingAction: receivedAsync.maybeWhen(
                data: (list) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppColors.primaryLight, size: 20),
                      tooltip: 'Print Live Stock Ledger',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          PdfExportService.printTeaMaterialReceivedLedger(list);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: AppColors.accent, size: 20),
                      tooltip: 'Share Live Stock Ledger',
                      onPressed: () {
                        if (list.isNotEmpty) {
                          PdfExportService.printTeaMaterialReceivedLedger(list, share: true);
                        }
                      },
                    ),
                  ],
                ),
                orElse: () => null,
              ),
              onSearchChanged: (val) => setState(() => _search = val.trim()),
              onApply: (search, from, to) {
                setState(() => _search = search.trim());
              },
              onClear: () {
                setState(() {
                  _search = '';
                  _selectedCategory = 'All';
                  _onlyWithBalance = false;
                });
              },
            ),

            // Filter Chips (Category + Available Stock Toggle)
            _buildFilterChipsRow(receivedAsync),

            // Material Received Ledger List
            Expanded(
              child: receivedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading received stock: $err',
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.move_to_inbox_rounded,
                      title: 'No Received Materials Found',
                      message: _onlyWithBalance
                          ? 'No materials currently have an active available balance in Tea.'
                          : 'No authorized transfers have been recorded for Tea yet.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildMaterialCard(item);
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

  Widget _buildFilterChipsRow(AsyncValue<List<TeaMaterialReceivedModel>> asyncItems) {
    final categories = <String>{'All'};
    asyncItems.whenData((items) {
      for (final it in items) {
        if (it.category.isNotEmpty) categories.add(it.category);
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Filter by Stock Balance toggle
          FilterChip(
            selected: _onlyWithBalance,
            label: const Text('In-Stock Only'),
            avatar: Icon(
              _onlyWithBalance ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: _onlyWithBalance ? Colors.white : AppColors.textMuted,
            ),
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.25),
            checkmarkColor: const Color(0xFF10B981),
            side: BorderSide(color: _onlyWithBalance ? const Color(0xFF10B981) : const Color(0xFF334155)),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _onlyWithBalance ? const Color(0xFF10B981) : AppColors.textSecondary,
            ),
            onSelected: (val) => setState(() => _onlyWithBalance = val),
          ),
          const SizedBox(width: 8),

          // Category Chips
          for (final cat in categories)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(cat),
                selected: _selectedCategory == cat,
                selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                side: BorderSide(color: _selectedCategory == cat ? const Color(0xFF06B6D4) : const Color(0xFF334155)),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _selectedCategory == cat ? const Color(0xFF06B6D4) : AppColors.textMuted,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(TeaMaterialReceivedModel item) {
    final hasBalance = item.currentBalance > 0.0001;
    final isLowStock = item.currentBalance > 0.0001 && item.currentBalance <= 5.0;

    final Color statusColor = hasBalance
        ? (isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
        : const Color(0xFF64748B);

    final String statusLabel = hasBalance
        ? (isLowStock ? 'LOW STOCK' : 'IN STOCK')
        : 'ZERO BALANCE';

    final latestDateStr = item.latestTransactionAt != null
        ? AppDateFormatter.formatWithTime(item.latestTransactionAt)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBalance
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFF334155).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Description + Code + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2_rounded, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              'CODE: ${item.materialCode}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.isNotEmpty ? item.category : 'TEA',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Unit: ${item.unit}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const Spacer(),
                          // Stock status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 18, color: Color(0xFF1E293B)),

            // Metrics Grid: Received | Consumed | Returned | Available Live Stock
            Row(
              children: [
                Expanded(
                  child: _quantityBox(
                    label: 'TOTAL RCVD',
                    value: QuantityFormatter.formatClean(item.totalReceived),
                    unit: item.unit,
                    color: const Color(0xFF06B6D4),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quantityBox(
                    label: 'CONSUMED',
                    value: QuantityFormatter.formatClean(item.totalConsumed),
                    unit: item.unit,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quantityBox(
                    label: 'RETURNED',
                    value: QuantityFormatter.formatClean(item.totalReturned),
                    unit: item.unit,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quantityBox(
                    label: 'LIVE BALANCE',
                    value: QuantityFormatter.formatClean(item.currentBalance),
                    unit: item.unit,
                    color: const Color(0xFF10B981),
                    isHighlighted: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Footer Row: Latest Tx Timestamp + Return to Admin Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Latest Tx: $latestDateStr',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                if (hasBalance)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFFC4B5FD),
                      side: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.keyboard_return_rounded, size: 14),
                    label: const Text(
                      'Return to Admin',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openReturnDialog(item),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.14)
            : const Color(0xFF030712).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.6 : 0.25),
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
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isHighlighted ? 13 : 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── RETURN TO ADMIN DIALOG ──────────────────────────────────────────────────
class _ReturnToAdminDialog extends ConsumerStatefulWidget {
  final TeaMaterialReceivedModel item;
  final VoidCallback onSuccess;

  const _ReturnToAdminDialog({
    required this.item,
    required this.onSuccess,
  });

  @override
  ConsumerState<_ReturnToAdminDialog> createState() => _ReturnToAdminDialogState();
}

class _ReturnToAdminDialogState extends ConsumerState<_ReturnToAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _personController = TextEditingController(text: 'Tea Supervisor');
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _personController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final returnQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (returnQty <= 0) return;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm Return to Admin?',
      message: 'Physically return ${QuantityFormatter.formatClean(returnQty)} ${widget.item.unit} of ${widget.item.description} to Admin Store inventory?\n\nThis will deduct ${QuantityFormatter.formatClean(returnQty)} ${widget.item.unit} from Tea live stock and credit it back to Admin.',
      confirmText: 'Yes, Confirm Return',
      cancelText: 'Cancel',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(teaConsumptionRepositoryProvider).recordReturnToAdmin(
            materialCode: widget.item.materialCode,
            description: widget.item.description,
            returnQty: returnQty,
            units: widget.item.unit,
            person: _personController.text.trim(),
            notes: _notesController.text.trim(),
          );

      widget.onSuccess();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully returned ${QuantityFormatter.formatClean(returnQty)} ${widget.item.unit} to Admin Store.',
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
            content: Text('Failed to record return: $e'),
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
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.keyboard_return_rounded, color: Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Return Material to Admin',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                Text(
                  '${widget.item.description} (${widget.item.materialCode})',
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
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Available Balance Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Currently Available in Tea:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '${QuantityFormatter.formatClean(widget.item.currentBalance)} ${widget.item.unit}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Return Quantity Input
                Text(
                  'RETURN QUANTITY (${widget.item.unit}) *',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _qtyController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Enter quantity to return',
                    suffixText: widget.item.unit,
                    suffixStyle: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter return quantity';
                    final qty = double.tryParse(val.trim());
                    if (qty == null || qty <= 0) return 'Must be greater than 0';
                    if (qty > (widget.item.currentBalance + 0.0001)) {
                      return 'Cannot exceed available balance (${QuantityFormatter.formatClean(widget.item.currentBalance)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Operator / Supervisor
                const Text('RETURNED BY (SUPERVISOR / PERSON) *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _personController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Supervisor name',
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please specify supervisor';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('REMARKS / REASON FOR RETURN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Unused stock returned to main store',
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
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Return', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
