import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../materials/new_material_dialog.dart';
import '../providers/app_providers.dart';

class WithoutInvoiceScreen extends ConsumerStatefulWidget {
  const WithoutInvoiceScreen({super.key});

  @override
  ConsumerState<WithoutInvoiceScreen> createState() => _WithoutInvoiceScreenState();
}

class _WithoutInvoiceScreenState extends ConsumerState<WithoutInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();

  DateTime _inwardDate = DateTime.now();
  bool _isSaving = false;

  // Selected Material Master record
  MaterialModel? _selectedMaterial;

  // Live search state
  List<MaterialModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastSearchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String get _currentLotNumber => AppDateFormatter.formatDayOfYearLot(_inwardDate);

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
        _lastSearchQuery = '';
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _hasSearched = true;
        _lastSearchQuery = trimmed;
      });

      try {
        final repo = ref.read(materialsRepositoryProvider);
        final results = await repo.searchMaterials(trimmed, limit: 15);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  void _selectMaterial(MaterialModel mat) {
    setState(() {
      _selectedMaterial = mat;
      _searchController.text = '${mat.materialCode} — ${mat.description}';
      _searchResults = [];
      _hasSearched = false;
    });
  }

  void _clearSelectedMaterial() {
    setState(() {
      _selectedMaterial = null;
      _searchController.clear();
      _searchResults = [];
      _hasSearched = false;
      _lastSearchQuery = '';
    });
  }

  Future<void> _openCreateNewMaterial() async {
    final query = _lastSearchQuery;
    final res = await showDialog<dynamic>(
      context: context,
      builder: (_) => NewMaterialDialog(
        initialCode: query.toUpperCase(),
        initialDescription: query,
      ),
    );

    if (res != null && mounted) {
      ref.invalidate(materialsListProvider);
      final codeStr = res is String ? res : res.toString();
      if (codeStr.isNotEmpty) {
        try {
          final repo = ref.read(materialsRepositoryProvider);
          final newMat = await repo.getMaterialByCode(codeStr);
          if (newMat != null && mounted) {
            _selectMaterial(newMat);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Material "${newMat.description}" (${newMat.materialCode}) registered and selected!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (_) {}
      }
    }
  }

  void _addQuickQty(double addAmount) {
    final curr = double.tryParse(_quantityController.text) ?? 0.0;
    _quantityController.text = (curr + addAmount).toStringAsFixed(3);
    setState(() {});
  }

  Future<void> _submit() async {
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an existing material from Material Master.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be greater than zero.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = _inwardDate;
      final rnd = Random().nextInt(9000) + 1000;
      final autoInvoiceNo = 'DIR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$rnd';

      final mat = _selectedMaterial!;
      final lot = _currentLotNumber;

      final invoicePayload = {
        'purchase_id': 'DIRECT-INWARD',
        'date': now.toIso8601String().split('T')[0],
        'invoice_no': autoInvoiceNo,
        'vendor': null,
        'no_of_items': 1,
        'round_off_value': 0.0,
        'payment_status': 'Paid',
        'remarks': 'Direct stock inward (without invoice)',
      };

      final itemsPayload = [
        {
          'material': mat.materialCode,
          'description': mat.description.isNotEmpty ? mat.description : mat.materialCode,
          'category': mat.category.isNotEmpty ? mat.category : 'General',
          'unit': mat.unit.isNotEmpty ? mat.unit : 'kg',
          'quantity': qty,
          'unit_price': mat.unitPrice,
          'discount_percentage': 0.0,
          'gst_percentage': 0.0,
          'igst_percentage': 0.0,
          'lot_no': lot,
          'batch_no': lot,
          'expiry_date': null,
          'hsn_sac': mat.hsnSac,
          'grade': mat.grade,
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
            content: Text('Received $qty ${mat.unit} of ${mat.materialCode} (Lot $lot) into stock!'),
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
        title: const Text('Direct Stock Inward (Without Invoice)'),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header GlassCard explaining the fast inward flow
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
                            'Quick Stock Inward',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct stock receipt without entering a purchase invoice. Select an existing material and enter the quantity.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── SECTION 1: INWARD DATE & LOT NUMBER (DAY-OF-YEAR) ──
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INWARD RECEIPT & LOT IDENTIFIER',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inward Date Selector
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _inwardDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setState(() => _inwardDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Inward Date (DD/MM/YYYY) *',
                                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                                ),
                                child: Text(
                                  AppDateFormatter.format(_inwardDate),
                                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // System-Generated LOT NUMBER (Day of Year)
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'LOT NUMBER',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'AUTO-GENERATED',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.tag_rounded, size: 18, color: AppColors.secondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentLotNumber,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(Day ${AppDateFormatter.getDayOfYear(_inwardDate)})',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── SECTION 2: MATERIAL SELECTION (SEARCH MATERIAL MASTER) ──
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MATERIAL MASTER SELECTION *',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          if (_selectedMaterial != null)
                            TextButton.icon(
                              onPressed: _clearSelectedMaterial,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primaryLight),
                              label: const Text('Change Material', style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_selectedMaterial == null) ...[
                        // Search Input
                        TextFormField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Search Material Code OR Description *',
                            hintText: 'Type Material Code or Name (e.g. 100, TEA, CHOCOLATE)...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchQueryChanged('');
                                        },
                                      )
                                    : null,
                          ),
                          onChanged: _onSearchQueryChanged,
                        ),

                        // Matching materials results dropdown
                        if (_searchResults.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.glassBorder),
                              itemBuilder: (context, index) {
                                final mat = _searchResults[index];
                                return InkWell(
                                  onTap: () => _selectMaterial(mat),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Code pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            mat.materialCode,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryLight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Description & Category
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mat.description,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${mat.category} · UOM: ${mat.unit}${mat.grade.isNotEmpty ? " · Grade: ${mat.grade}" : ""}',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Current Stock badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Stock: ${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}',
                                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        // "Material not found in Material Master" banner with Register button
                        if (_hasSearched && !_isSearching && _searchResults.isEmpty && _searchController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Material not found in Material Master.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      Text(
                                        'Register this material in the Material Master before creating direct inward stock.',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Create in Master', style: TextStyle(fontSize: 12)),
                                  onPressed: _openCreateNewMaterial,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // Selected Material Details Card (Auto-filled from Material Master)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'MATERIAL MASTER LINKED',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Code: ${_selectedMaterial!.materialCode}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedMaterial!.description.isNotEmpty ? _selectedMaterial!.description : _selectedMaterial!.materialCode,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildMasterChip('Category', _selectedMaterial!.category),
                                  _buildMasterChip('UOM', _selectedMaterial!.unit),
                                  if (_selectedMaterial!.grade.isNotEmpty)
                                    _buildMasterChip('Grade', _selectedMaterial!.grade),
                                  if (_selectedMaterial!.hsnSac.isNotEmpty)
                                    _buildMasterChip('HSN/SAC', _selectedMaterial!.hsnSac),
                                  _buildMasterChip(
                                    'Current Stock',
                                    '${_selectedMaterial!.quantity.toStringAsFixed(_selectedMaterial!.quantity % 1 == 0 ? 0 : 2)} ${_selectedMaterial!.unit}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── SECTION 3: QUANTITY INPUT (MINIMUM USER INPUT) ──
                GlassCard(
                  accentColor: _selectedMaterial != null ? AppColors.success : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ENTER QUANTITY *',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          if (_selectedMaterial != null)
                            Text(
                              'UOM: ${_selectedMaterial!.unit}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success),
                        decoration: InputDecoration(
                          labelText: 'Received Quantity *',
                          hintText: '0.000',
                          suffixText: _selectedMaterial?.unit ?? 'kg',
                          suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          prefixIcon: const Icon(Icons.scale_rounded, size: 24),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter quantity';
                          final d = double.tryParse(val);
                          if (d == null || d <= 0) return 'Quantity must be greater than 0';
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Commit Stock Inward Button
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

  Widget _buildMasterChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
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
