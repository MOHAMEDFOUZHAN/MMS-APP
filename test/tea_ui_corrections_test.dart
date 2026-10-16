import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/providers/tea_consumption_providers.dart';
import 'package:mms_app/presentation/tea/tea_material_received_screen.dart';
import 'package:mms_app/presentation/transfers/transfers_screen.dart';

void main() {
  group('Tea Portal - UI Corrections Tests', () {
    testWidgets('Tea Transfer page hides transfer history record cards while preserving search and controls', (tester) async {
      final mockTransfers = [
        TransferModel(
          id: 1,
          date: DateTime(2026, 10, 15, 12, 18),
          code: '213',
          description: 'CLOVE "B" GRADE',
          department: 'TEA',
          person: 'SUDHA',
          outward: 500,
          returnUnits: 0,
          units: 'g',
          lotNo: '287',
          allocations: [],
        ),
      ];

      // 1. In Tea Mode (departmentFilter: 'TEA'): Cards should be removed
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isTeaUserProvider.overrideWithValue(true),
            transfersListProvider.overrideWith((ref, filter) => Future.value(mockTransfers)),
          ],
          child: const MaterialApp(
            home: TransfersScreen(
              isEmbedded: true,
              readOnlyActions: true,
              departmentFilter: 'TEA',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // GlobalSearchFilterBar controls must exist
      expect(find.text('Search by Code, Description or Category'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      // Transfer-history record card UI elements must NOT be displayed
      expect(find.text('CLOVE "B" GRADE'), findsNothing);
      expect(find.text('Outward Issued'), findsNothing);
      expect(find.text('Returned In'), findsNothing);
      expect(find.text('Net Stock Impact'), findsNothing);
      expect(find.text('View'), findsNothing);
    });

    testWidgets('Non-Tea Transfer page continues to display transfer cards', (tester) async {
      final mockTransfers = [
        TransferModel(
          id: 2,
          date: DateTime(2026, 10, 15, 12, 18),
          code: 'CHOCO-01',
          description: 'DARK CHOCOLATE SLAB',
          department: 'CHOCOLATE',
          person: 'RAHUL',
          outward: 10,
          returnUnits: 0,
          units: 'kg',
          lotNo: '101',
          allocations: [],
        ),
      ];

      // In Chocolate/Admin mode: Cards should remain displayed
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isTeaUserProvider.overrideWithValue(false),
            isChocolateUserProvider.overrideWithValue(true),
            transfersListProvider.overrideWith((ref, filter) => Future.value(mockTransfers)),
          ],
          child: const MaterialApp(
            home: TransfersScreen(
              isEmbedded: true,
              readOnlyActions: true,
              departmentFilter: 'CHOCOLATE',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Transfer card elements must be visible for non-Tea
      expect(find.text('DARK CHOCOLATE SLAB'), findsOneWidget);
      expect(find.text('Outward Issued'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('Tea Material Received page hides the four summary cards while keeping material list intact', (tester) async {
      final mockItems = [
        const TeaMaterialReceivedModel(
          materialCode: 'TEA-101',
          description: 'GREEN TEA PREMIUM',
          category: 'RAW TEA',
          unit: 'kg',
          totalReceived: 279.14,
          totalConsumed: 70.0,
          totalReturned: 0.0,
          currentBalance: 209.14,
          stockStatus: 'IN_STOCK',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teaMaterialReceivedListProvider.overrideWith((ref, filter) => Future.value(mockItems)),
          ],
          child: const MaterialApp(
            home: TeaMaterialReceivedScreen(isEmbedded: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The 4 summary cards must NOT be displayed
      expect(find.text('Total Received'), findsNothing);
      expect(find.text('Total Consumed'), findsNothing);
      expect(find.text('Returned to Admin'), findsNothing);
      expect(find.text('Live Available'), findsNothing);

      // The material list item and details must continue working
      expect(find.text('CODE: TEA-101'), findsOneWidget);
      expect(find.text('GREEN TEA PREMIUM'), findsOneWidget);
      expect(find.text('Search by Code or Description'), findsOneWidget);
    });
  });
}
