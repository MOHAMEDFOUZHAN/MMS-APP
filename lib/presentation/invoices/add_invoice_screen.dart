import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/grade_dropdown.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../../shared/widgets/uom_dropdown.dart';
import '../materials/new_material_dialog.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';
import 'multi_page_scan_screen.dart';

enum MaterialMatchStatus {
  none,
  matched,
  notFound,
  matchRequired,
  multipleCandidates,
}

class _FormItem {
  final TextEditingController codeController;
  final TextEditingController descController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController discountController;
  final TextEditingController gstController;
  final TextEditingController igstController;
  final TextEditingController lotController;
  final TextEditingController categoryController;
  final TextEditingController reorderController;
  final TextEditingController hsnController;

  String unit;
  String grade;
  DateTime? purchaseDate;
  DateTime? expiryDate;

  MaterialMatchStatus matchStatus;
  String? matchedMaterialName;
  List<MaterialModel> candidateMatches;

  Timer? codeDebounce;
  Timer? descDebounce;

  _FormItem({
    String materialCode = '',
    String description = '',
    String unit = 'kg',
    double quantity = 1.0,
    double unitPrice = 0.0,
    double discount = 0.0,
    double gst = 0.0,
    double igst = 0.0,
    String lotNo = '',
    String category = 'General',
    String hsnSac = '',
    this.grade = '',
    double reorderLevel = 0.0,
    this.purchaseDate,
  })  : codeController = TextEditingController(text: materialCode),
        descController = TextEditingController(text: description),
        qtyController = TextEditingController(
            text: quantity > 0
                ? (quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString())
                : '1'),
        priceController = TextEditingController(text: unitPrice > 0 ? unitPrice.toString() : ''),
        discountController = TextEditingController(text: discount > 0 ? discount.toString() : ''),
        gstController = TextEditingController(text: gst > 0 ? gst.toString() : ''),
        igstController = TextEditingController(text: igst > 0 ? igst.toString() : ''),
        lotController = TextEditingController(text: lotNo),
        categoryController = TextEditingController(text: category),
        reorderController = TextEditingController(
            text: reorderLevel > 0
                ? (reorderLevel % 1 == 0 ? reorderLevel.toInt().toString() : reorderLevel.toString())
                : '0'),
        hsnController = TextEditingController(text: hsnSac),
        unit = unit.isNotEmpty ? unit : 'kg',
        matchStatus = MaterialMatchStatus.none,
        candidateMatches = [];

  void dispose() {
    codeDebounce?.cancel();
    descDebounce?.cancel();
    codeController.dispose();
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    gstController.dispose();
    igstController.dispose();
    lotController.dispose();
    categoryController.dispose();
    reorderController.dispose();
    hsnController.dispose();
  }

  String get materialCode => codeController.text.trim();
  String get description => descController.text.trim();
  double get quantity => double.tryParse(qtyController.text) ?? 0.0;
  double get unitPrice => double.tryParse(priceController.text) ?? 0.0;
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get gst => double.tryParse(gstController.text) ?? 0.0;
  double get igst => double.tryParse(igstController.text) ?? 0.0;
  String get lotNo => lotController.text.trim();
  String get category => categoryController.text.trim().isNotEmpty ? categoryController.text.trim() : 'General';
  String get hsnSac => hsnController.text.trim();
  double get reorderLevel => double.tryParse(reorderController.text) ?? 0.0;

  // Decimal-accurate calculations (identical to existing invoice business logic)
  double get gross => double.parse((quantity * unitPrice).toStringAsFixed(2));
  double get discountAmount => double.parse((gross * (discount / 100.0)).toStringAsFixed(2));
  double get taxableAmount => double.parse((gross - discountAmount).toStringAsFixed(2));

  bool get hasIgst => igst > 0;
  double get igstValue => hasIgst ? double.parse((taxableAmount * (igst / 100.0)).toStringAsFixed(2)) : 0.0;
  double get cgstValue => !hasIgst && gst > 0 ? double.parse((taxableAmount * ((gst / 2.0) / 100.0)).toStringAsFixed(2)) : 0.0;
  double get sgstValue => !hasIgst && gst > 0 ? double.parse((taxableAmount * ((gst / 2.0) / 100.0)).toStringAsFixed(2)) : 0.0;
  double get totalGstValue => double.parse((cgstValue + sgstValue).toStringAsFixed(2));

  double get itemTotal => double.parse((taxableAmount + totalGstValue + igstValue).toStringAsFixed(2));

  bool get hasEnteredData =>
      materialCode.isNotEmpty ||
      description.isNotEmpty ||
      quantity > 1.0 ||
      unitPrice > 0.0 ||
      discount > 0.0 ||
      gst > 0.0 ||
      igst > 0.0;

  void applyMaster(MaterialModel m) {
    codeController.text = m.materialCode;
    descController.text = m.description;
    categoryController.text = m.category.isNotEmpty ? m.category : 'General';
    unit = m.unit.isNotEmpty ? m.unit : 'kg';
    if (m.grade.isNotEmpty) grade = m.grade;
    hsnController.text = m.hsnSac;
    reorderController.text =
        m.reorderLevel % 1 == 0 ? m.reorderLevel.toInt().toString() : m.reorderLevel.toString();
    if (m.unitPrice > 0 && (unitPrice <= 0 || priceController.text.isEmpty)) {
      priceController.text = m.unitPrice.toString();
    }
    matchStatus = MaterialMatchStatus.matched;
    matchedMaterialName = m.description;
    candidateMatches = [];
  }

