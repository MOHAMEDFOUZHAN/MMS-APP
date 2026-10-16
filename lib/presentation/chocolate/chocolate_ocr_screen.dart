import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/weighing_machine_ocr_service.dart';
import '../../data/models/chocolate_ocr_ledger_model.dart';
import '../../data/models/chocolate_finished_product_model.dart';
import '../../core/services/chocolate_speech_service.dart';
import '../../core/services/chocolate_product_vocabulary_service.dart';
import '../providers/chocolate_ocr_providers.dart';
import '../providers/app_providers.dart';

class ChocolateOcrScreen extends ConsumerStatefulWidget {
  const ChocolateOcrScreen({super.key});

  @override
  ConsumerState<ChocolateOcrScreen> createState() => _ChocolateOcrScreenState();
}

class _ChocolateOcrScreenState extends ConsumerState<ChocolateOcrScreen> {
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();

  // Mode Selection: 0 = Weighing Machine OCR (LED Display), 1 = Document / Invoice OCR
  int _selectedMode = 0;

  File? _scannedFile;
  String? _scannedFileName;
  bool _isScanning = false;
  bool _isConfirming = false;

  // OCR Extraction State
  double? _detectedQuantity;
  String? _detectedQuantityString;
  String _detectedUnit = 'KG';
  static const List<String> _uomOptions = ['KG', 'G', 'PCS', 'BOX', 'TRAY', 'PACKET'];
  double _detectedConfidence = 0.0;
  String? _rawOcrText;
  String? _ocrErrorMessage;
  bool _isQuantityValid = false;
  String? _currentIdempotencyKey;
  String? _productNameError;

  // Weighing Machine Specific State
  bool _isWeighingStable = true;
  String? _weighingModelUsed;

  // Speech-to-Text & Finished Product Vocabulary State
  final _speechService = ChocolateSpeechService();
  final _vocabService = ChocolateProductVocabularyService();
  bool _isProductNameConfirmed = false;
  List<VocabularyMatchSuggestion> _productSuggestions = [];

  @override
  void initState() {
    super.initState();
    _vocabService.loadVocabulary();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _speechService.cancelListening();
    super.dispose();
  }

