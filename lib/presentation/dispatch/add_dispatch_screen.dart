import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/dispatch_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/material_search_widget.dart';
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
  final _locationController = TextEditingController();

  DateTime _dispatchDate = DateTime.now();
  String _selectedDepartment = 'Dispatch';

  // Material Master auto-filled fields
  String _materialCode = '';
  String _productName = '';
  String _category = '';
  String _grade = '';
  String _selectedUnit = 'kg';
  String _hsnSac = '';
  double _reorderLevel = 0.0;

  double _availableStock = 0.0;
  bool _isLoadingStock = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingDispatch != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingDispatch != null) {
      final d = widget.existingDispatch!;
      _materialCode = d.materialCode;
      _productName = d.product;
      _selectedUnit = d.units;
      _selectedDepartment = d.department.isNotEmpty ? d.department : 'Dispatch';
      _locationController.text = d.location;
      _quantityController.text = d.quantity.toStringAsFixed(3);
      _dispatchDate = d.date;
      _fetchAvailableStock(d.materialCode, d.product);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableStock(String code, String desc) async {
    setState(() {
      _isLoadingStock = true;
      _availableStock = 0.0;
    });

    try {
      final batchesRepo = ref.read(batchesRepositoryProvider);
      final activeBatches = await batchesRepo.fetchActiveBatches();
      
      // Match by materialCode or description
      double total = 0.0;
      for (final b in activeBatches) {
        final matchesCode = b.materialCode.trim().toUpperCase() == code.trim().toUpperCase();
        final matchesDesc = desc.isNotEmpty && b.description.trim().toUpperCase() == desc.trim().toUpperCase();
        if (matchesCode || matchesDesc) {
          total += b.availableQuantity;
        }
      }

      // Also check materials table quantity as fallback
      if (total <= 0.0001) {
        final matRepo = ref.read(materialsRepositoryProvider);
        final mat = await matRepo.getMaterialByCode(code);
        if (mat != null) {
          total = mat.quantity;
        }
      }

      if (mounted) {
        setState(() {
          _availableStock = total;
          _isLoadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStock = false);
      }
    }
  }

  Future<void> _submitDispatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_materialCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material by Code or Description')),
      );
      return;
    }

    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      return;
    }

    if (qty > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient stock! Requested: $qty $_selectedUnit, Available: $_availableStock $_selectedUnit'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(dispatchesRepositoryProvider);
      if (_isEditMode) {
        await repo.updateDispatch(
          dispatchId: widget.existingDispatch!.id,
          materialCode: TextStandardizer.normalizeCode(_materialCode),
          product: TextStandardizer.normalizeBusinessText(_productName.isNotEmpty ? _productName : _materialCode),
          quantity: qty,
          units: _selectedUnit,
          location: TextStandardizer.normalizeBusinessText(_locationController.text),
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          date: _dispatchDate,
        );
      } else {
        await repo.createDispatchFifo(
          materialCode: TextStandardizer.normalizeCode(_materialCode),
          product: TextStandardizer.normalizeBusinessText(_productName.isNotEmpty ? _productName : _materialCode),
          quantity: qty,
          units: TextStandardizer.normalizeBusinessText(_selectedUnit),
          location: TextStandardizer.normalizeBusinessText(_locationController.text),
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          date: _dispatchDate,
        );
      }

      ref.invalidate(dispatchesListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Dispatch #${widget.existingDispatch!.id} updated and FIFO batches re-allocated!'
                : 'Dispatched $qty $_selectedUnit using automated FIFO batch consumption!'),
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
            content: Text('Dispatch failed: $e'),
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
        title: Text(_isEditMode ? 'Edit Dispatch #${widget.existingDispatch!.id}' : 'Record FIFO Dispatch'),
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
                  accentColor: AppColors.secondary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  'Automated FIFO Allocation',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const Text(
                                  'Oldest active batches will be consumed first according to First-In, First-Out inventory logic.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // 1. Live Material Search (Code or Description)
                      MaterialSearchWidget(
                        labelText: 'Search Material — Code or Description *',
                        onSelected: (sel) {
                          setState(() {
                            _materialCode = sel.code;
                            _productName = sel.description;
                            _category = sel.category;
                            _grade = sel.grade;
                            _selectedUnit = sel.unit.isNotEmpty ? sel.unit : 'kg';
                            _hsnSac = sel.hsnSac;
                            _reorderLevel = sel.reorderLevel;
                          });
                          _fetchAvailableStock(sel.code, sel.description);
                        },
                      ),

                      // 2. Auto-filled Master Info Display
                      if (_materialCode.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _materialCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _productName,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (_category.isNotEmpty)
                                    _infoBadge(_category, AppColors.accent),
                                  if (_grade.isNotEmpty && _grade != 'STANDARD')
                                    _infoBadge('Grade: $_grade', AppColors.warning),
                                  if (_hsnSac.isNotEmpty)
                                    _infoBadge('HSN: $_hsnSac', AppColors.textSecondary),
                                  _infoBadge('UOM: $_selectedUnit', AppColors.primaryLight),
                                  if (_reorderLevel > 0)
                                    _infoBadge('Reorder: $_reorderLevel', AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Live Stock Availability Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _availableStock > 0
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _availableStock > 0
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : AppColors.danger.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _availableStock > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: _availableStock > 0 ? AppColors.success : AppColors.danger,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _isLoadingStock
                                          ? const Text('Checking batch storage stock...', style: TextStyle(fontSize: 12))
                                          : Text(
                                              'Available in Storage: $_availableStock $_selectedUnit',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _availableStock > 0 ? AppColors.success : AppColors.danger,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 3. Dispatch Quantity & Unit
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              decoration: InputDecoration(
                                labelText: 'Dispatch Quantity *',
                                suffixText: _selectedUnit,
                                prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter quantity';
                                final d = double.tryParse(val);
                                if (d == null || d <= 0) return 'Invalid quantity';
                                if (d > _availableStock) return 'Exceeds stock ($_availableStock)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
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
                      const SizedBox(height: 14),

                      // 4. Department and Destination Location
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              dropdownColor: AppColors.surface,
                              decoration: const InputDecoration(labelText: 'Department'),
                              items: const [
                                DropdownMenuItem(value: 'Dispatch', child: Text('Dispatch')),
                                DropdownMenuItem(value: 'Tea', child: Text('Tea')),
                                DropdownMenuItem(value: 'Chocolate', child: Text('Chocolate')),
                                DropdownMenuItem(value: 'Kitchen', child: Text('Kitchen')),
                                DropdownMenuItem(value: 'General', child: Text('General')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDepartment = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StandardizedTextField(
                              controller: _locationController,
                              labelText: 'Destination / Customer',
                              hintText: 'e.g. RETAIL STORE OOTY',
                              referenceCandidates: ref.watch(dynamicLocationsProvider).asData?.value ?? const [],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Dispatch Date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dispatchDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _dispatchDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Dispatch Date'),
                          child: Text(
                            QuantityFormatter.formatDate(_dispatchDate),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  text: _isEditMode ? 'Update Dispatch (FIFO Re-allocation)' : 'Execute FIFO Dispatch',
                  height: 52,
                  isLoading: _isSaving,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  onPressed: _submitDispatch,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
