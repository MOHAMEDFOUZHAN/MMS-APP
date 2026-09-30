import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/theme/glass_widgets.dart';
import '../providers/app_providers.dart';

class WithoutInvoiceScreen extends ConsumerStatefulWidget {
  const WithoutInvoiceScreen({super.key});

  @override
  ConsumerState<WithoutInvoiceScreen> createState() => _WithoutInvoiceScreenState();
}

class _WithoutInvoiceScreenState extends ConsumerState<WithoutInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _materialCodeController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lotController = TextEditingController();

  String _selectedCategory = 'General';
  String _selectedUnit = 'kg';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _lotController.text = 'BATCH-${now.year}${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _materialCodeController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _lotController.dispose();
    super.dispose();
  }

  void _addQuickQty(double addAmount) {
    final curr = double.tryParse(_quantityController.text) ?? 0.0;
    _quantityController.text = (curr + addAmount).toStringAsFixed(3);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final rnd = Random().nextInt(900) + 100;
      final autoInvoiceNo = 'WO-${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$rnd';

      final qty = double.parse(_quantityController.text);
      final code = _materialCodeController.text.trim().toUpperCase();
      final desc = _descController.text.trim();
      final lot = _lotController.text.trim();

      final invoicePayload = {
        'purchase_id': 'WITHOUT-INV',
        'date': now.toIso8601String().split('T')[0],
        'invoice_no': autoInvoiceNo,
        'vendor': 'Without Invoice / Factory Floor Local Receipt',
        'no_of_items': 1,
        'round_off_value': 0.0,
        'payment_status': 'Paid',
        'remarks': 'Fast inward factory entry',
      };

      final itemsPayload = [
        {
          'material': code,
          'description': desc.isNotEmpty ? desc : code,
          'category': _selectedCategory,
          'unit': _selectedUnit,
          'quantity': qty,
          'unit_price': 0.0,
          'discount_percentage': 0.0,
          'gst_percentage': 0.0,
          'igst_percentage': 0.0,
          'lot_no': lot,
          'expiry_date': null,
          'hsn_sac': '',
          'grade': 'STANDARD',
        }
      ];

      await ref.read(invoicesRepositoryProvider).createPurchaseInvoice(
            invoice: invoicePayload,
            items: itemsPayload,
          );

      ref.invalidate(invoicesListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received $qty $_selectedUnit of $code into stock!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Inward (Without Invoice)'),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  accentColor: AppColors.success,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: AppColors.success, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Stock Receipt',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Direct stock receipt without vendor bill. Immediately increases live inventory and storage batch.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),

                      // Material Code
                      TextFormField(
                        controller: _materialCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Material Code *',
                          hintText: 'e.g. TEA-PKG-01',
                          prefixIcon: Icon(Icons.qr_code, size: 18),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Item Description
                      TextFormField(
                        controller: _descController,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Item Description (Optional)',
                          hintText: 'e.g. Filter Paper Rolls',
                          prefixIcon: Icon(Icons.description_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category and Unit
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              dropdownColor: AppColors.surface,
                              decoration: const InputDecoration(labelText: 'Category'),
                              items: const [
                                DropdownMenuItem(value: 'General', child: Text('General')),
                                DropdownMenuItem(value: 'Tea Packaging', child: Text('Tea Packaging')),
                                DropdownMenuItem(value: 'Chocolate Raw Materials', child: Text('Chocolate Raw')),
                                DropdownMenuItem(value: 'Essential Oils', child: Text('Essential Oils')),
                                DropdownMenuItem(value: 'Kitchen Spices', child: Text('Kitchen Spices')),
                                DropdownMenuItem(value: 'Cleaning Supplies', child: Text('Cleaning')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              dropdownColor: AppColors.surface,
                              decoration: const InputDecoration(labelText: 'UOM'),
                              items: FactoryConstants.units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Large Quantity Input
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
                        decoration: InputDecoration(
                          labelText: 'Received Quantity *',
                          suffixText: _selectedUnit,
                          suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          prefixIcon: const Icon(Icons.scale_rounded, size: 24),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter quantity';
                          final d = double.tryParse(val);
                          if (d == null || d <= 0) return 'Invalid quantity';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Quick quantity add buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickAddBtn('+1', 1.0),
                          _buildQuickAddBtn('+5', 5.0),
                          _buildQuickAddBtn('+10', 10.0),
                          _buildQuickAddBtn('+25', 25.0),
                          _buildQuickAddBtn('+50', 50.0),
                          _buildQuickAddBtn('+100', 100.0),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lot No
                      TextFormField(
                        controller: _lotController,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Assigned Lot / Batch Number',
                          prefixIcon: Icon(Icons.tag_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  text: 'Commit Stock Inward',
                  height: 52,
                  isLoading: _isSaving,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddBtn(String label, double amount) {
    return InkWell(
      onTap: () => _addQuickQty(amount),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
