import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/ocr_service.dart';

void main() {
  test('Pure Dart PDF text extraction and parsing on Rajan Spices.pdf', () {
    final file = File(r'd:\projects\MMS APP\OCR testing\Rajan Spices.pdf');
    expect(file.existsSync(), isTrue);

    final parsed = OcrService.parsePdfDocumentDirect(file);

    expect(parsed.vendor, contains('Rajan Spices'));
    expect(parsed.invoiceNo, '26');
    expect(parsed.gstin, '32ALAPH1132P1ZG');
    expect(parsed.items.isNotEmpty, isTrue);
    expect(parsed.items.first.description, contains('Cardamom'));
    expect(parsed.items.first.quantity, 105.0);
    expect(parsed.items.first.unitPrice, 3200.0);
    expect(parsed.grandTotal, 352800.0);
  });
}
