import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';

import 'package:google_fonts/google_fonts.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService()
      : super(ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const teaProfile = UserProfileModel(
    id: 'tea-user-uuid',
    username: 'bm',
    fullName: 'Benchmark Tea Department',
    role: 'TEA_USER',
    permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
  );

  final artifactDir = r'C:\Users\fouzh\.gemini\antigravity-ide\brain\ca43b83e-af86-4c4e-b07e-751f23157e77';

  Future<void> saveScreenshot(GlobalKey key, String filename, WidgetTester tester) async {
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      File('$artifactDir\\$filename').writeAsBytesSync(bytes);
      File(filename).writeAsBytesSync(bytes);
    });
  }

  testWidgets('Capture screenshots of all 3 Tea user screens on phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => teaProfile),
          authNotifierProvider.overrideWith((ref) => MockAuthNotifier(
                AuthState(status: AuthStatus.authenticated, userEmail: 'bm@benchmarkmms.com'),
              )),
          connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
          transfersListProvider.overrideWith((ref, filter) async => <TransferModel>[]),
          batchesListProvider.overrideWith((ref, filter) async => <BatchModel>[]),
          dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: repKey,
            child: const HomeShell(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Screen 0: Transfers
    print('Capturing Screen 0: Transfers');
    await saveScreenshot(repKey, 'tea_screen_0_transfers.png', tester);

    // Switch to Screen 1: Storage
    print('Switching to Screen 1: Storage');
    await tester.tap(find.widgetWithText(InkWell, 'Storage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('Capturing Screen 1: Storage');
    await saveScreenshot(repKey, 'tea_screen_1_storage.png', tester);

    // Switch to Screen 2: Dispatch
    print('Switching to Screen 2: Dispatch');
    await tester.tap(find.widgetWithText(InkWell, 'Dispatch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('Capturing Screen 2: Dispatch');
    await saveScreenshot(repKey, 'tea_screen_2_dispatch.png', tester);

    print('SUCCESS: All 3 Tea screenshots captured on mobile!');
  });

  testWidgets('Capture screenshot of Tea user screen on tablet', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => teaProfile),
          authNotifierProvider.overrideWith((ref) => MockAuthNotifier(
                AuthState(status: AuthStatus.authenticated, userEmail: 'bm@benchmarkmms.com'),
              )),
          connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
          transfersListProvider.overrideWith((ref, filter) async => <TransferModel>[]),
          batchesListProvider.overrideWith((ref, filter) async => <BatchModel>[]),
          dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: repKey,
            child: const HomeShell(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    print('Capturing Tablet layout');
    await saveScreenshot(repKey, 'tea_tablet_layout.png', tester);
  });
}
