import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/expiry_helper.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/storage_product_model.dart';
import '../../data/models/chocolate_ocr_ledger_model.dart';
import '../../data/repositories/batches_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/uom_dropdown.dart';
import '../../core/services/pdf_export_service.dart';
import '../providers/app_providers.dart';
import '../providers/inventory_settings_provider.dart';
import '../providers/chocolate_ocr_providers.dart';

/// Unified Storage Management Module
/// Represents Finished Goods / Production Batch Inventory.
/// Provides a unified screen with view filtering:
/// [ In Stock ] [ All History ] [ Out of Stock ]
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  BatchViewMode _currentView = BatchViewMode.inStock;
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeSearch = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showFilters = false;

  bool get _hasActiveFilters => _activeSearch.isNotEmpty || _fromDate != null || _toDate != null;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _activeSearch = _searchCtrl.text.trim();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _activeSearch = '';
      _fromDate = null;
      _toDate = null;
      _showFilters = false;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ADD BATCH DIALOG
  // Auto-generates Batch No = Day of Year
  // Independent Storage Product Master (Product Code + Product Name)
  // Two-way autofill (Code <-> Name)
  Future<void> _showAddBatchDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime? selectedExpiryDate;
    final batchesRepo = ref.read(batchesRepositoryProvider);
    final initialDoy = await batchesRepo.generateBatchNumber(selectedDate);
    final batchNoCtrl = TextEditingController(text: initialDoy);
    final productCodeCtrl = TextEditingController();
    final productNameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final isTea = ref.read(isTeaUserProvider);
    final isChoc = ref.read(isChocolateUserProvider);
    final deptCtrl = TextEditingController(text: isChoc ? 'Chocolate' : (isTea ? 'Tea' : 'Finished Goods'));
    final rackCtrl = TextEditingController();
    final codeFocusNode = FocusNode();
    final nameFocusNode = FocusNode();
    String selectedUom = 'kg';
    String selectedGrade = 'STANDARD';
    final formKey = GlobalKey<FormState>();

    int? selectedOcrId;
    List<ChocolateOcrLedgerModel> confirmedOcrScans = [];
    if (isChoc) {
      try {
        confirmedOcrScans = await ref.read(chocolateOcrRepositoryProvider).fetchLedger();
      } catch (e) {
        debugPrint('Error loading chocolate OCR ledger: $e');
      }
    }

    // Pre-load existing storage products for instant two-way autocomplete
    List<StorageProductModel> existingProducts = [];
    try {
      existingProducts = await ref.read(storageProductsRepositoryProvider).searchStorageProducts(
            null,
            category: isChoc ? 'CHOCOLATE' : (isTea ? 'TEA' : null),
          );
    } catch (e) {
      debugPrint('Error loading storage products: $e');
    }

    // If Chocolate, integrate confirmed OCR scans into available products list
    if (isChoc) {
      for (final scan in confirmedOcrScans) {
        if (!existingProducts.any((p) => p.productName.trim().toLowerCase() == scan.description.trim().toLowerCase())) {
          existingProducts.add(StorageProductModel(
            id: 0,
            productCode: scan.productCode,
            productName: scan.description,
            uom: scan.unit.toLowerCase(),
            grade: 'STANDARD',
            category: 'CHOCOLATE',
            createdAt: scan.confirmedAt,
            updatedAt: scan.confirmedAt,
          ));
        }
      }
    }

    // Default sorting: Alphabetical by product name (Requirement 3)
    existingProducts.sort((a, b) => a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogWidth = (screenWidth - 32).clamp(280.0, 520.0);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void onProductCodeChanged(String val) {
              final trimmed = val.trim().toLowerCase();
              if (trimmed.isEmpty) return;
              final match = existingProducts.where((p) => p.productCode.trim().toLowerCase() == trimmed).firstOrNull;
              if (match != null) {
                if (productNameCtrl.text.trim().toLowerCase() != match.productName.trim().toLowerCase()) {
                  productNameCtrl.text = match.productName;
                }
                if (match.uom.isNotEmpty) {
                  setDialogState(() => selectedUom = match.uom.toLowerCase());
                }
                if (match.grade.isNotEmpty) {
                  setDialogState(() => selectedGrade = match.grade);
                }
              }
            }

            void onProductNameChanged(String val) {
              final trimmed = val.trim().toLowerCase();
              if (trimmed.isEmpty) return;
              final match = existingProducts.where((p) => p.productName.trim().toLowerCase() == trimmed).firstOrNull;
              if (match != null) {
                if (productCodeCtrl.text.trim().toLowerCase() != match.productCode.trim().toLowerCase()) {
                  productCodeCtrl.text = match.productCode;
                }
                if (match.uom.isNotEmpty) {
                  setDialogState(() => selectedUom = match.uom.toLowerCase());
                }
                if (match.grade.isNotEmpty) {
                  setDialogState(() => selectedGrade = match.grade);
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.glassBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: AppColors.primaryLight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isChoc ? 'Add Rack Batch' : 'Add Storage Batch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        Text(
                          isChoc ? 'Finished Goods / Production Rack Inward' : 'Finished Goods / Production Batch Inward',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Confirmed OCR Scan Quick Selector (Requirement 2)
                        if (isChoc && confirmedOcrScans.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.document_scanner_rounded, size: 16, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Auto-Fill from Confirmed OCR Scan',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  value: selectedOcrId,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF0F172A),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    hintText: 'Select confirmed OCR scan...',
                                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: confirmedOcrScans.map((scan) {
                                    return DropdownMenuItem<int>(
                                      value: scan.id,
                                      child: Text(
                                        '${scan.description} — ${scan.displayQuantity} (${scan.formattedDate})',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (ocrId) {
                                    if (ocrId != null) {
                                      final scan = confirmedOcrScans.firstWhere((s) => s.id == ocrId);
                                      setDialogState(() {
                                        selectedOcrId = scan.id;
                                        productNameCtrl.text = scan.description;
                                        productCodeCtrl.text = scan.productCode;
                                        qtyCtrl.text = QuantityFormatter.formatClean(scan.quantity);
                                        selectedUom = scan.unit.toLowerCase();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Inward Date & Time Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Inward Date *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
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
                                        final doy = await batchesRepo.generateBatchNumber(picked);
                                        setDialogState(() {
                                          selectedDate = picked;
                                          batchNoCtrl.text = doy;
                                        });
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
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryLight),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppDateFormatter.format(selectedDate),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Time *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedTime,
                                        builder: (context, child) => Theme(
                                          data: ThemeData.dark().copyWith(
                                            colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF0F172A)),
                                          ),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => selectedTime = picked);
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
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 16, color: AppColors.secondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            AppDateFormatter.formatTime(DateTime(2026, 1, 1, selectedTime.hour, selectedTime.minute)),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Batch Number Field (Auto-generated from Day of Year)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Batch Number *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const Text('(Auto: Day of Year)', style: TextStyle(fontSize: 10, color: AppColors.primaryLight, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: batchNoCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. 51',
                            prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AppColors.primaryLight),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textMuted),
                              tooltip: 'Recalculate Day of Year',
                              onPressed: () async {
                                final doy = await batchesRepo.generateBatchNumber(selectedDate);
                                setDialogState(() {
                                  batchNoCtrl.text = doy;
                                });
                              },
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Batch number required' : null,
                        ),
                        const SizedBox(height: 14),

                        // PRODUCT CODE FIELD (Auto-lookup + Free input for new products, hidden for Chocolate users)
                        if (!isChoc) ...[
                          Text('Product Code *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          RawAutocomplete<StorageProductModel>(
                            textEditingController: productCodeCtrl,
                            focusNode: codeFocusNode,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return existingProducts;
                              }
                              final q = textEditingValue.text.trim().toLowerCase();
                              return existingProducts.where(
                                (p) => p.productCode.toLowerCase().contains(q) || p.productName.toLowerCase().contains(q),
                              );
                            },
                            displayStringForOption: (StorageProductModel option) => option.productCode,
                            onSelected: (StorageProductModel selection) {
                              productCodeCtrl.text = selection.productCode;
                              productNameCtrl.text = selection.productName;
                              if (selection.uom.isNotEmpty) {
                                setDialogState(() => selectedUom = selection.uom.toLowerCase());
                              }
                              if (selection.grade.isNotEmpty) {
                                setDialogState(() => selectedGrade = selection.grade);
                              }
                              if (isChoc && qtyCtrl.text.trim().isEmpty) {
                                final matchingScan = confirmedOcrScans.where((s) => s.description.trim().toLowerCase() == selection.productName.trim().toLowerCase()).firstOrNull;
                                if (matchingScan != null) {
                                  qtyCtrl.text = QuantityFormatter.formatClean(matchingScan.quantity);
                                  setDialogState(() => selectedOcrId = matchingScan.id);
                                }
                              }
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              if (options.isEmpty) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 8,
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.glassBorder),
                                      ),
                                      child: Text('No matching products found', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                    ),
                                  ),
                                );
                              }
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: 180, maxWidth: dialogWidth),
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
                                            subtitle: Text(opt.productName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
                                  hintText: 'e.g. FG-TEA-001 (Type or select)',
                                  prefixIcon: Icon(Icons.qr_code_rounded, size: 18, color: AppColors.primaryLight),
                                ),
                                onChanged: (val) => onProductCodeChanged(val),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Product Code required' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // PRODUCT NAME FIELD (Auto-lookup + Free input for new products)
                        Text('Product Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        RawAutocomplete<StorageProductModel>(
                          textEditingController: productNameCtrl,
                          focusNode: nameFocusNode,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return existingProducts;
                            }
                            final q = textEditingValue.text.trim().toLowerCase();
                            return existingProducts.where(
                              (p) => p.productName.toLowerCase().contains(q) || p.productCode.toLowerCase().contains(q),
                            );
                          },
                          displayStringForOption: (StorageProductModel option) => option.productName,
                          onSelected: (StorageProductModel selection) {
                            productCodeCtrl.text = selection.productCode;
                            productNameCtrl.text = selection.productName;
                            if (selection.uom.isNotEmpty) {
                              setDialogState(() => selectedUom = selection.uom.toLowerCase());
                            }
                            if (selection.grade.isNotEmpty) {
                              setDialogState(() => selectedGrade = selection.grade);
                            }
                            if (isChoc && qtyCtrl.text.trim().isEmpty) {
                              final matchingScan = confirmedOcrScans.where((s) => s.description.trim().toLowerCase() == selection.productName.trim().toLowerCase()).firstOrNull;
                              if (matchingScan != null) {
                                qtyCtrl.text = QuantityFormatter.formatClean(matchingScan.quantity);
                                setDialogState(() => selectedOcrId = matchingScan.id);
                              }
                            }
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            if (options.isEmpty) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.glassBorder),
                                    ),
                                    child: Text('No matching products found', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                  ),
                                ),
                              );
                            }
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8,
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: 180, maxWidth: dialogWidth),
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
                                          subtitle: isChoc
                                              ? null
                                              : Text(opt.productCode, style: const TextStyle(color: AppColors.primaryLight, fontSize: 11)),
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
                                hintText: isChoc ? 'e.g. Dark Chocolate 500g (Type or select)' : 'e.g. Premium Green Tea Box (Type or select)',
                                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryLight),
                              ),
                              onChanged: (val) => onProductNameChanged(val),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Product Name required' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // EXPIRY DATE PICKER (DD/MM/YYYY)
                        Text('Expiry Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF0F172A)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedExpiryDate = picked);
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
                                    const Icon(Icons.event_available_rounded, size: 16, color: AppColors.secondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedExpiryDate != null ? DateFormat('dd/MM/yyyy').format(selectedExpiryDate!) : 'Select Expiry Date (DD/MM/YYYY)',
                                      style: TextStyle(
                                        fontWeight: selectedExpiryDate != null ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                        color: selectedExpiryDate != null ? AppColors.textPrimary : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedExpiryDate != null)
                                  InkWell(
                                    onTap: () => setDialogState(() => selectedExpiryDate = null),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                  )
                                else
                                  const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (!isChoc) ...[
                          // RACK / SHELF LOCATION
                          Text('Rack / Shelf Location', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: rackCtrl,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'e.g. RACK C-1, COLD SHELF B-2',
                              prefixIcon: Icon(Icons.shelves, size: 18, color: Color(0xFFF59E0B)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Department Selection
                          Text('Department / Location', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: FactoryConstants.departments.contains(deptCtrl.text.trim()) ? deptCtrl.text.trim() : null,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                              hintText: 'Select Department',
                            ),
                            items: [
                              const DropdownMenuItem(value: 'Finished Goods', child: Text('Finished Goods')),
                              ...FactoryConstants.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => deptCtrl.text = val);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // UOM & Quantity Received Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Quantity Received *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: qtyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                                      suffixText: selectedUom,
                                    ),
                                    validator: (v) {
                                      final val = double.tryParse(v ?? '');
                                      if (val == null || val <= 0) return 'Enter quantity > 0';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('UOM', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  UomDropdown(
                                    value: selectedUom,
                                    labelText: null,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => selectedUom = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    codeFocusNode.dispose();
                    nameFocusNode.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(isChoc ? 'Add to Rack' : 'Add Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final name = productNameCtrl.text.trim();
                    if (name.isEmpty) return;

                    String code = productCodeCtrl.text.trim();
                    if (code.isEmpty) {
                      final cleanName = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
                      code = isChoc ? 'TRAY-${cleanName.isEmpty ? 'ITEM' : cleanName}' : (cleanName.isEmpty ? 'ITEM' : cleanName);
                    }

                    final qty = double.parse(qtyCtrl.text.trim());
                    final scaffold = ScaffoldMessenger.of(context);
                    codeFocusNode.dispose();
                    nameFocusNode.dispose();
                    Navigator.pop(ctx);

                    try {
                      final fullDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                        DateTime.now().second,
                      );

                      final newBatch = BatchModel(
                        id: 0,
                        batchNo: batchNoCtrl.text.trim(),
                        batchDate: selectedDate,
                        materialCode: code,
                        description: name,
                        category: isChoc ? 'CHOCOLATE' : (isTea ? 'TEA' : 'Finished Goods'),
                        grade: selectedGrade,
                        department: deptCtrl.text.trim(),
                        uom: selectedUom,
                        rackLocation: rackCtrl.text.trim().isNotEmpty ? rackCtrl.text.trim().toUpperCase() : null,
                        receivedQuantity: qty,
                        availableQuantity: qty, // Initial == Available at creation
                        expiryDate: selectedExpiryDate,
                        receivedDate: selectedDate,
                        receivedAt: fullDateTime,
                        ocrLedgerId: selectedOcrId,
                        createdAt: fullDateTime,
                      );

                      await ref.read(batchesRepositoryProvider).createBatch(newBatch);
                      ref.invalidate(batchesListProvider);
                      ref.invalidate(activeBatchesProvider);
                      ref.invalidate(inwardHistoryProvider);
                      ref.invalidate(dashboardSummaryProvider);
                      ref.invalidate(storageProductsListProvider);
                      ref.invalidate(dispatchAvailableProductsProvider);

                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('${isChoc ? "Rack batch" : "Batch"} ${newBatch.batchNo} created successfully! Available: ${QuantityFormatter.formatDualUnit(qty, selectedUom)}'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('Failed to create batch: $e'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // EDIT BATCH DIALOG
  // Enforces Requirement 14: User cannot reduce original received quantity below
  // the amount already consumed/dispatched.
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _showEditBatchDialog(BatchModel b) async {
    final batchNoCtrl = TextEditingController(text: b.batchNo);
    final descCtrl = TextEditingController(text: b.description);
    final deptCtrl = TextEditingController(text: b.department);
    final rackCtrl = TextEditingController(text: b.rackLocation ?? '');
    final recvCtrl = TextEditingController(text: b.receivedQuantity.toString());
    String selectedUom = b.uom;
    DateTime? editExpiryDate = b.expiryDate;
    final double alreadyConsumed = b.consumedQuantity;
    double computedAvailable = b.availableQuantity;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.glassBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Batch ${b.batchNo}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                        Text(b.description.isNotEmpty ? b.description : b.materialCode, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Batch Details Strip
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            children: [
                              if (!ref.read(isChocolateUserProvider))
                                _infoRow('Product Code', b.materialCode.isNotEmpty ? b.materialCode : '-'),
                              _infoRow('Date Inward', AppDateFormatter.format(b.receivedDate)),
                              _infoRow(ref.read(isChocolateUserProvider) ? 'Already Consigned' : 'Already Dispatched', '${QuantityFormatter.formatDualUnit(alreadyConsumed, b.uom)} (Locked)'),
                              _infoRow('Current Stock Available', QuantityFormatter.formatDualUnit(computedAvailable, b.uom)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Batch Number
                        TextFormField(
                          controller: batchNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Batch Number *',
                            prefixIcon: Icon(Icons.tag_rounded, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Batch number required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Product / Description',
                            prefixIcon: Icon(Icons.description_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Expiry Date Picker (DD/MM/YYYY)
                        Text('Expiry Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: editExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: AppColors.secondary, surface: Color(0xFF0F172A)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => editExpiryDate = picked);
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
                                    const Icon(Icons.event_available_rounded, size: 16, color: AppColors.secondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      editExpiryDate != null ? DateFormat('dd/MM/yyyy').format(editExpiryDate!) : 'No Expiry Set (DD/MM/YYYY)',
                                      style: TextStyle(
                                        fontWeight: editExpiryDate != null ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                        color: editExpiryDate != null ? AppColors.textPrimary : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (editExpiryDate != null)
                                  InkWell(
                                    onTap: () => setDialogState(() => editExpiryDate = null),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                  )
                                else
                                  const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (!ref.read(isChocolateUserProvider)) ...[
                          // Department
                          TextFormField(
                            controller: deptCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Rack / Shelf Location
                          TextFormField(
                            controller: rackCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Rack / Shelf Location',
                              prefixIcon: Icon(Icons.shelves, size: 18, color: Color(0xFFF59E0B)),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // UOM
                        UomDropdown(
                          value: selectedUom,
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedUom = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Received Quantity Input with Validation against Consumed
                        TextFormField(
                          controller: recvCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Original Received Quantity ($selectedUom) *',
                            prefixIcon: const Icon(Icons.input_rounded, size: 18),
                            helperText: alreadyConsumed > 0 ? 'Minimum allowed: ${alreadyConsumed.toStringAsFixed(2)} $selectedUom (already dispatched)' : null,
                            helperStyle: const TextStyle(fontSize: 10, color: AppColors.warning),
                          ),
                          onChanged: (val) {
                            final newRecv = double.tryParse(val.trim());
                            if (newRecv != null) {
                              setDialogState(() {
                                computedAvailable = (newRecv - alreadyConsumed).clamp(0.0, double.infinity);
                              });
                            }
                          },
                          validator: (v) {
                            final val = double.tryParse(v ?? '');
                            if (val == null || val < 0) return 'Enter a valid positive quantity';
                            if (val < alreadyConsumed - 0.0001) {
                              return 'Cannot reduce below dispatched qty (${alreadyConsumed.toStringAsFixed(2)} $selectedUom)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final scaffold = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);

                    final newRecv = double.parse(recvCtrl.text.trim());
                    final newAvail = (newRecv - alreadyConsumed).clamp(0.0, double.infinity);

                    try {
                      await ref.read(batchesRepositoryProvider).updateBatchStock(
                            batchId: b.id,
                            batchNo: batchNoCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            department: deptCtrl.text.trim(),
                            uom: selectedUom,
                            newReceived: newRecv,
                            newAvailable: newAvail,
                          );

                      if (editExpiryDate != b.expiryDate) {
                        try {
                          await SupabaseConfig.client
                              .from('batches')
                              .update({'expiry_date': editExpiryDate?.toIso8601String().split('T')[0]})
                              .eq('id', b.id);
                        } catch (err) {
                          debugPrint('Error updating batch expiry: $err');
                        }
                      }

                      final newRack = rackCtrl.text.trim().isNotEmpty ? rackCtrl.text.trim().toUpperCase() : null;
                      if (newRack != b.rackLocation) {
                        try {
                          await SupabaseConfig.client
                              .from('batches')
                              .update({'rack_location': newRack})
                              .eq('id', b.id);
                        } catch (err) {
                          debugPrint('Error updating batch rack location: $err');
                        }
                      }

                      ref.invalidate(batchesListProvider);
                      ref.invalidate(activeBatchesProvider);
                      ref.invalidate(inwardHistoryProvider);
                      ref.invalidate(dashboardSummaryProvider);
                      ref.invalidate(storageProductsListProvider);
                      ref.invalidate(dispatchAvailableProductsProvider);

                      scaffold.showSnackBar(
                        const SnackBar(
                          content: Text('Batch updated successfully!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('Failed to update batch: $e'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DELETE BATCH ACTION
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _deleteBatch(BatchModel b) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Batch ${b.batchNo}?',
      message: 'Are you sure you want to delete this batch record? Deleting is strictly forbidden if any dispatches have been allocated against this batch.',
      confirmText: 'Yes, Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    try {
      await ref.read(batchesRepositoryProvider).safeDeleteBatch(b.id);
      ref.invalidate(batchesListProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(inwardHistoryProvider);
      ref.invalidate(dashboardSummaryProvider);

      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Batch deleted successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Cannot delete batch: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW BATCH DETAILS MODAL
  // ─────────────────────────────────────────────────────────────────────────────
  void _viewBatchDetails(BatchModel b) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.layers_rounded, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Batch ${b.batchNo} Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Batch No', b.batchNo),
                if (!ref.read(isChocolateUserProvider))
                  _detailRow('Product Code', b.materialCode.isNotEmpty ? b.materialCode : '-'),
                _detailRow('Description', b.description.isNotEmpty ? b.description : b.materialCode),
                if (!ref.read(isChocolateUserProvider)) ...[
                  _detailRow('Department', b.department),
                  if (b.rackLocation != null && b.rackLocation!.isNotEmpty)
                    _detailRow('Rack / Shelf', b.rackLocation!),
                ],
                if (b.category.isNotEmpty) _detailRow('Category', b.category),
                if (b.grade.isNotEmpty && b.grade != 'STANDARD') _detailRow('Grade', b.grade),
                _detailRow('UOM', b.uom),
                _detailRow('Received Qty', QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom)),
                _detailRow(ref.read(isChocolateUserProvider) ? 'Consigned Qty' : 'Dispatched Qty', QuantityFormatter.formatDualUnit(b.consumedQuantity, b.uom)),
                _detailRow('Available Qty', QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom)),
                _detailRow('Status', b.isExpired ? 'EXPIRED' : (b.isDepleted ? 'OUT OF STOCK' : 'ACTIVE')),
                _detailRow('Date', AppDateFormatter.format(b.effectiveDate)),
                _detailRow('Time', AppDateFormatter.formatTime(b.effectiveDateTime)),
                if (b.expiryDate != null) _detailRow('Expiry Date', AppDateFormatter.format(b.expiryDate)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
            ),
            if (_currentView != BatchViewMode.allHistory)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Batch'),
                onPressed: () {
                  Navigator.pop(context);
                  _showEditBatchDialog(b);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  int get _storageThreshold => ref.watch(inventorySettingsProvider).valueOrNull?.storageProductExpiryAlertDays ?? 30;

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);
    final isChoc = ref.watch(isChocolateUserProvider);
    final filter = BatchesFilter(
      viewMode: _currentView,
      search: _activeSearch.isEmpty ? null : _activeSearch,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final batchesAsync = ref.watch(batchesListProvider(filter));
    // Also watch all batches for summary calculations
    final allBatchesAsync = ref.watch(batchesListProvider(const BatchesFilter(viewMode: BatchViewMode.allHistory)));

    return Scaffold(
      body: AmbientBackground(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────────
            // 1. TOP HEADER & CONTROLS STRIP
            // ─────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xE60A0F1D),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Responsive Header & Toolbar Strip
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      // Storage / Tray Title & Subtitle
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: (MediaQuery.of(context).size.width - 48).clamp(200.0, 600.0)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Icon(isChoc ? Icons.shelves : Icons.warehouse_rounded, color: AppColors.primaryLight, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isChoc ? 'Rack' : 'Storage',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    isChoc ? 'Finished Goods & Rack Inventory' : 'Finished Goods & Batch Inventory',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Required Toolbar Buttons: [ Add Storage / Add Rack ] [ All History ] [ Print ] [ Filter ] [ Reset ]
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // [ Add Storage / Add Rack ]
                          ElevatedButton.icon(
                            onPressed: _showAddBatchDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(isChoc ? 'Add Rack' : 'Add Storage', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // [ All History ]
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentView = _currentView == BatchViewMode.allHistory
                                    ? BatchViewMode.inStock
                                    : BatchViewMode.allHistory;
                              });
                            },
                            icon: Icon(
                              _currentView == BatchViewMode.allHistory ? Icons.inventory_rounded : Icons.history_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _currentView == BatchViewMode.allHistory ? 'Current Stock' : 'All History',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _currentView == BatchViewMode.allHistory ? AppColors.secondary : AppColors.textPrimary,
                              side: BorderSide(
                                color: _currentView == BatchViewMode.allHistory ? AppColors.secondary : AppColors.glassBorder,
                              ),
                              backgroundColor: _currentView == BatchViewMode.allHistory ? AppColors.secondary.withValues(alpha: 0.15) : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // [ Print ]
                          OutlinedButton.icon(
                            onPressed: () {
                              batchesAsync.whenData((batches) {
                                final batchesToPrint = _currentView == BatchViewMode.inStock
                                    ? batches.where((b) => b.availableQuantity > 0.0001).toList()
                                    : batches;

                                if (batchesToPrint.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No batches to print for this view/filter'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                final isAllHistory = _currentView == BatchViewMode.allHistory || _currentView == BatchViewMode.depleted;
                                String? dateRange;
                                if (_fromDate != null || _toDate != null) {
                                  dateRange = '${_fromDate != null ? AppDateFormatter.format(_fromDate) : "Start"} - ${_toDate != null ? AppDateFormatter.format(_toDate) : "End"}';
                                }
                                PdfExportService.printStorageBatches(
                                  batchesToPrint,
                                  isAllHistory: isAllHistory,
                                  subtitle: _activeSearch.isNotEmpty ? 'Filter: "$_activeSearch"' : null,
                                  dateFilter: dateRange,
                                );
                              });
                            },
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // [ Filter ]
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                            icon: Icon(
                              _showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                              size: 16,
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                if (_hasActiveFilters) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: (_showFilters || _hasActiveFilters) ? AppColors.primaryLight : AppColors.textSecondary,
                              side: BorderSide(
                                color: (_showFilters || _hasActiveFilters) ? AppColors.primary : AppColors.glassBorder,
                              ),
                              backgroundColor: (_showFilters || _hasActiveFilters) ? AppColors.primary.withValues(alpha: 0.1) : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // [ Reset ]
                          OutlinedButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              side: BorderSide(color: AppColors.glassBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real KPI Summary Strip
                  allBatchesAsync.maybeWhen(
                    data: (allBatches) {
                      final activeCount = allBatches.where((b) => b.isActive).length;
                      final totalAvail = allBatches.where((b) => b.isActive).fold(0.0, (sum, b) => sum + b.availableQuantity);
                      final depletedCount = allBatches.where((b) => b.isDepleted).length;
                      final today = DateTime.now();
                      final todayInward = allBatches.where((b) {
                        if (b.receivedDate == null) return false;
                        return b.receivedDate!.year == today.year &&
                            b.receivedDate!.month == today.month &&
                            b.receivedDate!.day == today.day;
                      }).length;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMetricChip(icon: Icons.layers_outlined, label: 'Active Batches', value: '$activeCount', color: AppColors.primaryLight),
                            const SizedBox(width: 8),
                            _buildMetricChip(icon: Icons.scale_rounded, label: 'Available Stock', value: '${totalAvail.toStringAsFixed(1)} units', color: AppColors.success),
                            const SizedBox(width: 8),
                            _buildMetricChip(icon: Icons.inventory_2_outlined, label: 'Today\'s Inward', value: '$todayInward batches', color: AppColors.secondary),
                            const SizedBox(width: 8),
                            _buildMetricChip(icon: Icons.archive_outlined, label: 'Out of Stock Batches', value: '$depletedCount', color: AppColors.textMuted),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // Expandable Filter Controls: shown if _showFilters or active filters exist
                  if (_showFilters || _hasActiveFilters) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search Input (supports Batch Number, Product/Description, Department)
                          SizedBox(
                            width: isTablet ? 320 : double.infinity,
                            height: 38,
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search Batch / Product / Department...',
                                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: AppColors.textMuted),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _applyFilters();
                                        },
                                      )
                                    : null,
                              ),
                              onSubmitted: (_) => _applyFilters(),
                            ),
                          ),

                          // From Date
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _fromDate != null ? AppColors.primaryLight : AppColors.textSecondary,
                              side: BorderSide(color: _fromDate != null ? AppColors.primary : AppColors.glassBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: Text(
                              _fromDate != null ? AppDateFormatter.format(_fromDate) : 'From Date',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _pickDate(isFrom: true),
                          ),

                          // To Date
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _toDate != null ? AppColors.primaryLight : AppColors.textSecondary,
                              side: BorderSide(color: _toDate != null ? AppColors.primary : AppColors.glassBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: Text(
                              _toDate != null ? AppDateFormatter.format(_toDate) : 'To Date',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _pickDate(isFrom: false),
                          ),

                          // Apply Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _applyFilters,
                            child: const Text('Apply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),

                          // Clear filter
                          if (_hasActiveFilters)
                            IconButton(
                              tooltip: 'Clear filter',
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                              onPressed: _resetFilters,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // 2. VIEW SELECTOR: [ In Stock ] [ All History ] [ Depleted ]
            // ─────────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildViewTab(mode: BatchViewMode.inStock, title: 'Current Stock', icon: Icons.inventory_rounded),
                    const SizedBox(width: 8),
                    _buildViewTab(mode: BatchViewMode.allHistory, title: 'All History', icon: Icons.history_rounded),
                    const SizedBox(width: 8),
                    _buildViewTab(mode: BatchViewMode.depleted, title: 'Out of Stock', icon: Icons.archive_outlined),
                  ],
                ),
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // 3. TABLE / LIST CONTENT
            // ─────────────────────────────────────────────────────────────
            Expanded(
              child: batchesAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    title: isChoc ? 'Error loading rack batches' : 'Error loading storage batches',
                    message: err.toString(),
                  ),
                ),
                data: (batches) {
                  if (batches.isEmpty) {
                    final emptyTitle = switch (_currentView) {
                      BatchViewMode.inStock => isChoc ? 'No active rack batches found' : 'No active stock batches found',
                      BatchViewMode.allHistory => isChoc ? 'No rack batches registered' : 'No storage batches registered',
                      BatchViewMode.depleted => isChoc ? 'No out of stock rack batches' : 'No out of stock batches',
                    };
                    final emptyMessage = switch (_currentView) {
                      BatchViewMode.inStock => isChoc
                          ? 'All received rack batches are either fully consigned or out of stock. Click "+ Add Rack" to record finished goods.'
                          : 'All received batches are either fully dispatched or out of stock. Click "+ Add Batch" to record finished goods.',
                      BatchViewMode.allHistory => isChoc
                          ? 'Received finished goods rack batches will be logged here.'
                          : 'Received finished goods batches will be logged here.',
                      BatchViewMode.depleted => isChoc
                          ? 'Out of stock rack batches (0 available stock) will appear here for audit history.'
                          : 'Out of stock batches (0 available stock) will appear here for audit history.',
                    };
                    return EmptyStateWidget(
                      icon: isChoc ? Icons.shelves : Icons.layers_outlined,
                      title: emptyTitle,
                      message: emptyMessage,
                    );
                  }

                  return isTablet ? _buildDesktopTable(batches) : _buildMobileCards(batches);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW SELECTOR TAB BUTTON
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildViewTab({
    required BatchViewMode mode,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _currentView == mode;
    return InkWell(
      onTap: () {
        if (_currentView != mode) {
          setState(() => _currentView = mode);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP & TABLET DATA TABLE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopTable(List<BatchModel> batches) {
    final isChoc = ref.watch(isChocolateUserProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0x33020617)),
              horizontalMargin: 16,
              columnSpacing: 18,
              columns: switch (_currentView) {
                BatchViewMode.inStock => [
                    const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    if (!isChoc)
                      const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Stock In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                BatchViewMode.allHistory => [
                    const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    if (!isChoc)
                      const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Stock In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('UOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                BatchViewMode.depleted => [
                    const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    if (!isChoc)
                      const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Stock In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Dispatched Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('UOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
              },
              rows: batches.map((b) {
                final dateStr = AppDateFormatter.format(b.effectiveDate);
                final timeStr = AppDateFormatter.formatTime(b.effectiveDateTime);
                final productStr = b.description.isNotEmpty ? b.description : b.materialCode;
                final expInfo = ExpiryHelper.calculate(
                  expiryDate: b.expiryDate,
                  alertDaysThreshold: _storageThreshold,
                );
                final expiryCell = DataCell(
                  b.expiryDate != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  expInfo.isExpired ? Icons.warning_amber_rounded : Icons.event_available_outlined,
                                  size: 13,
                                  color: expInfo.textColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(b.expiryDate!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: expInfo.hasAlert ? FontWeight.bold : FontWeight.normal,
                                    color: expInfo.textColor,
                                  ),
                                ),
                                if (expInfo.hasAlert) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: expInfo.badgeColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      expInfo.statusLabel,
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: expInfo.textColor),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expInfo.daysLabel,
                              style: TextStyle(fontSize: 9.5, color: expInfo.textColor.withValues(alpha: 0.85)),
                            ),
                          ],
                        )
                      : const Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                );

                return switch (_currentView) {
                  BatchViewMode.inStock => DataRow(
                      cells: [
                        DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(b.batchNo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 12)),
                              ),
                              if (b.rackLocation != null && b.rackLocation!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    b.rackLocation!,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(productStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (!isChoc && b.materialCode.isNotEmpty && b.materialCode != productStr)
                                Text(b.materialCode, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        if (!isChoc)
                          DataCell(Text(b.department, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom), style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Text(
                            QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryLight),
                                tooltip: 'View Details',
                                onPressed: () => _viewBatchDetails(b),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondary),
                                tooltip: 'Edit Batch',
                                onPressed: () => _showEditBatchDialog(b),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                tooltip: 'Delete Batch',
                                onPressed: () => _deleteBatch(b),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  BatchViewMode.allHistory => DataRow(
                      cells: [
                        DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(b.batchNo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 12)),
                          ),
                        ),
                        DataCell(Text(productStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        if (!isChoc)
                          DataCell(Text(b.department, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom), style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Text(
                            QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: b.isDepleted ? AppColors.danger : AppColors.success,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(Text(b.uom, style: const TextStyle(fontSize: 12))),
                        expiryCell,
                        DataCell(
                          NeonPill(
                            label: b.isDepleted ? 'OUT OF STOCK' : 'ACTIVE',
                            color: b.isDepleted ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryLight),
                            tooltip: 'View Details',
                            onPressed: () => _viewBatchDetails(b),
                          ),
                        ),
                      ],
                    ),
                  BatchViewMode.depleted => DataRow(
                      cells: [
                        DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(b.batchNo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 12)),
                          ),
                        ),
                        DataCell(Text(productStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        if (!isChoc)
                          DataCell(Text(b.department, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(QuantityFormatter.formatDualUnit(b.consumedQuantity, b.uom), style: const TextStyle(fontSize: 12, color: AppColors.warning))),
                        DataCell(
                          Text(
                            '0.000 ${b.uom}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                        DataCell(Text(b.uom, style: const TextStyle(fontSize: 12))),
                        expiryCell,
                        DataCell(
                          const NeonPill(label: 'OUT OF STOCK', color: AppColors.danger),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryLight),
                            tooltip: 'View Details',
                            onPressed: () => _viewBatchDetails(b),
                          ),
                        ),
                      ],
                    ),
                };
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE CARDS LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileCards(List<BatchModel> batches) {
    final isChoc = ref.watch(isChocolateUserProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: batches.length,
      itemBuilder: (context, i) {
        final b = batches[i];
        final dateStr = AppDateFormatter.format(b.effectiveDate);
        final timeStr = AppDateFormatter.formatTime(b.effectiveDateTime);
        final productStr = b.description.isNotEmpty ? b.description : b.materialCode;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Batch No & Rack/Tray Location & Department
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (b.isDepleted ? AppColors.danger : AppColors.primary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Batch #${b.batchNo}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: b.isDepleted ? AppColors.danger : AppColors.primaryLight,
                            ),
                          ),
                        ),
                        if (!isChoc && b.rackLocation != null && b.rackLocation!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shelves, size: 12, color: const Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  b.rackLocation!,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (b.ocrLedgerId != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.document_scanner_rounded, size: 10, color: Color(0xFFF59E0B)),
                                SizedBox(width: 3),
                                Text('OCR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isChoc)
                      Text(
                        b.department,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Product Title
                Text(
                  productStr,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (!isChoc && b.materialCode.isNotEmpty && b.materialCode != productStr) ...[
                  const SizedBox(height: 2),
                  Text(b.materialCode, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
                if (b.expiryDate != null) ...[
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final expInfo = ExpiryHelper.calculate(
                      expiryDate: b.expiryDate,
                      alertDaysThreshold: _storageThreshold,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: expInfo.badgeColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: expInfo.textColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                expInfo.isExpired ? Icons.warning_amber_rounded : Icons.timer_outlined,
                                size: 13,
                                color: expInfo.textColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Expiry: ${DateFormat('dd/MM/yyyy').format(b.expiryDate!)}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: expInfo.textColor),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                expInfo.daysLabel,
                                style: TextStyle(fontSize: 10.5, color: expInfo.textColor),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: expInfo.textColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  expInfo.statusLabel,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: expInfo.textColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),

                // Metrics Row: Received vs Dispatched vs Available
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stock In', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (_currentView != BatchViewMode.inStock)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Dispatched', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          Text(
                            QuantityFormatter.formatDualUnit(b.consumedQuantity, b.uom),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Available Stock', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: b.isDepleted ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 16),

                // Bottom row: Date/Time + Status Badge + Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('$dateStr $timeStr', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    NeonPill(
                      label: b.isDepleted ? 'OUT OF STOCK' : 'IN STOCK',
                      color: b.isDepleted ? AppColors.danger : AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Actions buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _viewBatchDetails(b),
                    ),
                    if (_currentView == BatchViewMode.inStock) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showEditBatchDialog(b),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _deleteBatch(b),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
