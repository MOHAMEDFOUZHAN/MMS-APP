import 'package:flutter/material.dart';
import 'add_invoice_screen.dart';

/// RapidOCR Invoice Scanner with complete manual entry and fillable boxes.
/// Provides real-time OCR auto-fill directly into the inward purchase invoice form,
/// allowing users to verify, edit, and fill all boxes manually on the same page.
class OcrScanScreen extends StatelessWidget {
  final Map<String, dynamic>? initialOcrData;

  const OcrScanScreen({super.key, this.initialOcrData});

  @override
  Widget build(BuildContext context) {
    return AddInvoiceScreen(
      isOcrScanMode: true,
      initialOcrData: initialOcrData,
    );
  }
}
