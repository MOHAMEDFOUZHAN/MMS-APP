import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/glass_widgets.dart';
import 'add_invoice_screen.dart';

class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _picker = ImagePicker();
  File? _selectedFile;
  bool _isScanning = false;
  OcrParsedInvoice? _parsedInvoice;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedFile = File(picked.path);
          _isScanning = true;
          _errorMessage = null;
        });

        final result = await OcrService.parseInvoiceDocument(_selectedFile!);
        setState(() {
          _parsedInvoice = result;
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to process document: $e';
      });
    }
  }

  void _proceedToEditAndSave() {
    if (_parsedInvoice == null) return;

    final data = {
      'vendor': _parsedInvoice!.vendor,
      'invoice_no': _parsedInvoice!.invoiceNo,
      'date': _parsedInvoice!.date,
      'items': _parsedInvoice!.items.map((i) => i.toMap()).toList(),
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
        title: const Text('RapidOCR Invoice Scanner'),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions Card
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Purchase Invoices',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Capture a printed supplier tax invoice or upload an image. The OCR extracts quantities, line items, and GST for your verification.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capture Buttons
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      text: 'Camera Capture',
                      icon: Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      onPressed: _isScanning ? null : () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      text: 'Gallery / File',
                      icon: Icons.photo_library_rounded,
                      isOutlined: true,
                      onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Scanning State
              if (_isScanning)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: AppColors.primaryLight),
                        const SizedBox(height: 16),
                        Text(
                          'RapidOCR analyzing invoice lines & GST...',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error State
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),

              // Scanned Result Preview & Verification
              if (_parsedInvoice != null && !_isScanning) ...[
                Text(
                  'Extracted Data (Verify & Confirm)',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  accentColor: AppColors.success,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Detected Vendor', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  _parsedInvoice!.vendor,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('OCR Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Invoice No', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(_parsedInvoice!.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Invoice Date', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(QuantityFormatter.formatDate(_parsedInvoice!.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text('Recognized Line Items (${_parsedInvoice!.items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._parsedInvoice!.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text('Qty: ${item.quantity} ${item.unit} @ ${QuantityFormatter.formatCurrency(item.unitPrice)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Text(QuantityFormatter.formatCurrency(item.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          )),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(QuantityFormatter.formatCurrency(_parsedInvoice!.grandTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GlassButton(
                  text: 'Review & Commit Inward Stock',
                  height: 50,
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  onPressed: _proceedToEditAndSave,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