  Map<String, dynamic> toPayload([DateTime? fallbackDate]) {
    final effectiveLot = lotNo.isNotEmpty
        ? lotNo
        : (fallbackDate != null ? AppDateFormatter.formatDayOfYearLot(fallbackDate) : '');
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
      'lot_no': TextStandardizer.normalizeBusinessText(effectiveLot),
      'batch_no': TextStandardizer.normalizeBusinessText(effectiveLot),
      'expiry_date': expiryDate != null ? AppDateFormatter.toDbDate(expiryDate!) : null,
      'hsn_sac': TextStandardizer.normalizeBusinessText(hsnSac),
      'grade': grade.isNotEmpty ? FactoryConstants.normalizeGradeCode(grade) : '',
    };
  }
}

class AddInvoiceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialOcrData;
  final InvoiceModel? existingInvoice;
  final bool isOcrScanMode;

  const AddInvoiceScreen({
    super.key,
    this.initialOcrData,
    this.existingInvoice,
    this.isOcrScanMode = false,
  });

  @override
  ConsumerState<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends ConsumerState<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _invoiceNoController = TextEditingController();
  final _purchaseIdController = TextEditingController(text: 'PUR-01');
  final _vendorController = TextEditingController();
  final _roundOffController = TextEditingController(text: '0.00');
  final _remarksController = TextEditingController();
  final _itemCountController = TextEditingController(text: '1');

  DateTime _invoiceDate = DateTime.now();
  String _paymentStatus = 'Pending';
  bool _isSaving = false;

  // OCR state variables for real-time document extraction and preview
  File? _scannedFile;
  String? _scannedFileName;
  bool _isScanning = false;
  String? _ocrErrorMessage;
  String? _ocrSuccessMessage;
  late bool _isOcrSectionExpanded;

  final List<_FormItem> _items = [];

  bool get _isEditMode => widget.existingInvoice != null;

  /// Generate Day-of-Year lot number (e.g. 05/01/2026 -> 005, 31/12/2026 -> 365)
  static String calculateDayOfYearLot(DateTime date) {
    return AppDateFormatter.formatDayOfYearLot(date);
  }

  @override
  void initState() {
    super.initState();
    _isOcrSectionExpanded = widget.isOcrScanMode;
    _applyInitialData();
  }

  void _applyInitialData() {
    final generatedLot = calculateDayOfYearLot(_invoiceDate);

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
          description: '',
          unit: item.unit,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discount: item.discountPercentage,
          gst: item.gstPercentage,
          igst: item.igstPercentage,
          lotNo: item.lotNo.isNotEmpty
              ? item.lotNo
              : (item.batchNo.isNotEmpty ? item.batchNo : calculateDayOfYearLot(inv.date)),
          category: 'General',
          hsnSac: item.hsnSac,
          grade: item.grade,
          purchaseDate: inv.date,
        );
        _items.add(formItem);
      }
    } else if (widget.initialOcrData != null) {
      final ocr = widget.initialOcrData!;
      _invoiceNoController.text = ocr['invoice_no']?.toString() ?? '';
      _vendorController.text = ocr['vendor']?.toString() ?? '';
      if (ocr['date'] is DateTime) {
        _invoiceDate = ocr['date'] as DateTime;
      } else if (ocr['date'] is String) {
        try {
          _invoiceDate = DateTime.parse(ocr['date'].toString());
        } catch (_) {}
      }
      if (ocr['round_off'] != null) {
        _roundOffController.text =
            (double.tryParse(ocr['round_off'].toString()) ?? 0.0).toStringAsFixed(2);
      }

      final rawItems = ocr['items'] as List<dynamic>?;
      if (rawItems != null && rawItems.isNotEmpty) {
        for (final item in rawItems) {
          final m = item as Map<String, dynamic>;
          final itemLot = m['lot_no']?.toString().trim();
          _items.add(_FormItem(
            materialCode: m['material_code']?.toString() ?? '',
            description: m['description']?.toString() ?? '',
            quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
            unit: m['unit']?.toString() ?? 'kg',
            unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
            discount: (m['discount_percentage'] as num?)?.toDouble() ?? 0.0,
            gst: (m['gst_percentage'] as num?)?.toDouble() ?? 0.0,
            igst: (m['igst_percentage'] as num?)?.toDouble() ?? 0.0,
            lotNo: (itemLot != null && itemLot.isNotEmpty)
                ? itemLot
                : calculateDayOfYearLot(_invoiceDate),
            purchaseDate: _invoiceDate,
            category: m['category']?.toString() ?? 'General',
            hsnSac: m['hsn_sac']?.toString() ?? '',
            grade: m['grade']?.toString() ?? '',
          ));
        }
      }
      _ocrSuccessMessage =
          'Imported ${rawItems?.length ?? 0} items from scanner. All boxes below are populated and fully editable.';
    }

    if (_items.isEmpty) {
      _items.add(_FormItem(lotNo: generatedLot, purchaseDate: _invoiceDate));
    }
    _itemCountController.text = _items.length.toString();

    // Trigger Material Master matching post-frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveInitialMaterials();
    });
  }

  Future<void> _pickImageAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        await _processScannedFile(File(picked.path));
      }
    } catch (e) {
      setState(() {
        _ocrErrorMessage = 'Failed to capture image: $e';
      });
    }
  }

  Future<void> _pickFileAndScan() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        await _processScannedFile(File(result.files.single.path!));
      }
    } catch (e) {
      setState(() {
        _ocrErrorMessage = 'Failed to select file: $e';
      });
    }
  }

  Future<void> _processScannedFile(File file) async {
    setState(() {
      _scannedFile = file;
      _scannedFileName = file.path.split(Platform.pathSeparator).last;
      _isScanning = true;
      _ocrErrorMessage = null;
      _ocrSuccessMessage = null;
    });

    try {
      final ocrResult = await OcrService.parseInvoiceDocument(file);
      if (!mounted) return;

      final hasExistingData =
          _items.any((i) => i.hasEnteredData) || _vendorController.text.trim().isNotEmpty;
      bool shouldReplace = true;

      if (hasExistingData && mounted) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.document_scanner_rounded, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Text('Apply Scanned Invoice',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Extracted ${ocrResult.items.length} items from ${ocrResult.vendor.isNotEmpty ? ocrResult.vendor : "invoice"}.\nHow would you like to apply the scanned data?',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'append'),
                child: const Text('Append to Existing', style: TextStyle(color: AppColors.primaryLight)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: const Text('Replace All', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (choice == null || choice == 'cancel') {
          setState(() => _isScanning = false);
          return;
        }
        shouldReplace = (choice == 'replace');
      }

      setState(() {
        _isScanning = false;

        // Apply vendor and invoice number
        if (shouldReplace || _vendorController.text.trim().isEmpty) {
          if (ocrResult.vendor.isNotEmpty) _vendorController.text = ocrResult.vendor;
        }
        if (shouldReplace || _invoiceNoController.text.trim().isEmpty) {
          if (ocrResult.invoiceNo.isNotEmpty) _invoiceNoController.text = ocrResult.invoiceNo;
        }
        if (shouldReplace) {
          _invoiceDate = ocrResult.date;
          if (ocrResult.roundOff != 0.0) {
            _roundOffController.text = ocrResult.roundOff.toStringAsFixed(2);
          }
        }

        final generatedLot = calculateDayOfYearLot(_invoiceDate);

        if (shouldReplace) {
          for (final item in _items) {
            item.dispose();
          }
          _items.clear();
        }

        if (ocrResult.items.isNotEmpty) {
          for (final item in ocrResult.items) {
            final formItem = _FormItem(
              materialCode: item.materialCode,
              description: item.description,
              unit: item.unit.isNotEmpty ? item.unit : 'kg',
              quantity: item.quantity > 0 ? item.quantity : 1.0,
              unitPrice: item.unitPrice,
              discount: item.discount,
              gst: item.gst,
              igst: (ocrResult.totalIgst > 0 && item.gst == 0) ? 18.0 : 0.0,
              lotNo: item.lotNo.isNotEmpty ? item.lotNo : generatedLot,
              purchaseDate: _invoiceDate,
              category: 'General',
            );
            _items.add(formItem);
          }
        } else if (_items.isEmpty) {
          _items.add(_FormItem(lotNo: generatedLot, purchaseDate: _invoiceDate));
        }

        _itemCountController.text = _items.length.toString();
        _ocrSuccessMessage = ocrResult.items.isNotEmpty
            ? 'Scanned! Extracted ${ocrResult.items.length} items & supplier details. Review and edit any boxes below.'
            : 'Scanned supplier details. Line items could not be parsed; please fill them manually below.';
      });

      // Automatically trigger Material Master linking post-frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveInitialMaterials();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _ocrErrorMessage = 'Failed to process document: $e';
        });
      }
    }
  }

  void _showDocumentPreviewDialog(File file) {
    final ext = file.path.toLowerCase().split('.').last;
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.document_scanner_rounded, color: AppColors.primaryLight, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Original Scanned Bill',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: isImage
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppColors.danger),
                            const SizedBox(height: 12),
                            Text(
                              file.path.split(Platform.pathSeparator).last,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'PDF invoice processed by RapidOCR',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Pinch or drag to zoom and pan. Use this to cross-check boxes on the invoice form.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Automatically matches code or description from Material Master
  Future<void> _resolveInitialMaterials() async {
    final repo = ref.read(materialsRepositoryProvider);
    bool anyUpdated = false;

    for (final item in _items) {
      final code = item.codeController.text.trim();
      final desc = item.descController.text.trim();

      // 1. Try matching by code
      if (code.isNotEmpty) {
        try {
          final match = await repo.getMaterialByCode(code);
          if (match != null) {
            item.applyMaster(match);
            anyUpdated = true;
            continue;
          }
        } catch (_) {}
      }

      // 2. Fallback matching by description
      if (desc.isNotEmpty) {
        try {
          final exact = await repo.getMaterialByExactDescription(desc);
          if (exact != null) {
            item.applyMaster(exact);
            anyUpdated = true;
            continue;
          }

          final candidates = await repo.searchMaterials(desc, limit: 10);
          final exactDescMatches = candidates
              .where((m) => m.description.trim().toLowerCase() == desc.toLowerCase())
              .toList();

          if (exactDescMatches.length == 1) {
            item.applyMaster(exactDescMatches.first);
            anyUpdated = true;
          } else if (candidates.length == 1) {
            item.applyMaster(candidates.first);
            anyUpdated = true;
          } else if (candidates.length > 1) {
            item.candidateMatches = candidates;
            item.matchStatus = MaterialMatchStatus.matchRequired;
            anyUpdated = true;
          } else {
            item.matchStatus = MaterialMatchStatus.matchRequired;
            anyUpdated = true;
          }
        } catch (_) {}
      }
    }

    if (mounted && anyUpdated) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _purchaseIdController.dispose();
    _vendorController.dispose();
    _roundOffController.dispose();
    _remarksController.dispose();
    _itemCountController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // Authoritative financial calculations
  double get _subtotal => double.parse(
      _items.fold(0.0, (sum, i) => sum + i.taxableAmount).toStringAsFixed(2));
  double get _totalCgst => double.parse(
      _items.fold(0.0, (sum, i) => sum + i.cgstValue).toStringAsFixed(2));
  double get _totalSgst => double.parse(
      _items.fold(0.0, (sum, i) => sum + i.sgstValue).toStringAsFixed(2));
  double get _totalGst => double.parse((_totalCgst + _totalSgst).toStringAsFixed(2));
  double get _totalIgst => double.parse(
      _items.fold(0.0, (sum, i) => sum + i.igstValue).toStringAsFixed(2));
  double get _grandTotal => double.parse(
      (_subtotal + _totalGst + _totalIgst).toStringAsFixed(2));
  double get _roundOff => double.tryParse(_roundOffController.text) ?? 0.0;
  double get _finalTotal => double.parse((_grandTotal + _roundOff).toStringAsFixed(2));

  void _onInvoiceDateChanged(DateTime newDate) {
    final newLot = calculateDayOfYearLot(newDate);
    setState(() {
      _invoiceDate = newDate;
      for (final item in _items) {
        item.lotController.text = newLot;
        item.purchaseDate = newDate;
      }
    });
  }

  void _addItem() {
    if (_items.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 50 items allowed per invoice')),
      );
      return;
    }
    setState(() {
      _items.add(_FormItem(
        lotNo: calculateDayOfYearLot(_invoiceDate),
        purchaseDate: _invoiceDate,
      ));
      _itemCountController.text = _items.length.toString();
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
        _itemCountController.text = _items.length.toString();
      });
    }
  }

  Future<void> _setItemCount(int targetCount) async {
    if (targetCount < 1 || targetCount > 50) return;
    if (targetCount == _items.length) return;

    if (targetCount < _items.length) {
      final itemsToDrop = _items.sublist(targetCount);
      final hasData = itemsToDrop.any((item) => item.hasEnteredData);

      if (hasData) {
        final confirmed = await ConfirmationDialog.show(
          context,
          title: 'Reduce Line Items?',
          message:
              'Reducing item count to $targetCount will discard data in items ${targetCount + 1} to ${_items.length}. Continue?',
          confirmText: 'Yes, Reduce',
          isDestructive: true,
        );
        if (!confirmed) {
          _itemCountController.text = _items.length.toString();
          return;
        }
      }

      setState(() {
        for (final item in _items.sublist(targetCount)) {
          item.dispose();
        }
        _items.removeRange(targetCount, _items.length);
        _itemCountController.text = targetCount.toString();
      });
    } else {
      final diff = targetCount - _items.length;
      final currentLot = calculateDayOfYearLot(_invoiceDate);
      setState(() {
        for (int i = 0; i < diff; i++) {
          _items.add(_FormItem(
            lotNo: currentLot,
            purchaseDate: _invoiceDate,
          ));
        }
        _itemCountController.text = targetCount.toString();
      });
    }
  }

  void _onCodeChanged(_FormItem item, String val) {
    item.codeDebounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        item.matchStatus = MaterialMatchStatus.none;
        item.matchedMaterialName = null;
        item.candidateMatches = [];
      });
      return;
    }

    item.codeDebounce = Timer(const Duration(milliseconds: 250), () async {
      final repo = ref.read(materialsRepositoryProvider);
      try {
        final match = await repo.getMaterialByCode(trimmed);
        if (!mounted) return;
        if (match != null) {
          setState(() {
            item.applyMaster(match);
          });
        } else {
          setState(() {
            item.matchStatus = MaterialMatchStatus.notFound;
            item.matchedMaterialName = null;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          item.matchStatus = MaterialMatchStatus.notFound;
        });
      }
    });
  }

  void _onDescChanged(_FormItem item, String val) {
    item.descDebounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        item.candidateMatches = [];
        if (item.codeController.text.trim().isEmpty) {
          item.matchStatus = MaterialMatchStatus.none;
          item.matchedMaterialName = null;
        }
      });
      return;
    }

    item.descDebounce = Timer(const Duration(milliseconds: 300), () async {
      final repo = ref.read(materialsRepositoryProvider);
      try {
        final results = await repo.searchMaterials(trimmed, limit: 8);
        if (!mounted) return;

        final exact = results
            .where((m) => m.description.trim().toLowerCase() == trimmed.toLowerCase())
            .toList();

        if (exact.length == 1) {
          setState(() {
            item.applyMaster(exact.first);
          });
        } else if (results.length == 1) {
          setState(() {
            item.applyMaster(results.first);
          });
        } else if (results.length > 1) {
          setState(() {
            item.candidateMatches = results;
            item.matchStatus = MaterialMatchStatus.multipleCandidates;
          });
        } else {
          setState(() {
            item.candidateMatches = [];
            item.matchStatus = MaterialMatchStatus.notFound;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          item.matchStatus = MaterialMatchStatus.notFound;
        });
      }
    });
  }

  Future<void> _openMaterialSearchPicker(_FormItem item) async {
    final repo = ref.read(materialsRepositoryProvider);
    String query = '';
    List<MaterialModel> searchResults = [];
    bool isLoading = true;

    try {
      searchResults = await repo.searchMaterials('', limit: 30);
    } catch (_) {}
    isLoading = false;

    if (!mounted) return;

    final selected = await showModalBottomSheet<MaterialModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Material Master',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Register New'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openRegisterNewMaterial(item);
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search by Code or Description...',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onChanged: (val) async {
                        query = val;
                        setModalState(() => isLoading = true);
                        try {
                          final res = await repo.searchMaterials(val, limit: 30);
                          setModalState(() {
                            searchResults = res;
                            isLoading = false;
                          });
                        } catch (_) {
                          setModalState(() => isLoading = false);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                                    const SizedBox(height: 8),
                                    Text('No materials found for "$query"',
                                        style: const TextStyle(color: AppColors.textMuted)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Register As New Material'),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _openRegisterNewMaterial(item);
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: searchResults.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final mat = searchResults[i];
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        mat.materialCode,
                                        style: GoogleFonts.jetBrainsMono(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.primaryLight),
                                      ),
                                    ),
                                    title: Text(mat.description,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text(
                                        '${mat.category} • ${mat.unit}${mat.grade.isNotEmpty ? " • Grade: ${mat.grade}" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    onTap: () => Navigator.pop(ctx, mat),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        item.applyMaster(selected);
      });
    }
  }

  Future<void> _openRegisterNewMaterial(_FormItem item) async {
    final res = await showDialog<dynamic>(
      context: context,
      builder: (_) => NewMaterialDialog(
        initialCode: item.codeController.text.trim(),
        initialDescription: item.descController.text.trim(),
      ),
    );

    if (res != null && mounted) {
      ref.invalidate(materialsListProvider);
      ref.invalidate(dynamicDescriptionsProvider);
      ref.invalidate(dynamicCategoriesProvider);

      final codeStr = res is String ? res : item.codeController.text.trim();
      if (codeStr.isNotEmpty) {
        final repo = ref.read(materialsRepositoryProvider);
        try {
          final mat = await repo.getMaterialByCode(codeStr);
          if (mat != null && mounted) {
            setState(() {
              item.applyMaster(mat);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Material "${mat.description}" (${mat.materialCode}) registered and auto-filled!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _pickPurchaseDate(_FormItem item) async {
    final initial = item.purchaseDate ?? _invoiceDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => item.purchaseDate = picked);
    }
  }

  Future<void> _pickExpiryDate(_FormItem item) async {
    final initial = item.expiryDate ?? DateTime.now().add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => item.expiryDate = picked);
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate materials list
    final materialsRepo = ref.read(materialsRepositoryProvider);
    List<MaterialModel> allExistingMaterials = [];
    try {
      allExistingMaterials = await materialsRepo.fetchMaterials(limit: 2000);
    } catch (_) {}
    if (!mounted) return;

    final invoiceCodes = <String>{};

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final itemNum = i + 1;
      String code = item.materialCode;
      String desc = item.description;

      // If code was not entered but description was, try matching with existing master
      if (code.isEmpty && desc.isNotEmpty) {
        final match = allExistingMaterials
            .where((m) => m.description.trim().toUpperCase() == desc.trim().toUpperCase())
            .toList();
        if (match.isNotEmpty) {
          code = match.first.materialCode;
          item.codeController.text = code;
        } else {
          code = desc.replaceAll(' ', '-').toUpperCase();
          item.codeController.text = code;
        }
      }

      if (code.isEmpty && desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item #$itemNum: Please select or enter a material')),
        );
        return;
      }

      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item #$itemNum: Quantity must be greater than 0')),
        );
        return;
      }

      if (invoiceCodes.contains(code.toUpperCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item #$itemNum: Material code $code is duplicated in this invoice.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      invoiceCodes.add(code.toUpperCase());

      // Validation: verify existing code vs description compatibility
      final matchByCode = allExistingMaterials
          .where((m) => m.materialCode.toUpperCase() == code.toUpperCase())
          .toList();

      if (matchByCode.isNotEmpty) {
        final existingMat = matchByCode.first;
        if (existingMat.description.isNotEmpty &&
            desc.isNotEmpty &&
            existingMat.description.toUpperCase() != desc.toUpperCase()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material code $code is already taken by "${existingMat.description}".'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      } else {
        // Validation: prevent duplicate description under different code
        final matchByDesc = allExistingMaterials
            .where((m) => m.description.trim().toUpperCase() == desc.toUpperCase())
            .toList();

        if (matchByDesc.isNotEmpty) {
          final existingMat = matchByDesc.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Material description "$desc" already exists under code ${existingMat.materialCode}.'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final rawInvNo = _invoiceNoController.text.trim();
      final finalInvoiceNo = rawInvNo.isNotEmpty
          ? TextStandardizer.normalizeBusinessText(rawInvNo)
          : 'INV-${_invoiceDate.year}${_invoiceDate.month.toString().padLeft(2, '0')}${_invoiceDate.day.toString().padLeft(2, '0')}-${Random().nextInt(9000) + 1000}';

      final rawVendor = _vendorController.text.trim();
      final finalVendor = rawVendor.isNotEmpty ? TextStandardizer.normalizeBusinessText(rawVendor) : null;

      final rawPurchaseId = _purchaseIdController.text.trim();
      final finalPurchaseId = rawPurchaseId.isNotEmpty ? TextStandardizer.normalizeBusinessText(rawPurchaseId) : null;

      final rawRemarks = _remarksController.text.trim();
      final finalRemarks = rawRemarks.isNotEmpty ? TextStandardizer.normalizeBusinessText(rawRemarks) : null;

      final invoicePayload = {
        'purchase_id': finalPurchaseId,
        'date': _invoiceDate.toIso8601String().split('T')[0],
        'invoice_no': finalInvoiceNo,
        'vendor': finalVendor,
        'no_of_items': _items.length,
        'round_off_value': _roundOff,
        'payment_status': _paymentStatus,
        'remarks': finalRemarks,
      };

      final itemsPayload = _items.map((i) => i.toPayload(_invoiceDate)).toList();

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
      ref.invalidate(transferMaterialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Purchase Invoice and lot stock updated successfully!'
                : 'Purchase Invoice saved and raw material lot stock generated successfully!'),
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

  Widget _buildOcrSection() {
    final isOcrMode = widget.isOcrScanMode;

    return GlassCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryLight, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOcrMode ? 'RapidOCR Scanner & Invoice Entry' : 'Scan Invoice via RapidOCR',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            isOcrMode
                                ? 'Auto-fill boxes via OCR. All fields below are fully editable.'
                                : 'Auto-fill form fields by snapping or uploading supplier tax invoice.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOcrMode)
                IconButton(
                  icon: Icon(
                    _isOcrSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                  ),
                  tooltip: _isOcrSectionExpanded ? 'Collapse Scanner' : 'Expand Scanner',
                  onPressed: () {
                    setState(() {
                      _isOcrSectionExpanded = !_isOcrSectionExpanded;
                    });
                  },
                ),
            ],
          ),
          if (_isOcrSectionExpanded || isOcrMode) ...[
            const SizedBox(height: 12),
            // Action Buttons Row: Camera, Gallery/File, Multi-Page
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: 'Camera Scan',
                    icon: Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    height: 40,
                    onPressed: _isScanning ? null : () => _pickImageAndScan(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton(
                    text: 'Gallery / PDF',
                    icon: Icons.upload_file_rounded,
                    isOutlined: true,
                    height: 40,
                    onPressed: _isScanning ? null : _pickFileAndScan,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.auto_stories_rounded, color: Color(0xFF818CF8), size: 22),
                  tooltip: 'Multi-Page Scan',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiPageScanScreen()));
                  },
                ),
              ],
            ),
            // Scanning Indicator
            if (_isScanning) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryLight),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'RapidOCR analyzing invoice lines & GST...',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Error Message
            if (_ocrErrorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_ocrErrorMessage!,
                          style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: AppColors.danger),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _ocrErrorMessage = null),
                    ),
                  ],
                ),
              ),
            ],
            // Success Message / Scanned Document Preview Bar
            if (_scannedFile != null && !_isScanning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scannedFileName ?? 'Scanned Document',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _ocrSuccessMessage ?? 'Extracted fields populated in form boxes below.',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 14, color: AppColors.primaryLight),
                      label: const Text('View Bill',
                          style: TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                      onPressed: () => _showDocumentPreviewDialog(_scannedFile!),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(dynamicVendorsProvider);
    final existingVendors = vendorsAsync.asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOcrScanMode
            ? 'RapidOCR Invoice Scanner'
            : (_isEditMode ? 'Edit Inward Purchase Invoice' : 'New Inward Purchase Invoice')),
        actions: [
          if (!widget.isOcrScanMode && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryLight),
              tooltip: 'Scan Bill via RapidOCR',
              onPressed: () {
                setState(() {
                  _isOcrSectionExpanded = true;
                });
                _pickImageAndScan(ImageSource.camera);
              },
            ),
        ],
      ),
      body: AmbientBackground(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOcrSection(),
                const SizedBox(height: 18),
                _buildHeaderSection(existingVendors),
                const SizedBox(height: 18),
                _buildItemsSection(),
                const SizedBox(height: 18),
                _buildTotalsCard(),
                const SizedBox(height: 24),
                _buildActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GlassButton(
            text: 'Back',
            icon: Icons.arrow_back_rounded,
            isOutlined: true,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 7,
          child: GlassButton(
            text: _isEditMode ? 'Update Purchase Invoice' : 'Save Inward Purchase',
            isLoading: _isSaving,
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            onPressed: _submitInvoice,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(List<String> existingVendors) {
    final generatedLot = calculateDayOfYearLot(_invoiceDate);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoice Details',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 13, color: AppColors.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      'Lot: $generatedLot',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: StandardizedTextField(
                  controller: _invoiceNoController,
                  isCodeField: true,
                  labelText: 'Invoice No (Optional)',
                  hintText: 'Auto-generated if left empty',
                  prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
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
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      _onInvoiceDateChanged(picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Invoice Date (DD/MM/YYYY)',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                    ),
                    child: Text(
                      AppDateFormatter.format(_invoiceDate),
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
            labelText: 'Vendor / Supplier Name (Optional)',
            hintText: 'e.g. JAI AGENCIES',
            prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
            referenceCandidates: existingVendors,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: StandardizedTextField(
                  controller: _purchaseIdController,
                  isCodeField: true,
                  labelText: 'Purchase ID',
                  hintText: 'e.g. PUR-01',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: StandardizedTextField(
                  controller: _remarksController,
                  labelText: 'Remarks / Notes',
                  hintText: 'e.g. RECEIVED IN GOOD CONDITION',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                ),
              ),
            ],
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
            Row(
              children: [
                Text(
                  'Line Items',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _itemCountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onSubmitted: (val) {
                            final count = int.tryParse(val.trim()) ?? _items.length;
                            if (count >= 1 && count <= 50) {
                              _setItemCount(count);
                            } else {
                              _itemCountController.text = _items.length.toString();
                            }
                          },
                        ),
                      ),
                      PopupMenuButton<int>(
                        icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        color: const Color(0xFF0F172A),
                        tooltip: 'Select 1–50 items',
                        onSelected: _setItemCount,
                        itemBuilder: (context) {
                          final quickCounts = [1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 40, 50];
                          return quickCounts.map((cnt) {
                            return PopupMenuItem<int>(
                              value: cnt,
                              height: 32,
                              child: Text(
                                '$cnt ${cnt == 1 ? "Item" : "Items"}',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryLight),
              label: const Text('Add Item', style: TextStyle(color: AppColors.primaryLight)),
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _buildLineItemCard(i),
        ),
      ],
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _items[index];
    final generatedLot = calculateDayOfYearLot(_invoiceDate);
    if (item.lotNo.isEmpty) {
      item.lotController.text = generatedLot;
    }
    item.purchaseDate ??= _invoiceDate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Header: Item Number, Lot Pill, Feedback State, and Delete Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'MATERIAL ${index + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.lotNo.isNotEmpty ? item.lotNo : generatedLot,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Subtle Status Confirmation Badge
                      if (item.matchStatus == MaterialMatchStatus.matched)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                item.matchedMaterialName != null && item.matchedMaterialName!.isNotEmpty
                                    ? 'Material Master Matched'
                                    : 'Material Found',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      if (item.matchStatus == MaterialMatchStatus.matchRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline_rounded, color: AppColors.accent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Material Match Required',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      if (_items.length > 1) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.danger),
                          tooltip: 'Remove Item',
                          onPressed: () => _removeItem(index),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Warning State Banner if Material Not Found
              if (item.matchStatus == MaterialMatchStatus.notFound) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Material not found in Material Master.',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.search, size: 15, color: AppColors.primaryLight),
                        label: const Text('Search', style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                        onPressed: () => _openMaterialSearchPicker(item),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Register New', style: TextStyle(fontSize: 12)),
                        onPressed: () => _openRegisterNewMaterial(item),
                      ),
                    ],
                  ),
                ),
              ],

              // Candidate matches list (for multi-match or description search disambiguation)
              if (item.candidateMatches.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Matching Material (${item.candidateMatches.length} candidates):',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          ),
                          InkWell(
                            onTap: () => setState(() => item.candidateMatches = []),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...item.candidateMatches.take(5).map((mat) => InkWell(
                            onTap: () {
                              setState(() {
                                item.applyMaster(mat);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      mat.materialCode,
                                      style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryLight),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mat.description,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary),
                                        ),
                                        Text(
                                          'Category: ${mat.category} • UOM: ${mat.unit}${mat.grade.isNotEmpty ? " • Grade: ${mat.grade}" : ""}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.accent),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // ── PROMINENT MATERIAL IDENTIFICATION FIELDS (Code + Description) ──
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: item.codeController,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Material Code (Search / Enter)',
                          hintText: 'e.g. 100 or TEA-01',
                          prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, size: 18),
                            tooltip: 'Search Material Master',
                            onPressed: () => _openMaterialSearchPicker(item),
                          ),
                        ),
                        validator: (val) => (item.codeController.text.trim().isEmpty && item.descController.text.trim().isEmpty) ? 'Enter Code or Name' : null,
                        onChanged: (val) => _onCodeChanged(item, val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: item.descController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Description / Name (Search / Enter)',
                          hintText: 'e.g. MINT or GREEN TEA',
                          prefixIcon: const Icon(Icons.description_outlined, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_box_outlined, size: 18),
                            tooltip: 'Register New Material',
                            onPressed: () => _openRegisterNewMaterial(item),
                          ),
                        ),
                        validator: (val) => (item.codeController.text.trim().isEmpty && item.descController.text.trim().isEmpty) ? 'Enter Code or Name' : null,
                        onChanged: (val) => _onDescChanged(item, val),
                      ),
                    ),
                  ],
                )
              else ...[
                TextFormField(
                  controller: item.codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Material Code (Search / Enter)',
                    hintText: 'e.g. 100 or TEA-01',
                    prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      tooltip: 'Search Material Master',
                      onPressed: () => _openMaterialSearchPicker(item),
                    ),
                  ),
                  validator: (val) => (item.codeController.text.trim().isEmpty && item.descController.text.trim().isEmpty) ? 'Enter Code or Name' : null,
                  onChanged: (val) => _onCodeChanged(item, val),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: item.descController,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Description / Name (Search / Enter)',
                    hintText: 'e.g. MINT or GREEN TEA',
                    prefixIcon: const Icon(Icons.description_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      tooltip: 'Register New Material',
                      onPressed: () => _openRegisterNewMaterial(item),
                    ),
                  ),
                  validator: (val) => (item.codeController.text.trim().isEmpty && item.descController.text.trim().isEmpty) ? 'Enter Code or Name' : null,
                  onChanged: (val) => _onDescChanged(item, val),
                ),
              ],
              const SizedBox(height: 12),

              // Category and Centralized UOM
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: item.categoryController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        prefixIcon: Icon(Icons.category_outlined, size: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: UomDropdown(
                      value: item.unit,
                      labelText: 'UOM *',
                      onChanged: (val) {
                        if (val != null) setState(() => item.unit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quantity and Unit Price
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: item.qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Quantity *',
                        prefixIcon: const Icon(Icons.scale_rounded, size: 16),
                        suffixText: item.unit,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final d = double.tryParse(val);
                        if (d == null || d <= 0) return 'Must be > 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: item.priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (₹) (Optional)',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.currency_rupee_rounded, size: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Discount %, GST %, IGST %
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: item.discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Discount %',
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: item.gstController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        hintText: '0',
                      ),
                      onChanged: (val) {
                        final d = double.tryParse(val) ?? 0.0;
                        if (d > 0) item.igstController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: item.igstController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'IGST %',
                        hintText: '0',
                      ),
                      onChanged: (val) {
                        final d = double.tryParse(val) ?? 0.0;
                        if (d > 0) item.gstController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Batch / Lot, Purchase Date, Expiry Date
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: item.lotController,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Lot Number (Optional)',
                          hintText: 'Auto-assigned if empty',
                          prefixIcon: Icon(Icons.tag_rounded, size: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => _pickPurchaseDate(item),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date (Optional)',
                            prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                          ),
                          child: Text(
                            AppDateFormatter.format(item.purchaseDate ?? _invoiceDate),
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => _pickExpiryDate(item),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expiry Date (Optional)',
                            prefixIcon: const Icon(Icons.event_outlined, size: 16),
                            suffixIcon: item.expiryDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () => setState(() => item.expiryDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            item.expiryDate != null ? AppDateFormatter.format(item.expiryDate!) : 'No Expiry',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.expiryDate != null ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                TextFormField(
                  controller: item.lotController,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Lot Number (Optional)',
                    hintText: 'Auto-assigned if empty',
                    prefixIcon: Icon(Icons.tag_rounded, size: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickPurchaseDate(item),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date (Optional)',
                            prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                          ),
                          child: Text(
                            AppDateFormatter.format(item.purchaseDate ?? _invoiceDate),
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickExpiryDate(item),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expiry Date (Optional)',
                            prefixIcon: const Icon(Icons.event_outlined, size: 16),
                            suffixIcon: item.expiryDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () => setState(() => item.expiryDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            item.expiryDate != null ? AppDateFormatter.format(item.expiryDate!) : 'No Expiry',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.expiryDate != null ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Reorder Level and Centralized Grade Dropdown
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: item.reorderController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level (Optional)',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: GradeDropdown(
                      value: item.grade,
                      labelText: 'Grade (Optional)',
                      onChanged: (val) {
                        setState(() => item.grade = val ?? '');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Card Calculation Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taxable: ${QuantityFormatter.formatCurrency(item.taxableAmount)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      item.hasIgst
                          ? 'IGST: ${QuantityFormatter.formatCurrency(item.igstValue)}'
                          : 'GST: ${QuantityFormatter.formatCurrency(item.totalGstValue)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      'Item Total: ${QuantityFormatter.formatCurrency(item.itemTotal)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalsCard() {
    return GlassCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.calculate_outlined, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Financial Calculation Summary',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subtotal / Total Excl. Tax
          _buildSummaryRow('Subtotal / Total Excl. Tax', QuantityFormatter.formatCurrency(_subtotal)),
          const SizedBox(height: 8),

          // Total GST with breakdown
          _buildSummaryRow('Total GST', QuantityFormatter.formatCurrency(_totalGst), isBold: true),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 6),
            child: Column(
              children: [
                _buildSummarySubRow('CGST', QuantityFormatter.formatCurrency(_totalCgst)),
                const SizedBox(height: 3),
                _buildSummarySubRow('SGST', QuantityFormatter.formatCurrency(_totalSgst)),
              ],
            ),
          ),

          // Total IGST
          _buildSummaryRow('Total IGST', QuantityFormatter.formatCurrency(_totalIgst)),
          const Divider(height: 20),

          // Grand Total
          _buildSummaryRow('Grand Total', QuantityFormatter.formatCurrency(_grandTotal), isBold: true),
          const SizedBox(height: 10),

          // Round Off
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Round Off', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _roundOffController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Final Bill Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Bill Total',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                QuantityFormatter.formatCurrency(_finalTotal),
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
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

  Widget _buildSummarySubRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '• $label',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
