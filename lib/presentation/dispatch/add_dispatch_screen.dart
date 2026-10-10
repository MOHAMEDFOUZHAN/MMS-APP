import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../data/models/dispatch_model.dart';
import '../../data/models/storage_product_model.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';

class AddDispatchScreen extends ConsumerStatefulWidget {
  final DispatchModel? existingDispatch;
  const AddDispatchScreen({super.key, this.existingDispatch});

  @override
  ConsumerState<AddDispatchScreen> createState() => _AddDispatchScreenState();
}

class _AddDispatchScreenState extends ConsumerState<AddDispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _returnController = TextEditingController(text: '0.000');
  final _locationController = TextEditingController();
  final _remarksController = TextEditingController();

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();

  DateTime _dispatchDate = DateTime.now();
  String _selectedDepartment = 'Dispatch';

  // Storage Product Identity (Independent of Material Master)
  int? _storageProductId;
  String _productCode = '';
  String _productName = '';
  String _grade = 'STANDARD';
  String _selectedUnit = 'kg';

  // Authoritative Storage Stock Preview from Supabase Server
  double _availableStorageStock = 0.0;
  List<Map<String, dynamic>> _storageBatches = [];
  List<Map<String, dynamic>> _serverAllocations = [];
  bool _isLoadingPreview = false;
  bool _isSaving = false;

  // Available Storage Products cache for instant autocomplete
  List<DispatchAvailableProductModel> _availableProducts = [];
  bool _isLoadingProducts = false;

  bool get _isEditMode => widget.existingDispatch != null;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onQuantityOrReturnChanged);
    _returnController.addListener(_onQuantityOrReturnChanged);

    _loadAvailableProducts();

    if (widget.existingDispatch != null) {
      final d = widget.existingDispatch!;
      _storageProductId = d.storageProductId;
      _productCode = d.materialCode;
      _productName = d.product;
      _codeController.text = d.materialCode;
      _nameController.text = d.product;
      _grade = d.grade.isNotEmpty ? d.grade : 'STANDARD';
      _selectedUnit = d.units;
      _selectedDepartment = d.department.isNotEmpty ? d.department : 'Dispatch';
      _locationController.text = d.location;
      _remarksController.text = d.remarks;
      _quantityController.text = d.quantity.toStringAsFixed(3);
      _returnController.text = d.returnQuantity.toStringAsFixed(3);
      _dispatchDate = d.date;
      _fetchServerStockPreview();
    }
  }

  Future<void> _loadAvailableProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final repo = ref.read(storageProductsRepositoryProvider);
      final products = await repo.getDispatchAvailableProducts();
      if (mounted) {
        setState(() {
          _availableProducts = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _onQuantityOrReturnChanged() {
    _fetchServerStockPreview();
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityOrReturnChanged);
    _returnController.removeListener(_onQuantityOrReturnChanged);
    _quantityController.dispose();
    _returnController.dispose();
    _locationController.dispose();
    _remarksController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onProductSelected(DispatchAvailableProductModel selection) {
    setState(() {
      _productCode = selection.productCode;
      _productName = selection.productName;
      _codeController.text = selection.productCode;
      _nameController.text = selection.productName;
      if (selection.uom.isNotEmpty) _selectedUnit = selection.uom.toLowerCase();
      if (selection.grade.isNotEmpty) _grade = selection.grade;
      _availableStorageStock = selection.totalAvailable;
    });
    _fetchServerStockPreview();
  }

  void _onCodeChanged(String val) {
    final trimmed = val.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    final match = _availableProducts.where((p) => p.productCode.trim().toLowerCase() == trimmed).firstOrNull;
    if (match != null) {
      _onProductSelected(match);
    }
  }

  void _onNameChanged(String val) {
    final trimmed = val.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    final match = _availableProducts.where((p) => p.productName.trim().toLowerCase() == trimmed).firstOrNull;
    if (match != null) {
      _onProductSelected(match);
    }
  }

  /// Authoritative server-side stock availability and FIFO allocation preview
  Future<void> _fetchServerStockPreview() async {
    if (_productCode.isEmpty) {
      setState(() {
        _availableStorageStock = 0.0;
        _storageBatches = [];
        _serverAllocations = [];
      });
      return;
    }

    final reqQty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final retQty = double.tryParse(_returnController.text.trim()) ?? 0.0;

    setState(() => _isLoadingPreview = true);

    try {
      final repo = ref.read(dispatchesRepositoryProvider);
      final preview = await repo.getStorageDispatchPreview(
        materialCode: _productCode,
        requestedQuantity: reqQty,
        returnQuantity: retQty,
      );

      if (mounted) {
        setState(() {
          _availableStorageStock = (preview['total_available'] as num?)?.toDouble() ?? 0.0;
          _storageBatches = (preview['batches'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _serverAllocations = (preview['allocations'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPreview = false);
      }
    }
  }

  Future<void> _submitDispatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_productCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a finished product from Storage.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final retQty = double.tryParse(_returnController.text.trim()) ?? 0.0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispatch quantity must be greater than zero.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (retQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return quantity cannot be negative.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final netQty = qty - retQty;
    if (netQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return quantity cannot exceed dispatch quantity.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Atomic pre-check against Storage stock (Requirement 11)
    if (netQty > _availableStorageStock) {
      final shortage = netQty - _availableStorageStock;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Insufficient Storage Stock',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.danger),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requested dispatch quantity exceeds the total available stock in Storage batches. No partial dispatch will be created.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _dialogRow('Requested Quantity', '${QuantityFormatter.formatClean(qty)} $_selectedUnit'),
                    _dialogRow('Return Quantity', '${QuantityFormatter.formatClean(retQty)} $_selectedUnit'),
                    _dialogRow('Net Dispatch', '${QuantityFormatter.formatClean(netQty)} $_selectedUnit'),
                    _dialogRow('Total Storage Available', '${QuantityFormatter.formatClean(_availableStorageStock)} $_selectedUnit'),
                    const Divider(height: 14),
                    _dialogRow('Stock Shortage', '${QuantityFormatter.formatClean(shortage)} $_selectedUnit', isBold: true, color: AppColors.danger),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
      return;
    }

    // Multi-batch FIFO confirmation popup (Requirement 10)
    // If dispatch quantity exceeds first batch available quantity, inform user clearly
    if (_storageBatches.isNotEmpty && _serverAllocations.length > 1) {
      final firstBatch = _storageBatches.first;
      final firstBatchAvail = (firstBatch['available_quantity'] as num?)?.toDouble() ?? 0.0;
      final firstBatchNo = firstBatch['batch_no']?.toString() ?? '1';

      if (qty > firstBatchAvail && firstBatchAvail > 0) {
        final remainingTaken = qty - firstBatchAvail;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Multi-Batch Allocation Notice',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch $firstBatchNo has only ${QuantityFormatter.formatClean(firstBatchAvail)} $_selectedUnit available.\n\nThe remaining ${QuantityFormatter.formatClean(remainingTaken)} $_selectedUnit will be taken from the next available batch in FIFO sequence.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(dispatchesRepositoryProvider);
      if (_isEditMode) {
        await repo.updateDispatch(
          dispatchId: widget.existingDispatch!.id,
          storageProductId: _storageProductId,
          materialCode: TextStandardizer.normalizeCode(_productCode),
          product: TextStandardizer.normalizeBusinessText(_productName.isNotEmpty ? _productName : _productCode),
          category: 'Finished Goods',
          grade: _grade,
          quantity: qty,
          returnQuantity: retQty,
          units: _selectedUnit,
          location: TextStandardizer.normalizeBusinessText(_locationController.text),
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          remarks: TextStandardizer.normalizeBusinessText(_remarksController.text),
          date: _dispatchDate,
        );
      } else {
        await repo.createDispatchFifo(
          storageProductId: _storageProductId,
          materialCode: TextStandardizer.normalizeCode(_productCode),
          product: TextStandardizer.normalizeBusinessText(_productName.isNotEmpty ? _productName : _productCode),
          category: 'Finished Goods',
          grade: _grade,
          quantity: qty,
          returnQuantity: retQty,
          units: _selectedUnit,
          location: TextStandardizer.normalizeBusinessText(_locationController.text),
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          remarks: TextStandardizer.normalizeBusinessText(_remarksController.text),
          date: _dispatchDate,
        );
      }

      ref.invalidate(dispatchesListProvider);
      ref.invalidate(batchesListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(inwardHistoryProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dispatchAvailableProductsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Dispatch #${widget.existingDispatch!.id} updated with atomic FIFO batch re-allocation!'
                : 'Dispatched ${QuantityFormatter.formatClean(qty)} $_selectedUnit (Net: ${QuantityFormatter.formatClean(netQty)}) from Storage batches!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        final friendlyError = _formatDispatchError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDispatchError(dynamic e) {
    debugPrint('[DISPATCH ERROR] Technical details: $e');
    final errStr = e.toString();

    // Check known business errors
    if (errStr.contains('Insufficient Storage Stock')) {
      final match = RegExp(r'Insufficient Storage Stock[^\n]*').firstMatch(errStr);
      return match != null ? match.group(0)! : 'Insufficient Storage Stock. Please check available quantity.';
    }
    if (errStr.contains('Return quantity cannot exceed Dispatch quantity') ||
        errStr.contains('cannot exceed Dispatch quantity')) {
      return 'Return quantity cannot exceed Dispatch quantity.';
    }
    if (errStr.contains('Return quantity cannot be negative')) {
      return 'Return quantity cannot be negative.';
    }
    if (errStr.contains('Dispatch quantity must be greater than zero')) {
      return 'Dispatch quantity must be greater than zero.';
    }
    if (errStr.contains('Product code is required')) {
      return 'Product code is required for Dispatch.';
    }

    if (kDebugMode) {
      // In development/debug builds, provide technical error info safely
      final sanitized = errStr.replaceAll(RegExp(r'Bearer [A-Za-z0-9_\-\.]+'), 'Bearer ***');
      return 'Unable to save Dispatch: $sanitized (RPC: ${_isEditMode ? "update_dispatch" : "create_dispatch_fifo"}). No stock was changed.';
    }

    return 'Unable to save Dispatch. No stock was changed. Please try again.';
  }

  Widget _dialogRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Dispatch' : 'Record Storage Stock-Out (FIFO)'),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet / Desktop 2-Column Responsive Layout
  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Form Fields
            Expanded(
              flex: 6,
              child: _buildFormCard(),
            ),
            const SizedBox(width: 16),
            // Right Column: Storage Batch Stock & FIFO Allocation Preview
            Expanded(
              flex: 5,
              child: _buildPreviewCard(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildActionButtons(),
      ],
    );
  }

  /// Phone Single-Column Stacked Responsive Layout
  Widget _buildPhoneLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFormCard(),
        const SizedBox(height: 16),
        _buildPreviewCard(),
        const SizedBox(height: 20),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.glassBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GlassButton(
            text: _isEditMode ? 'Update Dispatch' : 'Save Dispatch',
            height: 50,
            isLoading: _isSaving,
            icon: Icons.check_circle_rounded,
            color: AppColors.secondary,
            onPressed: _submitDispatch,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return GlassCard(
      accentColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Stock-Out Operation',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Direct stock deduction from Storage batches in FIFO sequence. Finished products only.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // ─────────────────────────────────────────────────────────────
          // SECTION 1: PRODUCT
          // ─────────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 6),
              Text(
                'PRODUCT (STORAGE ONLY)',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Code Field
          Text('Product Code *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          RawAutocomplete<DispatchAvailableProductModel>(
            textEditingController: _codeController,
            focusNode: _codeFocusNode,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _availableProducts;
              }
              final q = textEditingValue.text.trim().toLowerCase();
              return _availableProducts.where(
                (p) => p.productCode.toLowerCase().contains(q) || p.productName.toLowerCase().contains(q),
              );
            },
            displayStringForOption: (DispatchAvailableProductModel option) => option.productCode,
            onSelected: _onProductSelected,
            optionsViewBuilder: (context, onSelected, options) {
              final width = MediaQuery.of(context).size.width.clamp(280.0, 480.0);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: width),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.glassBorder, height: 1),
                        itemBuilder: (context, index) {
                          final opt = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(opt.productCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 13)),
                            subtitle: Text('${opt.productName} • ${QuantityFormatter.formatClean(opt.totalAvailable)} ${opt.uom} available',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Select Product Code from Storage',
                  prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                  suffixIcon: _isLoadingProducts
                      ? const SizedBox(width: 14, height: 14, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
                onChanged: _onCodeChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'Product Code required' : null,
              );
            },
          ),
          const SizedBox(height: 12),

          // Product Name Field
          Text('Product Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          RawAutocomplete<DispatchAvailableProductModel>(
            textEditingController: _nameController,
            focusNode: _nameFocusNode,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _availableProducts;
              }
              final q = textEditingValue.text.trim().toLowerCase();
              return _availableProducts.where(
                (p) => p.productName.toLowerCase().contains(q) || p.productCode.toLowerCase().contains(q),
              );
            },
            displayStringForOption: (DispatchAvailableProductModel option) => option.productName,
            onSelected: _onProductSelected,
            optionsViewBuilder: (context, onSelected, options) {
              final width = MediaQuery.of(context).size.width.clamp(280.0, 480.0);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: width),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.glassBorder, height: 1),
                        itemBuilder: (context, index) {
                          final opt = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(opt.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                            subtitle: Text('${opt.productCode} • ${QuantityFormatter.formatClean(opt.totalAvailable)} ${opt.uom} available',
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 11)),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Select Product Name from Storage',
                  prefixIcon: Icon(Icons.description_outlined, size: 18),
                ),
                onChanged: _onNameChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'Product Name required' : null,
              );
            },
          ),
          const SizedBox(height: 12),

          // Available Storage Stock Strip
          if (_productCode.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _availableStorageStock > 0 ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _availableStorageStock > 0 ? AppColors.success.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _availableStorageStock > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 16,
                    color: _availableStorageStock > 0 ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Available Storage Stock: ${QuantityFormatter.formatClean(_availableStorageStock)} $_selectedUnit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _availableStorageStock > 0 ? AppColors.success : AppColors.danger,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(height: 20),

          // ─────────────────────────────────────────────────────────────
          // SECTION 2: DISPATCH DETAILS
          // ─────────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'DISPATCH DETAILS',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dispatch Date (Formatted DD/MM/YYYY)
          Text('Dispatch Date *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dispatchDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF0F172A)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _dispatchDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Text(
                        AppDateFormatter.format(_dispatchDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    'DD/MM/YYYY',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dispatch Quantity & Return Quantity Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dispatch Quantity
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dispatch Quantity *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      decoration: InputDecoration(
                        hintText: '0.000',
                        suffixText: _selectedUnit,
                        prefixIcon: const Icon(Icons.scale_rounded, size: 18, color: AppColors.secondary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter quantity';
                        final d = double.tryParse(val.trim());
                        if (d == null || d <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Return Quantity (Requirement 12)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Return Quantity', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _returnController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      decoration: InputDecoration(
                        hintText: '0.000',
                        suffixText: _selectedUnit,
                        prefixIcon: const Icon(Icons.assignment_return_rounded, size: 18, color: AppColors.primaryLight),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final d = double.tryParse(val.trim());
                          if (d == null || d < 0) return 'Cannot be negative';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Department Field
          Text('Department', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: FactoryConstants.departments.contains(_selectedDepartment) ? _selectedDepartment : 'Dispatch',
            dropdownColor: const Color(0xFF0F172A),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.apartment_rounded, size: 18),
            ),
            items: [
              const DropdownMenuItem(value: 'Dispatch', child: Text('Dispatch')),
              ...FactoryConstants.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedDepartment = val);
            },
          ),
          const SizedBox(height: 14),

          // Destination Location
          Text('Destination Location / Customer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          StandardizedTextField(
            controller: _locationController,
            labelText: 'Destination / Warehouse / Store',
            hintText: 'e.g. OOTY RETAIL STORE',
            referenceCandidates: ref.watch(dynamicLocationsProvider).asData?.value ?? const [],
          ),
          const SizedBox(height: 14),

          // Remarks
          Text('Dispatch Remarks / Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _remarksController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Add optional notes, order reference, or dispatch instructions...',
              prefixIcon: Icon(Icons.notes_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final reqQty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final retQty = double.tryParse(_returnController.text.trim()) ?? 0.0;
    final netQty = (reqQty - retQty).clamp(0.0, double.infinity);
    final isOverStock = netQty > _availableStorageStock;
    final shortage = isOverStock ? netQty - _availableStorageStock : 0.0;
    final remainingStorage = (_availableStorageStock - netQty).clamp(0.0, double.infinity);

    return GlassCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.layers_outlined, color: AppColors.primaryLight, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'STORAGE ALLOCATION',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight, letterSpacing: 0.5),
                  ),
                ],
              ),
              if (_isLoadingPreview)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                ),
            ],
          ),
          const Divider(height: 20),

          // Total Storage Available Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _availableStorageStock > 0 ? AppColors.success.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _availableStorageStock > 0 ? AppColors.success.withValues(alpha: 0.35) : AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Available in Storage:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    Text(
                      '${QuantityFormatter.formatClean(_availableStorageStock)} $_selectedUnit',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _availableStorageStock > 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _availableStorageStock > 0 ? AppColors.success.withValues(alpha: 0.2) : AppColors.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_storageBatches.length} Batches',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _availableStorageStock > 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Available Batches Breakdown (FIFO sequence)
          Text(
            'Eligible Storage Batches (FIFO Sequence):',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          if (_storageBatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x33020617),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Center(
                child: Text(
                  _productCode.isEmpty
                      ? 'Select a finished product to view storage batches.'
                      : 'No available storage batches found for $_productCode.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._storageBatches.map((b) {
              final bNo = b['batch_no']?.toString() ?? '-';
              final bAvail = (b['available_quantity'] as num?)?.toDouble() ?? 0.0;
              final rawTs = b['received_at'] ?? b['created_at'];
              final timeStr = rawTs != null ? AppDateFormatter.formatTime(rawTs) : null;
              final displayDate = AppDateFormatter.format(b['batch_date'] ?? b['received_date'] ?? rawTs);
              final isExpired = b['is_expired'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpired ? AppColors.danger.withValues(alpha: 0.08) : const Color(0x33020617),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isExpired ? AppColors.danger.withValues(alpha: 0.3) : AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Batch $bNo',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$displayDate${timeStr != null && timeStr != '-' ? " • $timeStr" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Text(
                      '${QuantityFormatter.formatClean(bAvail)} $_selectedUnit',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              );
            }),

          // FIFO Dynamic Allocation Card
          if (reqQty > 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FIFO Allocation Breakdown',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                ),
                Text(
                  isOverStock ? 'Shortage Detected' : 'Fully Covered',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOverStock ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isOverStock)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Shortage of ${QuantityFormatter.formatClean(shortage)} $_selectedUnit. Inward new batches before dispatching.',
                        style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            ..._serverAllocations.map((alloc) {
              final bNo = alloc['batch_no']?.toString() ?? '';
              final take = (alloc['allocated_quantity'] as num?)?.toDouble() ?? 0.0;
              final bRemain = (alloc['batch_remaining'] as num?)?.toDouble() ?? 0.0;
              final bDate = alloc['batch_date']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Batch $bNo ($bDate)',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Deduct: ${QuantityFormatter.formatClean(take)} $_selectedUnit',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                        Text(
                          'Remaining: ${QuantityFormatter.formatClean(bRemain)} $_selectedUnit',
                          style: TextStyle(
                            fontSize: 10,
                            color: bRemain <= 0.0001 ? AppColors.textMuted : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          // ─────────────────────────────────────────────────────────────
          // SECTION 3: SUMMARY CARD (Requirement 17)
          // ─────────────────────────────────────────────────────────────
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.summarize_outlined, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'SUMMARY',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x33020617),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _summaryRow('Requested Dispatch', '${QuantityFormatter.formatClean(reqQty)} $_selectedUnit'),
                _summaryRow('Returned Quantity', '${QuantityFormatter.formatClean(retQty)} $_selectedUnit', color: AppColors.primaryLight),
                _summaryRow('Net Dispatch', '${QuantityFormatter.formatClean(netQty)} $_selectedUnit', isBold: true, color: AppColors.secondary),
                const Divider(height: 12),
                _summaryRow('Remaining Storage', '${QuantityFormatter.formatClean(remainingStorage)} $_selectedUnit',
                    isBold: true, color: remainingStorage > 0 ? AppColors.success : AppColors.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
