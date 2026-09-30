import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/material_search_widget.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';

import '../../shared/widgets/grade_dropdown.dart';
import '../../shared/widgets/uom_dropdown.dart';
import '../../data/models/invoice_model.dart';
import '../../core/formatters/app_date_formatter.dart';

class _FormItem {
  String materialCode;
  String description;
  String category;
  String unit;
  double quantity;
  double unitPrice;
  double discount;
  double gst;
  double igst;
  String lotNo;
  DateTime? expiryDate;
  String hsnSac;
  String grade;

  _FormItem({
    this.materialCode = '',
    this.description = '',
    this.unit = 'kg',
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.discount = 0.0,
    this.gst = 0.0,
    this.lotNo = '',
  })  : category = 'General',
        igst = 0.0,
        expiryDate = null,
        hsnSac = '',
        grade = 'BP';

  double get gross => quantity * unitPrice;
  double get discountAmount => gross * (discount / 100.0);
  double get netAmount => gross - discountAmount;
  double get gstValue => double.parse((netAmount * (gst / 100.0)).toStringAsFixed(2));
  double get igstValue => double.parse((netAmount * (igst / 100.0)).toStringAsFixed(2));
  double get itemTotal => double.parse((netAmount + gstValue + igstValue).toStringAsFixed(2));

  Map<String, dynamic> toPayload() {
    return {
      'material': TextStandardizer.normalizeCode(materialCode),
      'description': TextStandardizer.normalizeBusinessText(description.isNotEmpty ? description : materialCode),
      'category': TextStandardizer.normalizeBusinessText(category),
      'unit': FactoryConstants.normalizeUomCode(unit),
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_percentage': discount,
      'gst_percentage': gst,
      'igst_percentage': igst,
      'lot_no': TextStandardizer.normalizeBusinessText(lotNo),
      'expiry_date': expiryDate != null ? AppDateFormatter.toDbDate(expiryDate!) : null,
      'hsn_sac': TextStandardizer.normalizeBusinessText(hsnSac),
      'grade': FactoryConstants.normalizeGradeCode(grade),
    };
  }
}

class AddInvoiceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialOcrData;
  final InvoiceModel? existingInvoice;

  const AddInvoiceScreen({super.key, this.initialOcrData, this.existingInvoice});

  @override
  ConsumerState<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends ConsumerState<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNoController = TextEditingController();
  final _purchaseIdController = TextEditingController(text: 'PUR-01');
  final _vendorController = TextEditingController();
  final _roundOffController = TextEditingController(text: '0.00');
  final _remarksController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  String _paymentStatus = 'Pending';
  bool _isSaving = false;

  final List<_FormItem> _items = [];

  bool get _isEditMode => widget.existingInvoice != null;

  @override
  void initState() {
    super.initState();
    _applyInitialData();
  }

  void _applyInitialData() {
    if (widget.existingInvoice != null) {
      final inv = widget.existingInvoice!;
      _invoiceNoController.text = inv.invoiceNo;
      _purchaseIdController.text = inv.purchaseId;
      _vendorController.text = inv.vendor;
      _invoiceDate = inv.date;
      _paymentStatus = inv.paymentStatus;
      _roundOffController.text = inv.roundOffValue.toStringAsFixed(2);
      _remarksController.text = inv.remarks;

      for (final item in inv.items) {
        final formItem = _FormItem(
          materialCode: item.material,
          unit: item.unit,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discount: item.discountPercentage,
          gst: item.gstPercentage,
          lotNo: item.batchNo,
        )
          ..category = 'General'
          ..igst = item.igstPercentage
          ..hsnSac = item.hsnSac
          ..grade = item.grade.isNotEmpty ? item.grade : 'BP';
        _items.add(formItem);
      }
    } else if (widget.initialOcrData != null) {
      final ocr = widget.initialOcrData!;
      _invoiceNoController.text = ocr['invoice_no']?.toString() ?? '';
      _vendorController.text = ocr['vendor']?.toString() ?? '';
      if (ocr['date'] is DateTime) _invoiceDate = ocr['date'] as DateTime;

      final rawItems = ocr['items'] as List<dynamic>?;
      if (rawItems != null && rawItems.isNotEmpty) {
        for (final item in rawItems) {
          final m = item as Map<String, dynamic>;
          _items.add(_FormItem(
            materialCode: m['material_code']?.toString() ?? '',
            description: m['description']?.toString() ?? '',
            quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
            unit: m['unit']?.toString() ?? 'kg',
            unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
            discount: (m['discount_percentage'] as num?)?.toDouble() ?? 0.0,
            gst: (m['gst_percentage'] as num?)?.toDouble() ?? 0.0,
            lotNo: m['lot_no']?.toString() ?? '',
          ));
        }
      }
    }

    if (_items.isEmpty) {
      _items.add(_FormItem(
        lotNo: 'BATCH-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}',
      ));
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _purchaseIdController.dispose();
    _vendorController.dispose();
    _roundOffController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.netAmount);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + i.gstValue);
  double get _totalIgst => _items.fold(0.0, (sum, i) => sum + i.igstValue);
  double get _grandTotal => double.parse((_subtotal + _totalGst + _totalIgst).toStringAsFixed(2));
  double get _roundOff => double.tryParse(_roundOffController.text) ?? 0.0;
  double get _finalTotal => double.parse((_grandTotal + _roundOff).toStringAsFixed(2));

  void _addItem() {
    setState(() {
      _items.add(_FormItem(
        lotNo: 'BATCH-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${_items.length + 1}',
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].materialCode.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item #${i + 1} is missing material code')),
        );
        return;
      }
      if (_items[i].quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item #${i + 1} quantity must be greater than 0')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final invoicePayload = {
        'purchase_id': TextStandardizer.normalizeBusinessText(_purchaseIdController.text),
        'date': _invoiceDate.toIso8601String().split('T')[0],
        'invoice_no': TextStandardizer.normalizeBusinessText(_invoiceNoController.text),
        'vendor': TextStandardizer.normalizeBusinessText(_vendorController.text),
        'no_of_items': _items.length,
        'round_off_value': _roundOff,
        'payment_status': _paymentStatus,
        'remarks': TextStandardizer.normalizeBusinessText(_remarksController.text),
      };

      final itemsPayload = _items.map((i) => i.toPayload()).toList();

      if (_isEditMode) {
        await ref.read(invoicesRepositoryProvider).updatePurchaseInvoice(
              invoiceId: widget.existingInvoice!.id,
              invoice: invoicePayload,
              items: itemsPayload,
            );
        ref.invalidate(invoiceDetailsProvider(widget.existingInvoice!.id));
      } else {
        await ref.read(invoicesRepositoryProvider).createPurchaseInvoice(
              invoice: invoicePayload,
              items: itemsPayload,
            );
      }

      ref.invalidate(invoicesListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Purchase Invoice and live material stock updated atomically!'
                : 'Purchase Invoice and live material stock saved atomically!'),
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
            content: Text('Failed to save invoice: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);
    final vendorsAsync = ref.watch(dynamicVendorsProvider);
    final existingVendors = vendorsAsync.asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Inward Purchase Invoice' : 'New Inward Purchase Invoice'),
      ),
      body: AmbientBackground(
        child: Form(
          key: _formKey,
          child: isTablet ? _buildTabletLayout(existingVendors) : _buildMobileLayout(existingVendors),
        ),
      ),
    );
  }

  Widget _buildMultiPageBanner() {
    if (widget.initialOcrData?['multi_page_job_id'] == null) return const SizedBox.shrink();
    final pageCount = widget.initialOcrData!['page_count'] ?? 1;
    final conf = ((widget.initialOcrData!['average_confidence'] as num?)?.toDouble() ?? 0.95) * 100;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Page Scanned Invoice ($pageCount Pages Merged)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  'All continuation lines unified into 1 invoice document (${conf.toInt()}% confidence). Stock will update exactly once per line.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<String> existingVendors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMultiPageBanner(),
          _buildHeaderSection(existingVendors),
          const SizedBox(height: 16),
          _buildItemsSection(),
          const SizedBox(height: 16),
          _buildTotalsCard(),
          const SizedBox(height: 24),
          GlassButton(
            text: _isEditMode ? 'Update Purchase Invoice' : 'Save Inward Purchase',
            isLoading: _isSaving,
            icon: Icons.check_circle_outline,
            onPressed: _submitInvoice,
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(List<String> existingVendors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Form Header & Items
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMultiPageBanner(),
                  _buildHeaderSection(existingVendors),
                  const SizedBox(height: 16),
                  _buildItemsSection(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Totals & Commit
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTotalsCard(),
                  const SizedBox(height: 20),
                  GlassButton(
                    text: _isEditMode ? 'Update Purchase Invoice' : 'Save Inward Purchase',
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline,
                    onPressed: _submitInvoice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(List<String> existingVendors) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Details',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: StandardizedTextField(
                  controller: _invoiceNoController,
                  isCodeField: true,
                  labelText: 'Invoice No *',
                  hintText: 'e.g. INV-2026-08',
                  prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _invoiceDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(
                      QuantityFormatter.formatDate(_invoiceDate),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StandardizedTextField(
            controller: _vendorController,
            labelText: 'Vendor / Supplier Name *',
            hintText: 'e.g. JAI AGENCIES',
            prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
            referenceCandidates: existingVendors,
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StandardizedTextField(
                  controller: _purchaseIdController,
                  isCodeField: true,
                  labelText: 'Purchase ID',
                  hintText: 'e.g. PUR-01',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentStatus,
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(labelText: 'Payment Status'),
                  items: const [
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentStatus = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StandardizedTextField(
            controller: _remarksController,
            labelText: 'Remarks / Notes',
            hintText: 'e.g. RECEIVED IN GOOD CONDITION',
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Line Items (${_items.length})',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryLight),
              label: const Text('Add Item', style: TextStyle(color: AppColors.primaryLight)),
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildLineItemCard(i),
        ),
      ],
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _items[index];

    return GlassCard(
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
                child: Text('Item #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
              ),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  onPressed: () => _removeItem(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // â”€â”€ Material Search (Code OR Description live search) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          MaterialSearchWidget(
            labelText: 'Search Material â€” Code or Name *',
            initialCode: item.materialCode,
            onSelected: (sel) {
              setState(() {
                item.materialCode = sel.code;
                item.description  = sel.description;
                item.category     = sel.category;
                item.unit         = sel.unit.isEmpty ? 'kg' : sel.unit;
                item.hsnSac       = sel.hsnSac;
                item.grade        = sel.grade.isEmpty ? 'STANDARD' : sel.grade;
              });
            },
          ),
          // â”€â”€ Auto-filled master info chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (item.materialCode.isNotEmpty) ...
            [
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _infoBadge('Code: ${item.materialCode}', AppColors.primary),
                  if (item.category.isNotEmpty) _infoBadge(item.category, AppColors.accent),
                  if (item.hsnSac.isNotEmpty) _infoBadge('HSN: ${item.hsnSac}', AppColors.textSecondary),
                  if (item.grade.isNotEmpty && item.grade != 'STANDARD') _infoBadge('Grade: ${item.grade}', AppColors.warning),
                ],
              ),
            ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                  onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 0.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: UomDropdown(
                  value: item.unit,
                  labelText: 'UOM',
                  onChanged: (val) {
                    if (val != null) setState(() => item.unit = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextFormField(
                  initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Unit Price (â‚¹)'),
                  onChanged: (val) => setState(() => item.unitPrice = double.tryParse(val) ?? 0.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.discount > 0 ? item.discount.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Disc %'),
                  onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.gst > 0 ? item.gst.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'GST %'),
                  onChanged: (val) => setState(() => item.gst = double.tryParse(val) ?? 0.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.igst > 0 ? item.igst.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'IGST %'),
                  onChanged: (val) => setState(() => item.igst = double.tryParse(val) ?? 0.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  initialValue: item.lotNo,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Lot / Batch No'),
                  onChanged: (val) => setState(() => item.lotNo = val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: GradeDropdown(
                  value: item.grade,
                  labelText: 'Grade',
                  onChanged: (val) {
                    if (val != null) setState(() => item.grade = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net: ${QuantityFormatter.formatCurrency(item.netAmount)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text('Tax: ${QuantityFormatter.formatCurrency(item.gstValue + item.igstValue)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text('Total: ${QuantityFormatter.formatCurrency(item.itemTotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildTotalsCard() {
    return GlassCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Calculation Summary',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          _buildSummaryRow('Subtotal (Excl. Tax)', QuantityFormatter.formatCurrency(_subtotal)),
          const SizedBox(height: 6),
          _buildSummaryRow('Total GST', QuantityFormatter.formatCurrency(_totalGst)),
          const SizedBox(height: 6),
          _buildSummaryRow('Total IGST', QuantityFormatter.formatCurrency(_totalIgst)),
          const Divider(height: 16),
          _buildSummaryRow('Grand Total', QuantityFormatter.formatCurrency(_grandTotal), isBold: true),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Round Off:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _roundOffController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Bill Total',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                QuantityFormatter.formatCurrency(_finalTotal),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
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
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

