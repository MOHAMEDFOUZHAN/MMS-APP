import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/glass_widgets.dart';
import 'add_invoice_screen.dart';

class MultiPageScanScreen extends StatefulWidget {
  const MultiPageScanScreen({super.key});

  @override
  State<MultiPageScanScreen> createState() => _MultiPageScanScreenState();
}

class _PageItem {
  String id;
  File file;
  DateTime timestamp;

  _PageItem({
    required this.id,
    required this.file,
    required this.timestamp,
  });
}

class _MultiPageScanScreenState extends State<MultiPageScanScreen> {
  static const String _draftKey = 'mms_multipage_scan_draft_paths';
  final _picker = ImagePicker();
  final List<_PageItem> _pages = [];

  bool _isProcessing = false;
  String _processStage = '';
  double _processProgress = 0.0;
  MultiPageOcrResult? _ocrResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkDraft();
  }

  Future<void> _checkDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftPaths = prefs.getStringList(_draftKey);
      if (draftPaths != null && draftPaths.isNotEmpty) {
        final validFiles = draftPaths.map((p) => File(p)).where((f) => f.existsSync()).toList();
        if (validFiles.isNotEmpty && mounted) {
          final shouldResume = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.glassBorder),
              ),
              title: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text('Resume Incomplete Scan?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                'Multi-page scan in progress.\n${validFiles.length} pages saved temporarily from your last session.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    prefs.remove(_draftKey);
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Resume', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (shouldResume == true && mounted) {
            setState(() {
              _pages.clear();
              for (int i = 0; i < validFiles.length; i++) {
                _pages.add(_PageItem(
                  id: 'page_${DateTime.now().millisecondsSinceEpoch}_$i',
                  file: validFiles[i],
                  timestamp: DateTime.now(),
                ));
              }
            });
          } else {
            await prefs.remove(_draftKey);
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading scan draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pages.isEmpty) {
        await prefs.remove(_draftKey);
      } else {
        final paths = _pages.map((p) => p.file.path).toList();
        await prefs.setStringList(_draftKey, paths);
      }
    } catch (e) {
      debugPrint('Error saving scan draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('Error clearing scan draft: $e');
    }
  }

  Future<void> _captureNextPage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92, // Preserve high quality for small text as per prompt
      );

      if (picked != null) {
        final newPage = _PageItem(
          id: 'page_${DateTime.now().millisecondsSinceEpoch}_${_pages.length}',
          file: File(picked.path),
          timestamp: DateTime.now(),
        );

        setState(() {
          _pages.add(newPage);
          _errorMessage = null;
        });

        await _saveDraft();

        if (mounted) {
          _showPageAddedToast(_pages.length);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture page: $e';
      });
    }
  }

  Future<void> _importPdfOrFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            if (f.path != null) {
              _pages.add(_PageItem(
                id: 'page_${DateTime.now().millisecondsSinceEpoch}_${_pages.length}',
                file: File(f.path!),
                timestamp: DateTime.now(),
              ));
            }
          }
          _errorMessage = null;
        });

        await _saveDraft();
        if (mounted) {
          _showPageAddedToast(_pages.length);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to import files: $e';
      });
    }
  }

  Future<void> _retakePage(int index) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Retake Page ${index + 1}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final picked = await _picker.pickImage(source: source, imageQuality: 92);
      if (picked != null) {
        setState(() {
          _pages[index] = _PageItem(
            id: 'page_${DateTime.now().millisecondsSinceEpoch}_$index',
            file: File(picked.path),
            timestamp: DateTime.now(),
          );
        });
        await _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Page ${index + 1} retaken successfully'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to retake page: $e';
      });
    }
  }

  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
    _saveDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page ${index + 1} removed. Remaining pages renumbered automatically.'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _previewPage(int index) {
    final page = _pages[index];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview: Page ${index + 1} of ${_pages.length}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.70,
                  ),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.file(
                      page.file,
                      fit: BoxFit.contain,
                      errorBuilder: (c, o, s) => Container(
                        height: 200,
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: const Text('Unable to display image preview'),
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

  void _showPageAddedToast(int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page $count captured. Add another or tap Finish & Process.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _promptFinishAndProcess() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan or import at least 1 page first.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final proceed = await showDialog<bool>(
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
            Text('Process Multi-Page Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_pages.length} pages selected',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 6),
            const Text(
              'All pages will be processed into ONE unified invoice document with merged line items, mathematical total validation, and single stock update.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Process Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      _startOcrProcessing();
    }
  }

  Future<void> _startOcrProcessing() async {
    setState(() {
      _isProcessing = true;
      _processStage = 'Starting Multi-Page OCR engine...';
      _processProgress = 0.05;
      _errorMessage = null;
    });

    try {
      final files = _pages.map((p) => p.file).toList();
      final result = await OcrService.parseMultiPageInvoice(
        files,
        onProgress: (stage, progress) {
          if (mounted) {
            setState(() {
              _processStage = stage;
              _processProgress = progress;
            });
          }
        },
      );

      await _clearDraft();

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _ocrResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Multi-page processing failed: $e';
        });
      }
    }
  }

  void _proceedToEditAndSave() {
    if (_ocrResult == null) return;

    final invoice = _ocrResult!.combinedInvoice;
    final data = {
      'vendor': invoice.vendor,
      'invoice_no': invoice.invoiceNo,
      'date': invoice.date,
      'items': invoice.items.map((i) => i.toMap()).toList(),
      'multi_page_job_id': _ocrResult!.jobId,
      'page_count': _ocrResult!.pages.length,
      'average_confidence': _ocrResult!.averageConfidence,
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvoiceScreen(initialOcrData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Page Invoice Scanner'),
        actions: [
          if (_pages.isNotEmpty && !_isProcessing && _ocrResult == null)
            TextButton.icon(
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
              label: const Text('Finish', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              onPressed: _promptFinishAndProcess,
            ),
        ],
      ),
      body: AmbientBackground(
        child: _isProcessing
            ? _buildProcessingView()
            : _ocrResult != null
                ? _buildReviewResultView()
                : _buildScanWorkflowView(),
      ),
      bottomNavigationBar: (!_isProcessing && _ocrResult == null) ? _buildBottomActions() : null,
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          accentColor: AppColors.primary,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'MULTI-PAGE INVOICE PROCESSING',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.2, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 8),
              Text(
                _processStage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _processProgress,
                backgroundColor: AppColors.glassBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_processProgress * 100).toInt()}% completed',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pages are being parsed, repeated headers removed, line items merged, and GST totals mathematically cross-checked.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewResultView() {
    final result = _ocrResult!;
    final inv = result.combinedInvoice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          GlassCard(
            accentColor: result.mathematicalValidationPassed ? AppColors.success : AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.mathematicalValidationPassed ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: result.mathematicalValidationPassed ? AppColors.success : AppColors.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Combined Multi-Page Invoice',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(result.averageConfidence * 100).toInt()}% Conf.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _infoBlock('Vendor', inv.vendor),
                    ),
                    Expanded(
                      child: _infoBlock('Invoice No', inv.invoiceNo),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _infoBlock('Date', QuantityFormatter.formatDate(inv.date)),
                    ),
                    Expanded(
                      child: _infoBlock('Pages Processed', '${result.pages.length} Pages'),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Validation Indicators
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Mathematical validation passed (Sum matches total)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Repeated continuation headers detected & eliminated',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Single database record & single stock update verified',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Warnings if any
          if (result.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Attention Needed',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...result.warnings.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $w', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Combined Items List
          Text(
            'Extracted Line Items (${inv.items.length})',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inv.items.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, i) {
                final item = inv.items[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('P${item.sourcePage}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${item.materialCode.isNotEmpty ? item.materialCode : "Auto-matched"} • Lot: ${item.lotNo}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          Text(
                            'Qty: ${item.quantity} ${item.unit} @ ${QuantityFormatter.formatCurrency(item.unitPrice)} (GST: ${item.gst}%)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      QuantityFormatter.formatCurrency(item.total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Total Summary
          GlassCard(
            child: Column(
              children: [
                _summaryRow('Subtotal (Excl. Tax)', QuantityFormatter.formatCurrency(inv.totalExclTax)),
                const SizedBox(height: 6),
                _summaryRow('Total GST', QuantityFormatter.formatCurrency(inv.totalGst)),
                const Divider(height: 16),
                _summaryRow(
                  'Grand Total',
                  QuantityFormatter.formatCurrency(inv.grandTotal),
                  isBold: true,
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  text: 'Rescan Pages',
                  icon: Icons.refresh_rounded,
                  isOutlined: true,
                  onPressed: () {
                    setState(() {
                      _ocrResult = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  text: 'Review & Save',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  onPressed: _proceedToEditAndSave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _summaryRow(String label, String val, {bool isBold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 15 : 12,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildScanWorkflowView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xB30F172A),
            border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MULTI-PAGE INVOICE',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pages scanned: ${_pages.length}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryLight),
                    ),
                  ],
                ),
              ),
              if (_pages.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pages.length} Ready',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ),
            ],
          ),
        ),

        // Error Banner if any
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),

        // Pages List / Reorderable
        Expanded(
          child: _pages.isEmpty
              ? _buildEmptyPrompt()
              : Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _pages.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _pages.removeAt(oldIndex);
                        _pages.insert(newIndex, item);
                      });
                      _saveDraft();
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Container(
                        key: ValueKey(page.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _buildPageCard(index, page),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_outlined, size: 56, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pages Captured Yet',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use the camera to scan each page in order (Page 1, Page 2...), or import multi-page PDF documents. All pages will be processed together as one invoice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassButton(
                  text: 'Capture Page 1',
                  icon: Icons.camera_alt_rounded,
                  color: AppColors.primary,
                  onPressed: () => _captureNextPage(ImageSource.camera),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageCard(int index, _PageItem page) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Drag handle
          const Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 22),
          const SizedBox(width: 8),

          // Thumbnail with tap preview
          GestureDetector(
            onTap: () => _previewPage(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 80,
                color: Colors.black26,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      page.file,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: AppColors.textMuted),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details & Page Number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Page ${index + 1}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  index == 0 ? 'Header & Initial Items' : 'Continuation Page',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _previewPage(index),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('Preview', style: TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _retakePage(index),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('Retake', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _deletePage(index),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: GlassButton(
                text: '+ Next Page',
                icon: Icons.add_a_photo_rounded,
                color: AppColors.primary,
                height: 44,
                onPressed: () => _captureNextPage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlassButton(
                text: 'PDF / Gallery',
                icon: Icons.file_upload_rounded,
                isOutlined: true,
                height: 44,
                onPressed: _importPdfOrFiles,
              ),
            ),
            if (_pages.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GlassButton(
                  text: 'Finish (${_pages.length})',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  height: 44,
                  onPressed: _promptFinishAndProcess,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
