import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';
import 'package:mms_app/presentation/transfers/transfers_screen.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService()
      : super(ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teaProfile = UserProfileModel(
    id: 'tea-user-uuid',
    username: 'bm',
    fullName: 'Benchmark Tea Department',
    role: 'TEA_USER',
    permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
  );

  testWidgets('Test switching between Transfers, Storage, and Dispatch pages in Tea mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => teaProfile),
          connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
          // Override list providers with empty data
          transfersListProvider.overrideWith((ref, arg) => []),
          batchesListProvider.overrideWith((ref, arg) => []),
          dispatchesListProvider.overrideWith((ref, arg) => []),
        ],
        child: const MaterialApp(
          home: HomeShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Dashboard must NOT exist for Tea user
    expect(find.widgetWithText(InkWell, 'Dashboard'), findsNothing);

    // Initially Transfer tab is selected (screenIndex: 0)
    debugPrint('Checking Transfer tab...');
    final transferTab = find.widgetWithText(InkWell, 'Transfer');
    expect(transferTab, findsOneWidget);

    // Transfer screen is visible - New Transfer button is hidden for view-only Tea user
    expect(find.text('New Transfer'), findsNothing);
    expect(find.byType(TransfersScreen), findsOneWidget);

    // Tap Material Received
    debugPrint('Tapping Material Received tab...');
    final matRecTab = find.widgetWithText(InkWell, 'Material Received');
    expect(matRecTab, findsOneWidget);
    await tester.tap(matRecTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap Consume
    debugPrint('Tapping Consume tab...');
    final consumeTab = find.widgetWithText(InkWell, 'Consume');
    expect(consumeTab, findsOneWidget);
    await tester.tap(consumeTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Record Material Taken'), findsOneWidget);

    // Tap Storage
    debugPrint('Tapping Storage tab...');
    final storageTab = find.widgetWithText(InkWell, 'Storage');
    expect(storageTab, findsOneWidget);
    await tester.tap(storageTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Check if Storage screen is visible
    expect(find.text('Add Storage'), findsOneWidget);

    // Tap Dispatch
    debugPrint('Tapping Dispatch tab...');
    final dispatchTab = find.widgetWithText(InkWell, 'Dispatch');
    expect(dispatchTab, findsOneWidget);
    await tester.tap(dispatchTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Check if Dispatch screen is visible
    expect(find.text('Record Dispatch'), findsOneWidget);

    // Tap back to Transfer
    debugPrint('Tapping back to Transfer tab...');
    await tester.tap(transferTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('New Transfer'), findsNothing);
    expect(find.byType(TransfersScreen), findsOneWidget);
  });
}
