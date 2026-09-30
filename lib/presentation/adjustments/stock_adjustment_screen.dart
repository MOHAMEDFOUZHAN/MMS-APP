import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const StockAdjustmentScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  bool _isAuthorized = false;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  MaterialModel? _selectedMaterial;
  String _operation = 'subtract'; // 'subtract' or 'add'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAuthorization();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _requestAuthorization() async {
    final ok = await PinAuthDialog.show(
      context,
      title: 'Stock Adjustment Authorization',
      message: 'Enter Supervisor PIN to access secure inventory adjustments.',
    );

    if (mounted) {
      if (ok) {
        setState(() => _isAuthorized = true);
      } else {
        Navigator.maybePop(context);
      }
    }
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a material code')));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be positive')));
      return;
    }

    if (_operation == 'subtract' && amount > _selectedMaterial!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot subtract $amount — only ${_selectedMaterial!.quantity} in stock!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm Stock Adjustment',
      message: 'Are you sure you want to $_operation $amount ${_selectedMaterial!.unit} for ${_selectedMaterial!.materialCode}?',
      confirmText: 'Yes, Apply Adjustment',
      isDestructive: _operation == 'subtract',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(stockAdjustmentsRepositoryProvider);
      final res = await repo.createAdjustment(
        materialCode: TextStandardizer.normalizeCode(_selectedMaterial!.materialCode),
        operation: _operation,
        amount: amount,
        reason: TextStandardizer.normalizeBusinessText(
          _reasonController.text.trim().isNotEmpty ? _reasonController.text : 'Manual inventory reconciliation',
        ),
      );

      ref.invalidate(stockAdjustmentsListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      _amountController.clear();
      _reasonController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock adjusted! Before: ${res['before_qty']}, After: ${res['after_qty']}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        appBar: widget.isEmbedded ? null : AppBar(title: const Text('Stock Adjustment')),
        body: Center(
          child: EmptyStateWidget(
            icon: Icons.lock_outline,
            title: 'Authorization Required',
            message: 'You need supervisor clearance to perform inventory stock adjustments.',
            actionLabel: 'Enter PIN',
            onAction: _requestAuthorization,
          ),
        ),
      );
    }

    final materialsAsync = ref.watch(materialsListProvider);
    final historyAsync = ref.watch(stockAdjustmentsListProvider);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Stock Adjustment'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.lock_rounded, size: 20),
                  tooltip: 'Lock screen',
                  onPressed: () => setState(() => _isAuthorized = false),
                ),
              ],
            ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Adjustment Form Card
              GlassCard(
                accentColor: _operation == 'subtract' ? AppColors.danger : AppColors.success,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Create Adjustment',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          // Add vs Subtract Segmented Control
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                _buildOpToggle('subtract', 'Subtract (FIFO)', AppColors.danger),
                                _buildOpToggle('add', 'Add', AppColors.success),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Material Selector
                      materialsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.danger)),
                        data: (materials) {
                          final unique = <String, MaterialModel>{};
                          for (final m in materials) {
                            if (!unique.containsKey(m.materialCode)) {
                              unique[m.materialCode] = m;
                            }
                          }
                          final list = unique.values.toList();

                          return DropdownButtonFormField<MaterialModel>(
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(
                              labelText: 'Target Material Code *',
                              prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                            ),
                            value: _selectedMaterial,
                            items: list.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text('${m.materialCode} - ${m.description} (${m.quantity} ${m.unit})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedMaterial = val);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      if (_selectedMaterial != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Current Total Stock:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              Text(
                                QuantityFormatter.formatDualUnit(_selectedMaterial!.quantity, _selectedMaterial!.unit),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _operation == 'subtract' ? AppColors.danger : AppColors.success,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Adjustment Amount *',
                          suffixText: _selectedMaterial?.unit ?? 'kg',
                          prefixIcon: Icon(
                            _operation == 'subtract' ? Icons.remove_circle_outline : Icons.add_circle_outline,
                            color: _operation == 'subtract' ? AppColors.danger : AppColors.success,
                            size: 20,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          final d = double.tryParse(val);
                          if (d == null || d <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      StandardizedTextField(
                        controller: _reasonController,
                        labelText: 'Reason for Adjustment *',
                        hintText: 'e.g. PHYSICAL INVENTORY COUNT MISMATCH / SPILL',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Reason is required' : null,
                      ),
                      const SizedBox(height: 16),

                      GlassButton(
                        text: _operation == 'subtract' ? 'Execute FIFO Subtraction' : 'Execute Stock Addition',
                        height: 48,
                        isLoading: _isSaving,
                        color: _operation == 'subtract' ? AppColors.danger : AppColors.success,
                        onPressed: _submitAdjustment,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Audit History Section
              Text(
                'Adjustment Audit Log',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              historyAsync.when(
                loading: () => const LoadingSkeletonList(count: 3),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (history) {
                  if (history.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.history_rounded,
                      title: 'No adjustments recorded',
                      message: 'Inventory adjustments will be permanently logged here.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = history[i];
                      final isSub = item.operation.toLowerCase() == 'subtract';
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isSub ? AppColors.danger : AppColors.success).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.operation.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: isSub ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.materialCode,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                Text(
                                  QuantityFormatter.formatDateTime(item.createdAt),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Adjusted: ${isSub ? "-" : "+"}${QuantityFormatter.format3Decimals(item.amount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSub ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                Text(
                                  'Stock: ${QuantityFormatter.format3Decimals(item.beforeQty)} → ${QuantityFormatter.format3Decimals(item.afterQty)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            if (item.reason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${item.reason}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpToggle(String op, String label, Color color) {
    final isSelected = _operation == op;
    return InkWell(
      onTap: () => setState(() => _operation = op),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
