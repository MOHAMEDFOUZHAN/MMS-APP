import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/auth/login_screen.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';

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

  const teaProfile = UserProfileModel(
    id: 'tea-user-uuid',
    username: 'bm',
    fullName: 'Benchmark Tea Department',
    role: 'TEA_USER',
    permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
  );

  testWidgets('Capture Login and App Screen Mockups', (tester) async {
    // 1. Capture Login Screen
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final loginRepKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: loginRepKey,
            child: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Tea Login option is absent
    expect(find.text('Tea'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));

    RenderRepaintBoundary boundary = loginRepKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage();
    var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('tea_login_mode.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('Saved login_screen.png');

    // 2. Capture Tea Phone Layout (390 x 844)
    final phoneRepKey = GlobalKey();
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
            key: phoneRepKey,
            child: const HomeShell(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    boundary = phoneRepKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    image = await boundary.toImage();
    byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('tea_phone_screen.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('Saved tea_phone_screen.png');

    // 3. Capture Tea Tablet Layout (800 x 1280)
    tester.view.physicalSize = const Size(800, 1280);
    final tabletRepKey = GlobalKey();

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
            key: tabletRepKey,
            child: const HomeShell(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    boundary = tabletRepKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    image = await boundary.toImage();
    byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('tea_tablet_screen.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('Saved tea_tablet_screen.png');
  });
}
