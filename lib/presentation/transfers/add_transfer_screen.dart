import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/transfer_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/material_search_widget.dart';
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

  // Material master info — auto-filled from search selection
  String _selectedCode = '';
  String _selectedDescription = '';
  String _selectedUnit = 'kg';
  String _selectedCategory = '';
  String _selectedHsn = '';
  double _availableStock = 0.0;
  bool _isLoadingStock = false;

  String _selectedDepartment = 'Tea';
  DateTime _transferDate = DateTime.now();
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
      _transferDate = t.date;
      _fetchAvailableStock(t.code);
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
  double get _returnQty => double.tryParse(_returnController.text) ?? 0.0;
  double get _netChange => _returnQty - _outward;

  void _addQuickOutward(double amountInKg) {
    final curr = double.tryParse(_outwardController.text) ?? 0.0;
    _outwardController.text = (curr + amountInKg).toStringAsFixed(3);
    setState(() {});
  }

  Future<void> _fetchAvailableStock(String code) async {
    setState(() {
      _isLoadingStock = true;
      _availableStock = 0.0;
    });

    try {
      final matRepo = ref.read(materialsRepositoryProvider);
      final mat = await matRepo.getMaterialByCode(code);
      if (mounted) {
        setState(() {
          _availableStock = mat?.quantity ?? 0.0;
          _isLoadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStock = false);
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material')),
      );
      return;
    }

    if (_outward <= 0 && _returnQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an outward or return quantity')),
      );
      return;
    }

    if (_outward > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient stock! Outward: $_outward $_selectedUnit, Available: $_availableStock $_selectedUnit'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(transfersRepositoryProvider);
      if (_isEditMode) {
        await repo.updateTransfer(
          transferId: widget.existingTransfer!.id,
          code: TextStandardizer.normalizeCode(_selectedCode),
          lotNo: widget.existingTransfer!.lotNo,
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          person: TextStandardizer.normalizeBusinessText(_personController.text),
          outward: _outward,
          returnUnits: _returnQty,
          units: _selectedUnit,
          date: _transferDate,
        );
      } else {
        await repo.createTransfer(
          code: TextStandardizer.normalizeCode(_selectedCode),
          lotNo: null,
          department: TextStandardizer.normalizeBusinessText(_selectedDepartment),
          person: TextStandardizer.normalizeBusinessText(_personController.text),
          outward: _outward,
          returnUnits: _returnQty,
          units: TextStandardizer.normalizeBusinessText(_selectedUnit),
          date: _transferDate,
        );
      }

      ref.invalidate(transfersListProvider);
      ref.invalidate(materialsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Transfer updated for $_selectedCode — $_selectedDescription'
                : 'Transfer recorded for $_selectedCode — $_selectedDescription'),
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

  @override
  Widget build(BuildContext context) {
    final departments = const [
      'Tea', 'Chocolate', 'Spices', 'Kitchen', 'Varkey Factory',
      'Packing', 'Storage', 'Admin', 'Other',
    ];

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
                      Text(
                        'Transfer Details',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),

                      // ── Material Search ─────────────────────────────────────
                      MaterialSearchWidget(
                        labelText: 'Search Material — Code or Name *',
                        onSelected: (sel) {
                          setState(() {
                            _selectedCode        = sel.code;
                            _selectedDescription = sel.description;
                            _selectedUnit        = sel.unit.isEmpty ? 'kg' : sel.unit;
                            _selectedCategory    = sel.category;
                            _selectedHsn         = sel.hsnSac;
                          });
                          _fetchAvailableStock(sel.code);
                        },
                      ),

                      // ── Auto-filled master info ─────────────────────────────
                      if (_selectedCode.isNotEmpty) ...[
                        const SizedBox(height: 8),
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
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (_selectedCategory.isNotEmpty)
                                    _infoBadge(_selectedCategory, AppColors.accent),
                                  _infoBadge('UOM: $_selectedUnit', AppColors.textSecondary),
                                  if (_selectedHsn.isNotEmpty)
                                    _infoBadge('HSN: $_selectedHsn', AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Live Available Stock Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                          ? const Text('Checking inventory stock...', style: TextStyle(fontSize: 12))
                                          : Text(
                                              'Available in Stock: $_availableStock $_selectedUnit',
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

                      const SizedBox(height: 16),

                      // ── Department ──────────────────────────────────────────
                      DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Transfer To Department *',
                          prefixIcon: Icon(Icons.business_rounded, size: 18),
                        ),
                        items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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
                      const SizedBox(height: 12),

                      // ── Transfer Date ───────────────────────────────────────
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _transferDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _transferDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Transfer Date'),
                          child: Text(
                            QuantityFormatter.formatDate(_transferDate),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const Divider(height: 24),

                      // ── Outward Quantity ────────────────────────────────────
                      TextFormField(
                        controller: _outwardController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
                        decoration: InputDecoration(
                          labelText: 'Outward Issued Quantity',
                          suffixText: _selectedUnit,
                          prefixIcon: const Icon(Icons.arrow_upward_rounded, color: AppColors.danger, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),

                      // Quick gram buttons for kg/litre materials
                      if (_selectedUnit.toLowerCase() == 'kg' || _selectedUnit.toLowerCase() == 'litre') ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildGramHelperBtn('+100 g', 0.100),
                            _buildGramHelperBtn('+250 g', 0.250),
                            _buildGramHelperBtn('+500 g', 0.500),
                            _buildGramHelperBtn('+1 kg', 1.000),
                            _buildGramHelperBtn('+5 kg', 5.000),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Return Quantity ─────────────────────────────────────
                      TextFormField(
                        controller: _returnController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                        decoration: InputDecoration(
                          labelText: 'Return Quantity Received Back',
                          suffixText: _selectedUnit,
                          prefixIcon: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Divider(height: 24),

                      // ── Net Change Preview ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Stock Change:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              Text(
                                '${_netChange > 0 ? "+" : ""}${QuantityFormatter.format3Decimals(_netChange)} $_selectedUnit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _netChange < 0 ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Material:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              Text(
                                _selectedCode.isEmpty ? '—' : '$_selectedCode · $_selectedUnit',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  text: _isEditMode ? 'Update Department Transfer' : 'Commit Department Transfer',
                  height: 52,
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

  Widget _buildGramHelperBtn(String label, double amount) {
    return InkWell(
      onTap: () => _addQuickOutward(amount),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
        ),
      ),
    );
  }
}
