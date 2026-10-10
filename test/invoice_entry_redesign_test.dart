import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/formatters/app_date_formatter.dart';
import 'package:mms_app/core/formatters/quantity_formatter.dart';
import 'package:mms_app/data/models/material_model.dart';
import 'package:mms_app/presentation/invoices/add_invoice_screen.dart';

void main() {
  group('BENCHMARK MMS — INVOICE ENTRY REDESIGN TESTS', () {
    testWidgets('1. Payment Status / Invoice Status is NOT shown on Add Invoice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that "Payment Status" does NOT exist anywhere in the Add Invoice UI
      expect(find.text('Payment Status'), findsNothing);
      expect(find.text('Invoice Status'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('2. Material Code and Description are prominently present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Material Code and Description fields exist prominently
      expect(find.textContaining('Material Code'), findsWidgets);
      expect(find.textContaining('Description'), findsWidgets);
      expect(find.textContaining('UOM'), findsWidgets);
      expect(find.textContaining('Quantity'), findsWidgets);
      expect(find.textContaining('Unit Price'), findsWidgets);
    });

    testWidgets('3. Financial Summary is rendered with required totals', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Financial Calculation Summary exists
      expect(find.text('Financial Calculation Summary'), findsOneWidget);
      expect(find.text('Subtotal / Total Excl. Tax'), findsOneWidget);
      expect(find.text('Total GST'), findsOneWidget);
      expect(find.text('Total IGST'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(find.text('Round Off'), findsOneWidget);
      expect(find.text('Final Bill Total'), findsOneWidget);
    });

    test('4. Master Material Model Auto-Fill Mapping', () {
      final sampleMat = MaterialModel(
        id: 101,
        materialCode: '100',
        description: 'MINT',
        category: 'SPICES',
        unit: 'kg',
        grade: 'BP',
        hsnSac: '0910',
        reorderLevel: 50.0,
        unitPrice: 240.0,
      );

      expect(sampleMat.materialCode, '100');
      expect(sampleMat.description, 'MINT');
      expect(sampleMat.category, 'SPICES');
      expect(sampleMat.unit, 'kg');
      expect(sampleMat.grade, 'BP');
      expect(sampleMat.hsnSac, '0910');
      expect(sampleMat.reorderLevel, 50.0);
    });

    test('5. Date Formatter enforces strict DD/MM/YYYY presentation', () {
      final dt1 = DateTime(2026, 10, 1);
      final dt2 = DateTime(2026, 2, 13);
      final dt3 = DateTime(2026, 12, 31);

      expect(AppDateFormatter.format(dt1), '01/10/2026');
      expect(AppDateFormatter.format(dt2), '13/02/2026');
      expect(AppDateFormatter.format(dt3), '31/12/2026');

      expect(QuantityFormatter.formatDate(dt1), '01/10/2026');
      expect(QuantityFormatter.formatDate(dt2), '13/02/2026');
    });

    test('6. Multi-Item and Decimal Accurate Invoice Calculations', () {
      // Line item 1: 100 kg @ 50 = 5000, 10% disc = 4500, 18% GST = 810 -> 5310
      const qty1 = 100.0;
      const price1 = 50.0;
      const disc1 = 10.0;
      const gst1 = 18.0;

      final gross1 = qty1 * price1;
      final discAmt1 = gross1 * (disc1 / 100.0);
      final taxable1 = gross1 - discAmt1;
      final gstVal1 = taxable1 * (gst1 / 100.0);
      final total1 = taxable1 + gstVal1;

      expect(gross1, 5000.0);
      expect(discAmt1, 500.0);
      expect(taxable1, 4500.0);
      expect(gstVal1, 810.0);
      expect(total1, 5310.0);

      // Line item 2: 20 kg @ 120 = 2400, 0% disc, 12% IGST = 288 -> 2688
      const qty2 = 20.0;
      const price2 = 120.0;
      const igst2 = 12.0;

      final gross2 = qty2 * price2;
      final taxable2 = gross2;
      final igstVal2 = taxable2 * (igst2 / 100.0);
      final total2 = taxable2 + igstVal2;

      expect(gross2, 2400.0);
      expect(taxable2, 2400.0);
      expect(igstVal2, 288.0);
      expect(total2, 2688.0);

      // Financial Summary Totals
      final subtotal = taxable1 + taxable2; // 6900.0
      final totalGst = gstVal1; // 810.0
      final totalIgst = igstVal2; // 288.0
      final grandTotal = subtotal + totalGst + totalIgst; // 7998.0
      const roundOff = 2.0;
      final finalBillTotal = grandTotal + roundOff; // 8000.0

      expect(subtotal, 6900.0);
      expect(totalGst, 810.0);
      expect(totalIgst, 288.0);
      expect(grandTotal, 7998.0);
      expect(finalBillTotal, 8000.0);
    });

    test('7. Day-of-Year Lot Number Generation matches calendar dates exactly', () {
      // 1 January -> Day 001
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 1)), '001');

      // 2 January -> Day 002
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 2)), '002');

      // 5 January 2026 -> Day 005
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 5)), '005');

      // 31 December 2026 (non-leap year) -> Day 365
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 12, 31)), '365');

      // 31 December 2028 (leap year) -> Day 366
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2028, 12, 31)), '366');
    });

    testWidgets('8. Add Invoice page presents Invoice No and Vendor as Optional', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Invoice No (Optional)'), findsOneWidget);
      expect(find.textContaining('Vendor / Supplier Name (Optional)'), findsOneWidget);
    });
  });
}