  /// Trigger document capture via camera (Document OCR mode)
  Future<void> _pickImage(ImageSource source) async {
    final name = _descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _productNameError = 'Finished Product Name is required before scanning';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Finished Product Name before scanning.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!_isProductNameConfirmed) {
      setState(() {
        _productNameError = 'Please review and confirm product name before scanning';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click "Confirm" on the product name before scanning.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _productNameError = null);

    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        await _processDocument(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to acquire image: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Trigger document file selection (PDF, PNG, JPG)
  Future<void> _pickFile() async {
    final name = _descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _productNameError = 'Finished Product Name is required before scanning';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Finished Product Name before scanning.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!_isProductNameConfirmed) {
      setState(() {
        _productNameError = 'Please review and confirm product name before scanning';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click "Confirm" on the product name before scanning.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _productNameError = null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        await _processDocument(File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select file: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Run OCR extraction for document / invoice
  Future<void> _processDocument(File file) async {
    setState(() {
      _scannedFile = file;
      _scannedFileName = file.path.split(Platform.pathSeparator).last;
      _isScanning = true;
      _ocrErrorMessage = null;
      _detectedQuantity = null;
      _isQuantityValid = false;
      _rawOcrText = null;
      _currentIdempotencyKey = 'CHOC-DOC-${DateTime.now().millisecondsSinceEpoch}-${file.hashCode.abs()}';
    });

    try {
      final result = await OcrService.parseChocolateDocument(file);

      if (!mounted) return;

      if (!result.isQuantityValid || result.detectedQuantity == null || result.detectedQuantity! <= 0) {
        setState(() {
          _isScanning = false;
          _isQuantityValid = false;
          _detectedQuantity = null;
          _ocrErrorMessage = result.errorMessage ??
              'OCR Quantity Detection Failed: Could not extract a valid numerical quantity from document. Please rescan with better clarity.';
          _rawOcrText = result.rawOcrText;
        });
      } else {
        setState(() {
          _isScanning = false;
          _isQuantityValid = true;
          _detectedQuantity = result.detectedQuantity;
          _detectedQuantityString = result.detectedQuantity != null
              ? (result.detectedQuantity! % 1 == 0 ? result.detectedQuantity!.toInt().toString() : result.detectedQuantity!.toString())
              : null;
          _detectedUnit = result.unit.isNotEmpty ? result.unit : 'KG';
          _detectedConfidence = result.confidence;
          _rawOcrText = result.rawOcrText;
          _ocrErrorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _isQuantityValid = false;
        _detectedQuantity = null;
        _ocrErrorMessage = 'OCR Extraction Error: $e. Please rescan or use a clear document.';
      });
    }
  }

  /// Trigger Weighing Machine Camera Capture
  Future<void> _pickWeighingImage(ImageSource source) async {
    final name = _descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _productNameError = 'Finished Product Name is required before scanning';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Finished Product Name before scanning.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!_isProductNameConfirmed) {
      setState(() {
        _productNameError = 'Please review and confirm product name before opening camera';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click "Confirm" on the product name before opening camera.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _productNameError = null);

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1400,
        imageQuality: 95,
      );
      if (picked != null) {
        await _processWeighingMachine(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera/Image error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Execute Weighing Machine LED OCR Pipeline (Single-photo OCR)
  Future<void> _processWeighingMachine(File file) async {
    setState(() {
      _scannedFile = file;
      _scannedFileName = file.path.split(Platform.pathSeparator).last;
      _isScanning = true;
      _ocrErrorMessage = null;
      _detectedQuantity = null;
      _isQuantityValid = false;
      _currentIdempotencyKey = 'CHOC-WEIGH-${DateTime.now().millisecondsSinceEpoch}-${file.hashCode.abs()}';
    });

    try {
      final result = await WeighingMachineOcrService.parseWeighingIndicator(
        file,
        existingSamples: [],
      );

      if (!mounted) return;

      if (!result.isValid || result.numericWeight == null || result.numericWeight! <= 0) {
        setState(() {
          _isScanning = false;
          _isQuantityValid = false;
          _detectedQuantity = result.numericWeight;
          _detectedQuantityString = result.weightString;
          _isWeighingStable = false;
          _weighingModelUsed = result.model;
          _ocrErrorMessage = result.errorMessage ??
              'Weighing Indicator OCR Failed: Could not detect valid weight digits on display. Position camera closer to LED digits.';
          _rawOcrText = result.rawText;
        });
      } else {
        setState(() {
          _isScanning = false;
          _isQuantityValid = true;
          _detectedQuantity = result.numericWeight;
          _detectedQuantityString = result.weightString ?? (result.numericWeight! % 1 == 0 ? result.numericWeight!.toInt().toString() : result.numericWeight!.toString());
          _detectedUnit = result.unit.isNotEmpty ? result.unit : 'KG';
          _detectedConfidence = result.confidence;
          _rawOcrText = result.rawText;
          _isWeighingStable = true;
          _weighingModelUsed = result.model;
          _ocrErrorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _isQuantityValid = false;
        _detectedQuantity = null;
        _ocrErrorMessage = 'Weighing OCR Error: $e. Please recapture display.';
      });
    }
  }

  /// Retake Weighing Machine capture
  void _retakeWeighing() {
    setState(() {
      _scannedFile = null;
      _scannedFileName = null;
      _isScanning = false;
      _detectedQuantity = null;
      _detectedQuantityString = null;
      _isQuantityValid = false;
      _rawOcrText = null;
      _ocrErrorMessage = null;
      _isWeighingStable = true;
      _currentIdempotencyKey = null;
    });
  }

  /// Confirm and record the finished chocolate product in the permanent ledger
  Future<void> _confirmAndSave() async {
    if (_isConfirming) return; // Prevent double taps

    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the Finished Chocolate Product Description.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_isProductNameConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please review and click "Confirm" on the product name before saving.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_isQuantityValid || _detectedQuantity == null || _detectedQuantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot confirm: A valid OCR-detected quantity (> 0) is required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedMode == 0 && !_isWeighingStable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot confirm: Weight is unstable. Wait for scale to settle and recapture.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final repo = ref.read(chocolateOcrRepositoryProvider);
      final idempKey = _currentIdempotencyKey ?? 'CHOC-OCR-${DateTime.now().millisecondsSinceEpoch}';

      final saved = await repo.confirmEntry(
        description: desc,
        quantity: _detectedQuantity!,
        unit: _detectedUnit,
        rawOcrQuantity: _detectedQuantity!,
        rawOcrText: _rawOcrText,
        documentName: _selectedMode == 0
            ? 'Weighing Machine (${_weighingModelUsed ?? "RapidOCR PP-OCRv3 (ONNX)"})'
            : _scannedFileName,
        idempotencyKey: idempKey,
      );

      if (!mounted) return;

      ref.invalidate(chocolateOcrLedgerProvider);
      ref.invalidate(activeBatchesProvider);
      ref.invalidate(dispatchesListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirmed! "${saved.description}" (${saved.displayQuantity}) recorded in ledger.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset scan & review card so user can perform next scan cleanly
      setState(() {
        _isConfirming = false;
        _scannedFile = null;
        _scannedFileName = null;
        _detectedQuantity = null;
        _isQuantityValid = false;
        _rawOcrText = null;
        _ocrErrorMessage = null;
        _currentIdempotencyKey = null;
        _isWeighingStable = true;
        _descriptionController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm record: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearScan() {
    setState(() {
      _scannedFile = null;
      _scannedFileName = null;
      _isScanning = false;
      _detectedQuantity = null;
      _isQuantityValid = false;
      _rawOcrText = null;
      _ocrErrorMessage = null;
      _currentIdempotencyKey = null;
      _isWeighingStable = true;
      _descriptionController.clear();
      _isProductNameConfirmed = false;
      _productSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(chocolateOcrLedgerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.refresh(chocolateOcrLedgerProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Header Bar
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Mode Selector Tabs (Weighing Machine OCR vs Document OCR)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _buildModeSelector(),
                ),
              ),

              // Dedicated Scanner Action Card based on selected mode
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _selectedMode == 0
                      ? _buildWeighingMachineScannerCard()
                      : _buildDocumentScannerCard(),
                ),
              ),

              // In-Progress Scanner Indicator
              if (_isScanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildScanningProgressCard(),
                  ),
                ),

              // Review & Confirmation Section (Appears after document/display is scanned)
              if (_scannedFile != null && !_isScanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildReviewAndConfirmCard(),
                  ),
                ),

              // Confirmed Chocolate Ledger History Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Confirmed Chocolate Ledger',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      ledgerAsync.maybeWhen(
                        data: (items) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length} records',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Refresh Ledger',
                        onPressed: () => ref.refresh(chocolateOcrLedgerProvider),
                      ),
                    ],
                  ),
                ),
              ),

              // Confirmed Ledger List Items
              ledgerAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _buildEmptyLedgerState(),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) => _buildLedgerEntryTile(item)).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                    ),
                  ),
                ),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading ledger: $err',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceLight,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try Again'),
                            onPressed: () => ref.refresh(chocolateOcrLedgerProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Screen Header (Mobile Responsive)
  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isCompact ? 8 : 12, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFB45309)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.neonGlow(const Color(0xFFD97706), blur: 12),
            ),
            child: Icon(Icons.speed_rounded, color: Colors.white, size: isCompact ? 20 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Chocolate OCR',
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'FINISHED GOODS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'RAPIDOCR ONNX',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Weighing Machine Indicator & Finished Product OCR',
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 11 : 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mode Selector: Weighing Machine OCR (LED) vs Document / Invoice OCR
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x3B020617),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedMode != 0) {
                  _clearScan();
                  setState(() => _selectedMode = 0);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: _selectedMode == 0 ? const Color(0xFFD97706) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedMode == 0 ? AppColors.neonGlow(const Color(0xFFD97706), blur: 8) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 15,
                      color: _selectedMode == 0 ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Weighing Machine OCR',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 0 ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedMode != 1) {
                  _clearScan();
                  setState(() => _selectedMode = 1);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: _selectedMode == 1 ? const Color(0xFFD97706) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedMode == 1 ? AppColors.neonGlow(const Color(0xFFD97706), blur: 8) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_rounded,
                      size: 15,
                      color: _selectedMode == 1 ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Document / Invoice',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 1 ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Specialized Scanner Card for Industrial Weighing Machine LED Indicator
  Widget _buildWeighingMachineScannerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
        boxShadow: AppColors.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFF59E0B), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weighing Indicator Camera Scanner',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Baykon BX27 & Industrial 7-Segment Red LED Displays',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_scannedFile != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textMuted),
                  label: const Text('Retake', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onPressed: _retakeWeighing,
                ),
            ],
          ),

          const SizedBox(height: 14),

          // 1. Finished Product Name with Speech-to-Text & Finished Goods Catalog Suggestions
          _buildProductNameInputField(),

          const SizedBox(height: 12),

          // Viewfinder Guidance / Display Reticle Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF030712),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('┌', style: GoogleFonts.jetBrainsMono(fontSize: 16, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LED DISPLAY RETICLE',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                      ),
                    ),
                    Text('┐', style: GoogleFonts.jetBrainsMono(fontSize: 16, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.center_focus_strong_rounded, size: 26, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Position the digital LED digits directly inside the camera frame.\nAvoid direct flash reflections on the screen.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('└', style: GoogleFonts.jetBrainsMono(fontSize: 16, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                    Text('───────────────', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF334155))),
                    Text('┘', style: GoogleFonts.jetBrainsMono(fontSize: 16, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Primary Capture Actions (Single-Photo OCR)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    onPressed: _isScanning ? null : () => _pickWeighingImage(ImageSource.camera),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.glassBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFFF59E0B)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    onPressed: _isScanning ? null : () => _pickWeighingImage(ImageSource.gallery),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.glassBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFFF59E0B)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('PDF / File', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    onPressed: _isScanning ? null : _pickFile,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Document / Invoice Scanner Card (Legacy Document Inward Mode)
  Widget _buildDocumentScannerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.document_scanner_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text(
                'Scan Document / Invoice',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_scannedFile != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                  label: const Text('Clear', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onPressed: _clearScan,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Capture carton labels, finished goods dispatch slips, or invoices. Enter product name before scanning.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: 12),
          // Finished Product Name with Speech-to-Text & Finished Goods Catalog Suggestions
          _buildProductNameInputField(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: _isScanning ? null : () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFFF59E0B)),
                  label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFFF59E0B)),
                  label: const Text('PDF / File', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: _isScanning ? null : _pickFile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Interactive Voice Input Modal Bottom Sheet with animated sound wave & language switcher
  Future<void> _showVoiceInputDialog() async {
    final available = await _speechService.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_speechService.errorMessage ?? 'Microphone access is unavailable or permission denied.'),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    String spokenResult = '';

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        _speechService.startListening(
          onResult: (text, suggestions) {
            spokenResult = text;
          },
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            final locale = _speechService.selectedLocale;

            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFD97706), width: 2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mic_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Product Name Input',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Speak finished chocolate name into microphone',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () {
                          _speechService.cancelListening();
                          Navigator.pop(bottomSheetContext);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Language Switcher Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ChocolateSpeechService.supportedLocales.map((loc) {
                        final isSelected = loc.id == locale.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(loc.label),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFD97706),
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFFF59E0B) : AppColors.glassBorder,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                _speechService.setSelectedLocale(loc);
                                setModalState(() {});
                                _speechService.cancelListening().then((_) {
                                  _speechService.startListening(
                                    onResult: (text, suggestions) {
                                      spokenResult = text;
                                      setModalState(() {});
                                    },
                                  );
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Animated Soundwave Pulsing Microphone Icon
                  ValueListenableBuilder<double>(
                    valueListenable: _speechService.soundLevelNotifier,
                    builder: (context, level, child) {
                      final scale = 1.0 + (level * 0.35);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFB45309)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withValues(alpha: 0.3 + (level * 0.4)),
                                blurRadius: 16 + (level * 16),
                                spreadRadius: 4 + (level * 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  ValueListenableBuilder<SpeechStatus>(
                    valueListenable: _speechService.statusNotifier,
                    builder: (context, status, child) {
                      String statusText = 'Listening... Speak product name now';
                      Color statusColor = const Color(0xFFF59E0B);

                      if (status == SpeechStatus.completed) {
                        statusText = 'Speech captured. Review below.';
                        statusColor = const Color(0xFF10B981);
                      } else if (status == SpeechStatus.error) {
                        statusText = _speechService.errorMessage ?? 'Speech error occurred. Please try again.';
                        statusColor = AppColors.danger;
                      }

                      return Text(
                        statusText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _speechService.wordsNotifier,
                      builder: (context, words, child) {
                        if (words.isEmpty) {
                          return Center(
                            child: Text(
                              'e.g. "Dark Almond", "Mixed Box", "White Bar"...',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                            ),
                          );
                        }
                        return Text(
                          words,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),

                  // Real-time Catalog Match Outcome & Suggestions
                  ValueListenableBuilder<ProductMatchResult?>(
                    valueListenable: _speechService.matchResultNotifier,
                    builder: (context, matchResult, child) {
                      if (matchResult == null || _speechService.currentWords.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }

                      if (matchResult.isHighConfidence) {
                        final product = matchResult.selectedProduct!;
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'High Confidence Catalog Match:',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                    Text(
                                      product.productName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: () {
                                  _speechService.stopListening();
                                  Navigator.pop(bottomSheetContext);
                                  setState(() {
                                    _descriptionController.text = product.productName;
                                    _isProductNameConfirmed = false;
                                    _productSuggestions = [];
                                    _productNameError = null;
                                  });
                                },
                                child: const Text('SELECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      }

                      if (matchResult.isAmbiguous && matchResult.candidates.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ambiguous Match - Tap Your Exact Product:',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: matchResult.candidates.map((s) {
                                  return ActionChip(
                                    backgroundColor: const Color(0xFF1E293B),
                                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                                    label: Text(
                                      s.product.productName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onPressed: () {
                                      _speechService.stopListening();
                                      Navigator.pop(bottomSheetContext);
                                      setState(() {
                                        _descriptionController.text = s.product.productName;
                                        _isProductNameConfirmed = false;
                                        _productSuggestions = [];
                                        _productNameError = null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }

                      if (matchResult.isNone) {
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No matching chocolate product found in catalog. Please speak clearly.',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            side: const BorderSide(color: AppColors.glassBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                          onPressed: () {
                            _speechService.cancelListening();
                            Navigator.pop(bottomSheetContext);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Use Product Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () async {
                            final finalWords = await _speechService.stopListening();
                            final selectedText = finalWords.trim().isNotEmpty
                                ? finalWords.trim()
                                : spokenResult.trim();

                            if (selectedText.isEmpty) {
                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext);
                              }
                              return;
                            }

                            final match = _vocabService.matchProduct(selectedText);

                            if (match.isHighConfidence) {
                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext);
                              }
                              if (mounted) {
                                setState(() {
                                  _descriptionController.text = match.selectedProduct!.productName;
                                  _isProductNameConfirmed = false;
                                  _productSuggestions = [];
                                  _productNameError = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Recognized: ${match.selectedProduct!.productName}'),
                                    backgroundColor: const Color(0xFF10B981),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else if (match.isAmbiguous) {
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ambiguous match. Please tap the correct registered product from the choices above.'),
                                  backgroundColor: Color(0xFFD97706),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No approved chocolate product matched. Please repeat product name or select manually.'),
                                  backgroundColor: AppColors.danger,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Reusable Finished Product Name Input with Speech-to-Text & Finished Goods Catalog Suggestions
  Widget _buildProductNameInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Finished Product Name *',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_isProductNameConfirmed && _descriptionController.text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'CONFIRMED',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isProductNameConfirmed = false;
                        });
                      },
                      child: Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          readOnly: _isProductNameConfirmed,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _isProductNameConfirmed ? const Color(0xFF10B981) : AppColors.textPrimary,
            fontWeight: _isProductNameConfirmed ? FontWeight.w600 : FontWeight.normal,
          ),
          onChanged: (val) {
            setState(() {
              _isProductNameConfirmed = false;
              if (_productNameError != null && val.trim().isNotEmpty) {
                _productNameError = null;
              }
              _productSuggestions = _vocabService.findMatches(val);
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0x2B1E293B),
            hintText: 'Type or click mic to speak (e.g. Dark Almond)...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.cookie_outlined, size: 20, color: Color(0xFFF59E0B)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_descriptionController.text.isNotEmpty && !_isProductNameConfirmed)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                    tooltip: 'Clear',
                    onPressed: () {
                      _descriptionController.clear();
                      setState(() {
                        _isProductNameConfirmed = false;
                        _productSuggestions = [];
                        _productNameError = null;
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.25),
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 20, color: Color(0xFFF59E0B)),
                    tooltip: 'Speak Product Name (Voice Input)',
                    onPressed: _showVoiceInputDialog,
                  ),
                ),
              ],
            ),
            helperText: _isProductNameConfirmed
                ? 'Product name locked & verified. Click Camera below to capture weighing scale.'
                : 'Speak or type finished chocolate product name before scanning',
            helperStyle: TextStyle(
              fontSize: 11,
              color: _isProductNameConfirmed ? const Color(0xFF10B981) : AppColors.textMuted,
            ),
            errorText: _productNameError,
            errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _productNameError != null
                    ? AppColors.danger
                    : (_isProductNameConfirmed ? const Color(0xFF10B981) : AppColors.glassBorder),
                width: _isProductNameConfirmed ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
            ),
          ),
        ),

        // Confirm Product Name Button & Suggestions
        if (!_isProductNameConfirmed && _descriptionController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    'Confirm "${_descriptionController.text.trim()}"',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    setState(() {
                      _isProductNameConfirmed = true;
                      _productNameError = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ],

        // Suggestions from Chocolate Finished Product Catalog
        if (!_isProductNameConfirmed && _productSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      'Matching Finished Products (tap to select):',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _productSuggestions.take(4).map((s) {
                    final percentage = (s.score * 100).toInt();
                    return ActionChip(
                      backgroundColor: s.isExact
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFD97706).withValues(alpha: 0.15),
                      side: BorderSide(
                        color: s.isExact
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : const Color(0xFFD97706).withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      avatar: Icon(
                        s.isExact ? Icons.check_circle_rounded : Icons.label_rounded,
                        size: 13,
                        color: s.isExact ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      label: Text(
                        '${s.product.productName} ($percentage%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: s.isExact ? const Color(0xFF10B981) : AppColors.textPrimary,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _descriptionController.text = s.product.productName;
                          _isProductNameConfirmed = true;
                          _productSuggestions = [];
                          _productNameError = null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Scanning In-Progress Feedback Card
  Widget _buildScanningProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMode == 0
                      ? 'Analyzing LED display with PaddleOCR PP-OCRv5...'
                      : 'Analyzing document...',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedMode == 0
                      ? 'Segmenting red LED digits, isolating color channels & detecting decimal separator'
                      : 'Extracting finished chocolate product description and quantity',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Review & Confirmation Card with Read-Only Weight Enforced
  Widget _buildReviewAndConfirmCard() {
    final bool canConfirm = _isQuantityValid &&
        _detectedQuantity != null &&
        _detectedQuantity! > 0 &&
        (_selectedMode == 1 || _isWeighingStable) &&
        !_isConfirming &&
        !_isScanning &&
        _descriptionController.text.trim().isNotEmpty &&
        _isProductNameConfirmed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isQuantityValid
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: AppColors.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Status & Document Badge
          Row(
            children: [
              Icon(
                _isQuantityValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: _isQuantityValid ? AppColors.success : AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isQuantityValid ? 'OCR Extraction Review' : 'Ambiguous Reading — Retake Required',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_scannedFileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _scannedFileName!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),

          // Error Alert if Quantity could not be extracted or is ambiguous
          if (!_isQuantityValid) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambiguous or Unreliable Display Reading',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _ocrErrorMessage ??
                              'Could not extract a reliable numerical weight from display. Confirmation is locked until display photo is retaken.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Captured indicator photo preview
          if (_scannedFile != null && !_scannedFile!.path.toLowerCase().endsWith('.pdf')) ...[
            const SizedBox(height: 14),
            Text(
              'Captured Indicator Photo',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFF020617),
                child: Image.file(
                  _scannedFile!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 1. Finished Product Name Field
          Text(
            'Finished Product Name *',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x2B1E293B),
              hintText: 'e.g. Dark Chocolate Slab 70% 500g, Milk Chocolate Bar...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.cookie_outlined, size: 20, color: Color(0xFFF59E0B)),
              helperText: 'Finished chocolate product name (separate from raw-material master)',
              helperStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. OCR Weight Field (STRICTLY READ-ONLY, LOCKED UI & ENFORCED IMMUTABILITY)
          Text(
            _selectedMode == 0
                ? 'Weighing Indicator Detected Weight (Read-Only) *'
                : 'OCR-Detected Quantity (Read-Only) *',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // High-Visibility Industrial Display Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isQuantityValid
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                    : AppColors.danger.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'READ-ONLY • IMMUTABLE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF59E0B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _weighingModelUsed ?? 'On-Device 7-Segment OCR',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _isQuantityValid && _detectedQuantity != null
                                ? (_detectedQuantityString ?? (_detectedQuantity! % 1 == 0 ? _detectedQuantity!.toInt().toString() : _detectedQuantity!.toString()))
                                : '---',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: _isQuantityValid ? const Color(0xFFF59E0B) : AppColors.danger,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // UOM (Unit of Measure) Selector near Qty box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isQuantityValid
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'UOM: ',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _uomOptions.contains(_detectedUnit.toUpperCase())
                                  ? _detectedUnit.toUpperCase()
                                  : _uomOptions.first,
                              isDense: true,
                              dropdownColor: const Color(0xFF1E293B),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFFF59E0B),
                                size: 20,
                              ),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              items: _uomOptions.map((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (newUnit) {
                                if (newUnit != null) {
                                  setState(() {
                                    _detectedUnit = newUnit;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _isQuantityValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 12,
                      color: _isQuantityValid ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isQuantityValid
                          ? 'Verified by Optical Recognition Engine (${(_detectedConfidence * 100).toInt()}% conf) • Keyboard editing locked'
                          : 'Detection failed: Manual editing is strictly disabled',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Traceability Raw OCR Snippet
          if (_rawOcrText != null && _rawOcrText!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1A0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Traceability: $_rawOcrText',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 3. Retake Photo & Confirm and Save Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.glassBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFF59E0B)),
                    label: const Text('Retake Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: _retakeWeighing,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canConfirm ? const Color(0xFF10B981) : AppColors.surfaceLight,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                      disabledForegroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: canConfirm ? 3 : 0,
                    ),
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            canConfirm ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isConfirming
                          ? 'Saving to Ledger...'
                          : (canConfirm
                              ? 'Confirm and Save'
                              : (!_isWeighingStable && _selectedMode == 0
                                  ? 'Ambiguous — Retake Photo'
                                  : 'Retake to Confirm')),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: canConfirm ? _confirmAndSave : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single Item in the Confirmed Chocolate Ledger
  Widget _buildLedgerEntryTile(ChocolateOcrLedgerModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date, Time & Confirmed Badge
          Row(
            children: [
              // Date
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                item.formattedDate, // Strictly DD/MM/YYYY
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              // Time (12-hour format with AM/PM)
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                item.formattedTime, // Strictly hh:mm AM/PM
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Status Badge (CONFIRMED)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Middle Row: Product Description and Confirmed Quantity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.documentName != null && item.documentName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.documentName!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Confirmed Quantity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.displayQuantity,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    Text(
                      'READ-ONLY OCR',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Empty State for Ledger
  Widget _buildEmptyLedgerState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.speed_rounded, color: Color(0xFFF59E0B), size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'No Confirmed Entries Yet',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Capture a weighing indicator reading or scan a finished chocolate document above to record your first immutable ledger entry.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
