import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/presentation/invoices/ocr_scan_screen.dart';

void main() {
  group('RapidOCR Scan Screen — Editable Fields & Manual Boxes Test', () {
    testWidgets('1. OcrScanScreen renders OCR controls and all editable manual entry fields on the same page',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OcrScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify RapidOCR Scanner header and action buttons are present at top
      expect(find.text('RapidOCR Invoice Scanner'), findsOneWidget);
      expect(find.text('RapidOCR Scanner & Invoice Entry'), findsOneWidget);
      expect(find.text('Camera Scan'), findsOneWidget);
      expect(find.text('Gallery / PDF'), findsOneWidget);

      // Verify Header details fields are present on the same page
      expect(find.text('Invoice Details'), findsOneWidget);
      expect(find.text('Vendor / Supplier Name *'), findsOneWidget);
      expect(find.text('Invoice No *'), findsOneWidget);
      expect(find.text('Purchase ID'), findsOneWidget);
      expect(find.text('Invoice Date (DD/MM/YYYY) *'), findsOneWidget);
      expect(find.text('Remarks / Notes'), findsOneWidget);

      // Verify Line Item boxes are present and ready to fill
      expect(find.text('Line Items'), findsOneWidget);
      expect(find.text('Material Code *'), findsWidgets);
      expect(find.text('Description *'), findsWidgets);
      expect(find.text('Category'), findsWidgets);
      expect(find.text('UOM *'), findsWidgets);
      expect(find.text('Quantity *'), findsWidgets);
      expect(find.text('Unit Price (₹) *'), findsWidgets);
      expect(find.text('Discount %'), findsWidgets);
      expect(find.text('GST %'), findsWidgets);
      expect(find.text('IGST %'), findsWidgets);
      expect(find.text('Batch / Lot No'), findsWidgets);
      expect(find.text('Purchase Date (DD/MM/YYYY)'), findsWidgets);
      expect(find.text('Expiry Date'), findsWidgets);
      expect(find.text('Reorder Level'), findsWidgets);
      expect(find.text('Grade (Factory Spec)'), findsWidgets);

      // Verify Financial summary & Save button are present on the same page
      expect(find.text('Financial Calculation Summary'), findsOneWidget);
      expect(find.text('Save Inward Purchase'), findsOneWidget);
    });

    testWidgets('2. OcrScanScreen populates initialOcrData directly into editable boxes',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ocrData = {
        'vendor': 'SRI KRISHNA POLYMERS',
        'invoice_no': 'SKP/2026/099',
        'date': DateTime(2026, 10, 4),
        'round_off': 0.25,
        'items': [
          {
            'material_code': '101',
            'description': 'POLYPROPYLENE GRANULES',
            'quantity': 250.0,
            'unit': 'kg',
            'unit_price': 110.0,
            'discount_percentage': 5.0,
            'gst_percentage': 18.0,
            'igst_percentage': 0.0,
            'lot_no': 'LOT-CUSTOM-99',
            'category': 'Raw Material',
            'hsn_sac': '39021000',
            'grade': 'Virgin',
          }
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OcrScanScreen(initialOcrData: ocrData),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Vendor and Invoice No were populated in the text fields
      expect(find.text('SRI KRISHNA POLYMERS'), findsOneWidget);
      expect(find.text('SKP/2026/099'), findsOneWidget);

      // Verify the item fields were populated
      expect(find.text('101'), findsOneWidget);
      expect(find.text('POLYPROPYLENE GRANULES'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('110.0'), findsOneWidget);

      // Verify the user can interactively edit the populated fields
      await tester.enterText(find.widgetWithText(TextFormField, '110.0'), '115.0');
      await tester.pumpAndSettle();
      expect(find.text('115.0'), findsOneWidget);
    });
  });
}
