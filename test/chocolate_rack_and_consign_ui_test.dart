import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/storage/storage_screen.dart';
import 'package:mms_app/presentation/dispatch/add_dispatch_screen.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService()
      : super(ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const chocolateProfile = UserProfileModel(
    id: 'choc-user-uuid',
    username: 'chocolate',
    fullName: 'Chocolate Department',
    role: 'CHOCOLATE_USER',
    permissions: ['chocolate.*', 'storage.*', 'dispatch.*', 'notifications.view'],
  );

  const adminProfile = UserProfileModel(
    id: 'admin-user-uuid',
    username: 'admin',
    fullName: 'Administrator',
    role: 'ADMIN',
    permissions: ['admin.*', 'storage.*', 'dispatch.*'],
  );

  group('Chocolate Rack & Consign UI Field Verification Tests', () {
    testWidgets('1. Chocolate Add Rack Batch dialog omits Rack Location and Department Location', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => chocolateProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            batchesListProvider.overrideWith((ref, filter) async => <BatchModel>[]),
          ],
          child: const MaterialApp(
            home: StorageScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the "+ Add Rack" button
      final addRackBtn = find.text('Add Rack');
      expect(addRackBtn, findsOneWidget);
      await tester.tap(addRackBtn);
      await tester.pumpAndSettle();

      // Dialog title must be 'Add Rack Batch'
      expect(find.text('Add Rack Batch'), findsOneWidget);

      // Removed fields MUST NOT be present
      expect(find.text('Rack / Shelf Location'), findsNothing);
      expect(find.text('Department / Location'), findsNothing);
      expect(find.text('Select Department'), findsNothing);
      expect(find.text('e.g. RACK C-1, COLD SHELF B-2'), findsNothing);

      // Remaining fields MUST be present
      expect(find.text('Batch Number *'), findsOneWidget);
      expect(find.text('Product Name *'), findsOneWidget);
      expect(find.text('Expiry Date'), findsOneWidget);
      expect(find.text('Quantity Received *'), findsOneWidget);
      expect(find.text('UOM'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add to Rack'), findsOneWidget);
    });

    testWidgets('2. Chocolate Consign page omits Department field', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => chocolateProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
          ],
          child: const MaterialApp(
            home: AddDispatchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Department dropdown / field MUST NOT be present for chocolate user
      expect(find.text('Department'), findsNothing);

      // Destination Location / Customer MUST be preserved
      expect(find.text('Destination Location / Customer'), findsOneWidget);
      expect(find.text('Dispatch Remarks / Notes'), findsOneWidget);
      expect(find.text('Confirm Consignment'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('3. Admin Storage Batch dialog retains Rack Location and Department Location', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => adminProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            batchesListProvider.overrideWith((ref, filter) async => <BatchModel>[]),
          ],
          child: const MaterialApp(
            home: StorageScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final addStorageBtn = find.text('Add Storage');
      expect(addStorageBtn, findsOneWidget);
      await tester.tap(addStorageBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Storage Batch'), findsOneWidget);
      expect(find.text('Rack / Shelf Location'), findsOneWidget);
      expect(find.text('Department / Location'), findsOneWidget);
    });

    testWidgets('4. Admin Dispatch form retains Department field', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => adminProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
          ],
          child: const MaterialApp(
            home: AddDispatchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Department dropdown is present for Admin
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Destination Location / Customer'), findsOneWidget);
      expect(find.text('Save Dispatch'), findsOneWidget);
    });
  });
}
