import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/inventory_settings_model.dart';
import 'package:mms_app/data/models/owner_reporting_models.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/auth/login_screen.dart';
import 'package:mms_app/presentation/owner/owner_dashboard_screen.dart';
import 'package:mms_app/presentation/owner/owner_login_screen.dart';
import 'package:mms_app/presentation/owner/owner_shell_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_admin_section_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_chocolate_section_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_expiry_list_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_live_stock_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_out_of_stock_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_reorder_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_tea_section_screen.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/providers/inventory_settings_provider.dart';
import 'package:mms_app/presentation/providers/owner_providers.dart';
import 'package:mms_app/presentation/providers/tea_consumption_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';
import 'package:mms_app/presentation/tea/tea_consume_screen.dart';
import 'package:mms_app/presentation/tea/tea_material_received_screen.dart';
import 'package:mms_app/presentation/transfers/transfers_screen.dart';

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

class FakeTestInventorySettingsNotifier extends StateNotifier<AsyncValue<InventorySettingsModel>>
    implements InventorySettingsNotifier {
  FakeTestInventorySettingsNotifier()
      : super(const AsyncValue.data(InventorySettingsModel(
          invoiceMaterialExpiryAlertDays: 30,
          storageProductExpiryAlertDays: 30,
        )));
  @override
  Future<void> loadSettings() async {}
  @override
  Future<void> saveSettings({
    required int invoiceMaterialExpiryAlertDays,
    required int storageProductExpiryAlertDays,
  }) async {}
}

const testAdminProfile = UserProfileModel(
  id: 'admin-uuid',
  username: 'admin',
  fullName: 'Administrator',
  role: 'ADMIN',
  permissions: ['*'],
);

const testTeaProfile = UserProfileModel(
  id: 'tea-uuid',
  username: 'bm',
  fullName: 'Tea Department Terminal',
  role: 'TEA_USER',
  permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
);

const testChocolateProfile = UserProfileModel(
  id: 'choco-uuid',
  username: 'chocolate',
  fullName: 'Chocolate Department Terminal',
  role: 'CHOCOLATE_USER',
  permissions: ['chocolate.*', 'notifications.view'],
);

Widget createTestApp(Widget child, {UserProfileModel? profile, double textScale = 1.0}) {
  return ProviderScope(
    overrides: [
      currentUserProfileProvider.overrideWith((ref) => profile ?? testAdminProfile),
      authNotifierProvider.overrideWith((ref) => MockAuthNotifier(
            AuthState(status: AuthStatus.authenticated, userEmail: 'admin@benchmark.com'),
          )),
      connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
      inventorySettingsProvider.overrideWith((ref) => FakeTestInventorySettingsNotifier()),
      unreadNotificationsCountProvider.overrideWith((ref) => 0),
      transfersListProvider.overrideWith((ref, filter) async => <TransferModel>[]),
      batchesListProvider.overrideWith((ref, filter) async => <BatchModel>[]),
      dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
      teaMaterialReceivedListProvider.overrideWith((ref, filter) async => <TeaMaterialReceivedModel>[]),
      ownerLiveStockProvider.overrideWith((ref, search) async => <OwnerAdminLiveStockItem>[]),
      ownerOutOfStockReportProvider.overrideWith((ref, arg) async => <OwnerOutOfStockItem>[]),
      ownerReorderReportProvider.overrideWith((ref, arg) async => <OwnerReorderItem>[]),
      ownerExpiryReportProvider.overrideWith((ref, arg) async => <OwnerExpiryListItem>[]),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final viewports = <String, Size>{
    'small_mobile_320x568': const Size(320, 568),
    'standard_mobile_360x800': const Size(360, 800),
    'large_mobile_390x844': const Size(390, 844),
    'large_mobile_430x932': const Size(430, 932),
    'small_tablet_600x960': const Size(600, 960),
    'tablet_768x1024': const Size(768, 1024),
    'laptop_1366x768': const Size(1366, 768),
    'desktop_1920x1080': const Size(1920, 1080),
  };

  group('AUDIT: Login Screens across 8 viewports', () {
    for (final vp in viewports.entries) {
      testWidgets('OwnerLoginScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerLoginScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });

      testWidgets('LoginScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const LoginScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });
    }
  });

  group('AUDIT: Management Shell & Sections across 8 viewports', () {
    for (final vp in viewports.entries) {
      testWidgets('OwnerShellScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerShellScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });

      testWidgets('OwnerLiveStockScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerLiveStockScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });

      testWidgets('OwnerOutOfStockScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerOutOfStockScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });

      testWidgets('OwnerReorderScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerReorderScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });

      testWidgets('OwnerExpiryListScreen at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerExpiryListScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });
    }
  });

  group('AUDIT: Admin HomeShell across 8 viewports', () {
    for (final vp in viewports.entries) {
      testWidgets('Admin HomeShell at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const HomeShell(), profile: testAdminProfile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });
    }
  });

  group('AUDIT: Tea HomeShell across 8 viewports', () {
    for (final vp in viewports.entries) {
      testWidgets('Tea HomeShell at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const HomeShell(), profile: testTeaProfile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });
    }
  });

  group('AUDIT: Chocolate HomeShell across 8 viewports', () {
    for (final vp in viewports.entries) {
      testWidgets('Chocolate HomeShell at ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const HomeShell(), profile: testChocolateProfile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        expect(error, isNull, reason: 'Failed with error at ${vp.key}: $error');
      });
    }
  });

  group('AUDIT: Font Scaling 1.4x across Key Portals', () {
    for (final vp in [
      MapEntry('small_mobile_320x568', const Size(320, 568)),
      MapEntry('standard_mobile_360x800', const Size(360, 800)),
      MapEntry('tablet_768x1024', const Size(768, 1024)),
    ]) {
      testWidgets('OwnerLoginScreen at 1.4x font scale on ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerLoginScreen(), textScale: 1.4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });

      testWidgets('LoginScreen at 1.4x font scale on ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const LoginScreen(), textScale: 1.4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });

      testWidgets('OwnerShellScreen at 1.4x font scale on ${vp.key}', (tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const OwnerShellScreen(), textScale: 1.4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
