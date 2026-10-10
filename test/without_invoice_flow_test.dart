import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/formatters/app_date_formatter.dart';
import 'package:mms_app/presentation/invoices/without_invoice_screen.dart';

void main() {
  group('WITHOUT INVOICE / DIRECT STOCK INWARD TESTS', () {
    test('1. Day-of-Year lot number generation matches user specifications', () {
      // 1 January -> Day 001
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 1)), '001');

      // 2 January -> Day 002
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 2)), '002');

      // 05/01/2026 -> Day of year = 005
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 1, 5)), '005');

      // 31/12/2026 -> Day of year = 365
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2026, 12, 31)), '365');

      // 31/12/2028 (leap year) -> Day of year = 366
      expect(AppDateFormatter.formatDayOfYearLot(DateTime(2028, 12, 31)), '366');
    });

    testWidgets('2. Without Invoice UI labels the field strictly as LOT NUMBER (never Batch Number)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WithoutInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Field label must be LOT NUMBER
      expect(find.text('LOT NUMBER'), findsOneWidget);

      // Must NOT be called "Batch Number" in Without Invoice raw material workflow
      expect(find.textContaining('Batch Number'), findsNothing);
      expect(find.textContaining('Assigned Lot / Batch Number'), findsNothing);

      // Verify that the lot number is auto-generated and displayed
      final todayLot = AppDateFormatter.formatDayOfYearLot(DateTime.now());
      expect(find.text(todayLot), findsOneWidget);
    });

    testWidgets('3. Material Search and Quantity inputs are present for minimal workflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WithoutInvoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Material search field is ready
      expect(find.textContaining('Search Material Code OR Description'), findsOneWidget);

      // Quantity input is present with quick add buttons
      expect(find.textContaining('Received Quantity'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);

      // Commit button exists
      expect(find.text('Commit Stock Inward'), findsOneWidget);
    });
  });
}
