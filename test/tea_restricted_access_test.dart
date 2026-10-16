import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/app_update_service.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/dashboard_summary_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';
import 'package:mms_app/presentation/auth/login_screen.dart';

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

  const adminProfile = UserProfileModel(
    id: 'admin-uuid',
    username: 'admin',
    fullName: 'Factory Admin',
    role: 'ADMIN',
    permissions: ['*'],
  );

  group('1. Tea User Profile & Role Verification', () {
    test('Tea profile identifies as isTeaUser and not admin/owner', () {
      expect(teaProfile.isTeaUser, isTrue);
      expect(teaProfile.isAdmin, isFalse);
      expect(teaProfile.isOwner, isFalse);
      expect(teaProfile.username, 'bm');
    });

    test('Admin profile does not identify as isTeaUser', () {
      expect(adminProfile.isTeaUser, isFalse);
      expect(adminProfile.isAdmin, isTrue);
    });
  });

  group('2. Login Screen Department Toggle & Verification', () {
    testWidgets('Login screen provides Admin, Tea, Chocolate switches and Management Login', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify all 4 login options are present
      expect(find.text('Admin'), findsWidgets);
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Chocolate'), findsOneWidget);
      expect(find.text('Management Login'), findsOneWidget);

      // Default Admin state
      expect(find.text('Sign In to MMS'), findsOneWidget);

      // 2. Tap Tea mode
      await tester.tap(find.text('Tea'));
      await tester.pump();
      expect(find.text('Sign In as Tea User'), findsOneWidget);
      expect(find.text('Tea Department Sign In'), findsOneWidget);

      // 3. Tap Chocolate mode
      await tester.tap(find.text('Chocolate'));
      await tester.pump();
      expect(find.text('Sign In as Chocolate User'), findsOneWidget);
      expect(find.text('Chocolate Department Sign In'), findsOneWidget);

      // 4. Tap Admin mode back
      await tester.tap(find.text('Admin'));
      await tester.pump();
      expect(find.text('Sign In to MMS'), findsOneWidget);
    });
  });

  group('3. Device Access Enforcement for Tea User', () {
    testWidgets('Tea user on phone layout (390x844) can access permitted 3 modules', (tester) async {
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
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tea badge must appear in AppBar
      expect(find.text('TEA'), findsOneWidget);

      // Exactly 5 modules in navigation order: Transfer, Material Received, Consume, Storage, Dispatch
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Material Received'), findsOneWidget);
      expect(find.text('Consume'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);

      // Unauthorized modules must NOT exist in the Tea navigation
      expect(find.text('Invoices'), findsNothing);
      expect(find.text('Materials'), findsNothing);
      expect(find.text('Materials Master'), findsNothing);
      expect(find.text('Vendors'), findsNothing);
      expect(find.text('Stock Adjustment'), findsNothing);
      expect(find.text('Reports Hub'), findsNothing);
      expect(find.text('More'), findsNothing); // 'More' menu hidden for Tea user
      expect(find.byTooltip('MIRA AI Brain'), findsNothing);
      expect(find.byTooltip('Security Center'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
    });

    testWidgets('Tea user on tablet layout (800x1280) accesses 6 Tea modules in Navigation Rail', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
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
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tea badge must appear in AppBar
      expect(find.text('TEA'), findsWidgets);

      // Permitted 5 modules visible on tablet Navigation Rail & AppBar
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Transfer'), findsWidgets);
      expect(find.text('Material Received'), findsOneWidget);
      expect(find.text('Consume'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);

      // Unauthorized modules must NOT exist
      expect(find.text('Invoices'), findsNothing);
      expect(find.text('Materials'), findsNothing);
      expect(find.text('Reports Hub'), findsNothing);
      expect(find.byTooltip('MIRA AI Brain'), findsNothing);
      expect(find.byTooltip('Security Center'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
    });

    testWidgets('Admin user on tablet/desktop layout (800x1280) is NOT blocked', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSummary = DashboardSummaryModel.empty();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => adminProfile),
            dashboardSummaryProvider.overrideWith((ref) => mockSummary),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Admin is NOT blocked on tablet
      expect(find.text('Mobile Phone Access Only'), findsNothing);
      // Navigation rail is visible
      expect(find.text('Dashboard'), findsWidgets);
    });
  });

  group('4. Update Notification Announcement Tests', () {
    testWidgets('Update notification indicator dot is visible on bell icon and sheet displays announcement', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Set update info
      AppUpdateService.instance.updateAvailableNotifier.value = const AppVersionInfo(
        versionCode: 102,
        versionName: '1.0.2',
        apkUrl: 'https://example.com/update.apk',
        releaseNotes: 'Performance improvements and bug fixes',
        isMandatory: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => teaProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Notification bell indicator dot must be displayed for update
      expect(find.byKey(const ValueKey('app_update_indicator_dot')), findsOneWidget);

      // Tap notification bell icon to open NotificationsSheet
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // NotificationsSheet must display clear announcement: "A new application update is available."
      expect(find.text('A new application update is available.'), findsOneWidget);
      expect(find.text('v1.0.2'), findsOneWidget);

      // Clean up update notifier
      AppUpdateService.instance.updateAvailableNotifier.value = null;
    });
  });

  group('5. Zero-Latency Tea Layout & Sync Profile Fallback', () {
    testWidgets('HomeShell immediately displays 3 Tea pages even if profile is initially null (async loading)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Profile is null (simulating async loading frame)
            currentUserProfileProvider.overrideWith((ref) => null),
            // AuthNotifier has email bm@benchmarkmms.com
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(
                  AuthState(
                    status: AuthStatus.authenticated,
                    userEmail: 'bm@benchmarkmms.com',
                  ),
                )),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      await tester.pump();

      // Must immediately show Transfer, Material Received, Consume, Storage, Dispatch
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Material Received'), findsOneWidget);
      expect(find.text('Consume'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);

      // Must NEVER display unauthorized standard navigation
      expect(find.text('Invoices'), findsNothing);
      expect(find.text('Materials'), findsNothing);
    });
  });
}
