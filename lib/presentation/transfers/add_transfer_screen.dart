import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/material_lot_model.dart';
import '../../data/models/material_model.dart';
import '../../data/models/transfer_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';

class AddTransferScreen extends ConsumerStatefulWidget {
  final TransferModel? existingTransfer;
  const AddTransferScreen({super.key, this.existingTransfer});

  @override
  ConsumerState<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends ConsumerState<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _outwardController = TextEditingController(text: '0.000');
  final _returnController = TextEditingController(text: '0.000');
  final _personController = TextEditingController();

  // Selected Material Master info (Raw Materials Only from Inward Purchases)
  String _selectedCode = '';
  String _selectedDescription = '';
  String _selectedUnit = 'kg';

  // Lots for selected material (FIFO order)
  List<MaterialLotModel> _availableLots = [];
  MaterialLotModel? _selectedLot;
  bool _isLoadingLots = false;

  String _selectedDepartment = 'Tea';
  bool _isSaving = false;

  bool get _isEditMode => widget.existingTransfer != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingTransfer != null) {
      final t = widget.existingTransfer!;
      _selectedCode = t.code;
      _selectedDescription = t.description;
      _selectedUnit = t.units;
      _selectedDepartment = t.department.isNotEmpty ? t.department : 'Tea';
      _personController.text = t.person;
      _outwardController.text = t.outward.toStringAsFixed(3);
      _returnController.text = t.returnUnits.toStringAsFixed(3);
      _fetchLotsForCode(t.code);
    }
  }

  @override
  void dispose() {
    _outwardController.dispose();
    _returnController.dispose();
    _personController.dispose();
    super.dispose();
  }

  double get _outward => double.tryParse(_outwardController.text) ?? 0.0;
  double get _returnUnits => double.tryParse(_returnController.text) ?? 0.0;
  double get _netChange => _returnUnits - _outward;
  double get _newQuantity => _totalAvailableStock + _netChange;

  double get _totalAvailableStock =>
      _availableLots.fold(0.0, (sum, lot) => sum + lot.availableQuantity);

  Future<void> _fetchLotsForCode(String code) async {
    setState(() {
      _isLoadingLots = true;
      _availableLots = [];
      _selectedLot = null;
    });

    try {
      final repo = ref.read(transfersRepositoryProvider);
      final lots = await repo.fetchLotsForMaterial(code);
      if (mounted) {
        setState(() {
          _availableLots = lots;
          // Auto-select oldest available lot (FIFO)
          if (lots.isNotEmpty) {
            _selectedLot = lots.first;
          }
          _isLoadingLots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLots = false);
    }
  }

  void _onMaterialSelected(MaterialModel mat) {
    setState(() {
      _selectedCode = mat.materialCode;
      _selectedDescription = mat.description;
      _selectedUnit = mat.unit.isNotEmpty ? mat.unit : 'kg';
    });
    _fetchLotsForCode(mat.materialCode);
  }

  void _addQuickOutward(double amount) {
    final curr = double.tryParse(_outwardController.text) ?? 0.0;
    _outwardController.text = (curr + amount).toStringAsFixed(3);
    setState(() {});
  }

  /// Calculates FIFO allocation across lots for the requested outward quantity
  List<Map<String, dynamic>> _calculateLotAllocations(double requestedQty) {
    final allocations = <Map<String, dynamic>>[];
    double needed = requestedQty;

    // Start with selected lot if chosen, then follow FIFO
    final orderedLots = <MaterialLotModel>[];
    if (_selectedLot != null) {
      orderedLots.add(_selectedLot!);
      for (final lot in _availableLots) {
        if (lot.id != _selectedLot!.id) orderedLots.add(lot);
      }
    } else {
      orderedLots.addAll(_availableLots);
    }

    for (final lot in orderedLots) {
      if (needed <= 0) break;
      final take = lot.availableQuantity < needed ? lot.availableQuantity : needed;
      if (take > 0) {
        allocations.add({
          'lot_no': lot.lotNo,
          'lot_id': lot.id,
          'quantity': take,
          'available': lot.availableQuantity,
        });
        needed -= take;
      }
    }

    return allocations;
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a raw material for transfer')),
      );
      return;
    }

    if (_outward == 0 && _returnUnits == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter either an Outward Quantity or Return Quantity.')),
      );
      return;
    }

    if (_outward < 0 || _returnUnits < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantities cannot be negative.')),
      );
      return;
    }

    // Tea account category validation (Requirement 5)
    final isTeaUser = ref.read(isTeaUserProvider);
    if (isTeaUser) {
      final availableTeaMaterials = ref.read(transferMaterialsProvider).valueOrNull ?? [];
      final isAllowedTea = availableTeaMaterials.any(
        (m) => m.materialCode.toUpperCase() == _selectedCode.toUpperCase() && m.category.toUpperCase() == 'TEA',
      );
      if (!isAllowedTea && availableTeaMaterials.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access Denied: Material "$_selectedCode" does not belong to the authorized TEA category.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Check total available stock across all lots
    final totalAvail = _totalAvailableStock;
    if (_outward > totalAvail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient stock.\n\nAvailable: ${QuantityFormatter.formatClean(totalAvail)} $_selectedUnit\nRequested Outward: ${QuantityFormatter.formatClean(_outward)} $_selectedUnit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_newQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid transfer: resulting final stock would be negative (${_newQuantity.toStringAsFixed(3)} $_selectedUnit).'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Transfer quantity exceeds current lot
    final primaryLot = _selectedLot ?? (_availableLots.isNotEmpty ? _availableLots.first : null);
    if (_outward > 0 && primaryLot != null && _outward > primaryLot.availableQuantity) {
      final allocations = _calculateLotAllocations(_outward);
      if (allocations.length > 1) {
        final confirmed = await _showMultiLotConfirmationDialog(primaryLot, allocations);
        if (!confirmed) return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(transfersRepositoryProvider);

      if (_isEditMode) {
        await repo.updateTransfer(
          transferId: widget.existingTransfer!.id,
          code: TextStandardizer.normalizeCode(_selectedCode),
          lotNo: _selectedLot?.lotNo ?? widget.existingTransfer!.lotNo,
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          person: TextStandardizer.normalizeBusinessText(_personController.text),
          outward: _outward,
          returnUnits: _returnUnits,
          units: _selectedUnit,
        );
      } else {
        await repo.createTransfer(
          code: TextStandardizer.normalizeCode(_selectedCode),
          lotNo: _selectedLot?.lotNo,
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          person: TextStandardizer.normalizeBusinessText(_personController.text),
          outward: _outward,
          returnUnits: _returnUnits,
          units: TextStandardizer.normalizeBusinessText(_selectedUnit),
        );
      }

      ref.invalidate(transfersListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(transferMaterialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Transfer #${widget.existingTransfer!.id} updated and lot allocations adjusted!'
                : 'Transfer recorded for $_selectedCode — $_selectedDescription!'),
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
            content: Text('Transfer failed: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showMultiLotConfirmationDialog(
      MaterialLotModel primaryLot, List<Map<String, dynamic>> allocations) async {
    final nextAllocations = allocations.sublist(1);
    final remainingTaken = nextAllocations.fold<double>(0.0, (sum, a) => sum + (a['quantity'] as double));
    final nextLotNames = nextAllocations.map((a) => '${a['lot_no']} (${QuantityFormatter.formatClean(a['quantity'])} $_selectedUnit)').join(', ');

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 24),
                  const SizedBox(width: 10),
                  const Text('Multi-Lot Transfer Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${primaryLot.lotNo} has only ${QuantityFormatter.formatClean(primaryLot.availableQuantity)} $_selectedUnit available.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You requested ${QuantityFormatter.formatClean(_outward)} $_selectedUnit.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The remaining ${QuantityFormatter.formatClean(remainingTaken)} $_selectedUnit will be taken from $nextLotNames via FIFO.',
                    style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.glassBorder),
                  const SizedBox(height: 4),
                  Text(
                    'Allocations:\n${allocations.map((a) => '• ${a['lot_no']}: ${QuantityFormatter.formatClean(a['quantity'])} $_selectedUnit').join('\n')}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Continue with transfer?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final transferMaterialsAsync = ref.watch(transferMaterialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transfer #${widget.existingTransfer!.id}' : 'Record Department Transfer'),
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
                  accentColor: AppColors.accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transfer Details',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          // Automatic system timestamp indicator (no manual date)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.primaryLight),
                                const SizedBox(width: 4),
                                Text(
                                  AppDateFormatter.formatWithTime(DateTime.now()),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Material Selection (Raw Materials with Active Lots Only) ──
                      transferMaterialsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (err, _) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Error loading raw material stock: $err', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                        ),
                        data: (rawMaterials) {
                          if (rawMaterials.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, color: AppColors.warning, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'No raw materials with available lot stock found in inward inventory. Add purchase invoices first.',
                                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            value: _selectedCode.isNotEmpty ? _selectedCode : null,
                            dropdownColor: const Color(0xFF0F172A),
                            decoration: const InputDecoration(
                              labelText: 'Select Raw Material *',
                              prefixIcon: Icon(Icons.category_outlined, size: 18),
                              hintText: 'Choose from inward purchase inventory',
                            ),
                            items: rawMaterials.map((m) {
                              return DropdownMenuItem<String>(
                                value: m.materialCode,
                                child: Text(
                                  '${m.materialCode} — ${m.description} (${QuantityFormatter.formatClean(m.quantity)} ${m.unit})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final selected = rawMaterials.firstWhere((m) => m.materialCode == val);
                                _onMaterialSelected(selected);
                              }
                            },
                          );
                        },
                      ),

                      // ── Auto-filled master & lot information ─────────────────────────────
                      if (_selectedCode.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedDescription,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Total available stock across all lots
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _totalAvailableStock > 0
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _totalAvailableStock > 0
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : AppColors.danger.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _totalAvailableStock > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: _totalAvailableStock > 0 ? AppColors.success : AppColors.danger,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _isLoadingLots
                                          ? const Text('Loading active lots...', style: TextStyle(fontSize: 12))
                                          : Text(
                                              'Total Available: ${QuantityFormatter.formatClean(_totalAvailableStock)} $_selectedUnit across ${_availableLots.length} lot(s)',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _totalAvailableStock > 0 ? AppColors.success : AppColors.danger,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Lot Selection (Auto-filled FIFO, selectable) ────────
                        if (_availableLots.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: DropdownButtonFormField<int>(
                                  value: _selectedLot?.id,
                                  dropdownColor: const Color(0xFF0F172A),
                                  decoration: const InputDecoration(
                                    labelText: 'Primary Lot (FIFO Auto-Selected)',
                                    prefixIcon: Icon(Icons.qr_code_2_rounded, size: 18),
                                  ),
                                  items: _availableLots.map((lot) {
                                    return DropdownMenuItem<int>(
                                      value: lot.id,
                                      child: Text(
                                        '${lot.lotNo} — ${QuantityFormatter.formatClean(lot.availableQuantity)} ${lot.uom}',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedLot = _availableLots.firstWhere((l) => l.id == val);
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Avail in Lot',
                                    isDense: true,
                                  ),
                                  child: Text(
                                    '${QuantityFormatter.formatClean(_selectedLot?.availableQuantity ?? 0)} $_selectedUnit',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),

                      // ── Department ──────────────────────────────────────────
                      DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        dropdownColor: const Color(0xFF0F172A),
                        decoration: const InputDecoration(
                          labelText: 'Transfer To Department *',
                          prefixIcon: Icon(Icons.business_rounded, size: 18),
                        ),
                        items: FactoryConstants.departments
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDepartment = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Person ──────────────────────────────────────────────
                      StandardizedTextField(
                        controller: _personController,
                        labelText: 'Receiving Person *',
                        hintText: 'e.g. RAMESH',
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Outward Quantity ────────────────────────────────────
                      TextFormField(
                        controller: _outwardController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
                        decoration: InputDecoration(
                          labelText: 'Outward Quantity ($_selectedUnit)',
                          prefixIcon: const Icon(Icons.arrow_upward_rounded, color: AppColors.danger, size: 18),
                          suffixText: _selectedUnit,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          final v = double.tryParse(val ?? '') ?? 0.0;
                          if (v < 0) return 'Cannot be negative';
                          if (v > _totalAvailableStock) {
                            return 'Exceeds available stock (${QuantityFormatter.formatClean(_totalAvailableStock)} $_selectedUnit)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Quick preset buttons for outward
                      Wrap(
                        spacing: 8,
                        children: [
                          _quickChip('+10', () => _addQuickOutward(10)),
                          _quickChip('+25', () => _addQuickOutward(25)),
                          _quickChip('+50', () => _addQuickOutward(50)),
                          _quickChip('+100', () => _addQuickOutward(100)),
                          if (_selectedLot != null)
                            ActionChip(
                              label: Text('Fill Lot (${QuantityFormatter.formatClean(_selectedLot!.availableQuantity)})'),
                              backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                              labelStyle: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                              onPressed: () {
                                _outwardController.text = _selectedLot!.availableQuantity.toStringAsFixed(3);
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Return Quantity ─────────────────────────────────────
                      TextFormField(
                        controller: _returnController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                        decoration: InputDecoration(
                          labelText: 'Return Quantity ($_selectedUnit)',
                          prefixIcon: const Icon(Icons.keyboard_return_rounded, color: AppColors.success, size: 18),
                          suffixText: _selectedUnit,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          final v = double.tryParse(val ?? '') ?? 0.0;
                          if (v < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Quick preset buttons for return
                      Wrap(
                        spacing: 8,
                        children: [
                          _quickChip('Clear Return', () {
                            _returnController.text = '0.000';
                            setState(() {});
                          }),
                          _quickChip('+5 Return', () {
                            final curr = double.tryParse(_returnController.text) ?? 0.0;
                            _returnController.text = (curr + 5).toStringAsFixed(3);
                            setState(() {});
                          }),
                          _quickChip('+10 Return', () {
                            final curr = double.tryParse(_returnController.text) ?? 0.0;
                            _returnController.text = (curr + 10).toStringAsFixed(3);
                            setState(() {});
                          }),
                          _quickChip('+20 Return', () {
                            final curr = double.tryParse(_returnController.text) ?? 0.0;
                            _returnController.text = (curr + 20).toStringAsFixed(3);
                            setState(() {});
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Live Calculation & Impact Summary Card ───────────────
                      if (_selectedCode.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x33020617),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Stock Calculation Summary',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _netChange >= 0
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : AppColors.danger.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Net Change: ${_netChange >= 0 ? "+" : ""}${QuantityFormatter.formatClean(_netChange)} $_selectedUnit',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _netChange >= 0 ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              _calcRow('Current Available Quantity', '${QuantityFormatter.formatClean(_totalAvailableStock)} $_selectedUnit'),
                              _calcRow('Outward Quantity', '- ${QuantityFormatter.formatClean(_outward)} $_selectedUnit', color: AppColors.danger),
                              _calcRow('Return Quantity', '+ ${QuantityFormatter.formatClean(_returnUnits)} $_selectedUnit', color: AppColors.success),
                              const Divider(height: 12),
                              _calcRow(
                                'New Calculated Stock',
                                '${QuantityFormatter.formatClean(_newQuantity)} $_selectedUnit',
                                isBold: true,
                                color: _newQuantity >= 0 ? AppColors.primaryLight : AppColors.danger,
                              ),
                              if (_selectedLot != null && _outward > _selectedLot!.availableQuantity) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bolt_rounded, size: 14, color: AppColors.warning),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Outward exceeds ${_selectedLot!.lotNo}. Multi-lot FIFO allocation will take remaining stock from next lots.',
                                          style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  text: _isEditMode ? 'Update Department Transfer' : 'Save Transfer',
                  isLoading: _isSaving,
                  icon: Icons.check_circle_outline,
                  color: AppColors.accent,
                  onPressed: _submitTransfer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surface,
      labelStyle: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
      onPressed: onTap,
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
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
