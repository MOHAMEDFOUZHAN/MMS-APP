import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/auth/login_screen.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';
import 'package:mms_app/shared/widgets/maple_pro_footer.dart';

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

  const adminProfile = UserProfileModel(
    id: 'admin-uuid',
    username: 'admin',
    fullName: 'Factory Admin',
    role: 'ADMIN',
    permissions: ['*'],
  );

  group('Maple Pro Branding & Typography Tests', () {
    testWidgets('1. MapleProFooter renders Powered by and MAPLE PRO with Calama font and logo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapleProFooter(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Powered by '), findsOneWidget);
      expect(find.text('MAPLE PRO'), findsOneWidget);

      final mapleText = tester.widget<Text>(find.text('MAPLE PRO'));
      expect(mapleText.style?.fontFamily, 'Calama');
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('2. LoginScreen displays MapleProFooter branding at bottom', (tester) async {
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

      expect(find.byType(MapleProFooter), findsOneWidget);
      expect(find.text('Powered by '), findsOneWidget);
      expect(find.text('MAPLE PRO'), findsOneWidget);
      expect(find.text('Management Login'), findsOneWidget);
    });

    testWidgets('3. HomeShell in Tea phone layout displays MapleProFooter', (tester) async {
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

      expect(find.byType(MapleProFooter), findsOneWidget);
      expect(find.text('Powered by '), findsOneWidget);
      expect(find.text('MAPLE PRO'), findsOneWidget);
    });

    testWidgets('4. HomeShell in Standard phone layout displays MapleProFooter', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => adminProfile),
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

      expect(find.byType(MapleProFooter), findsOneWidget);
      expect(find.text('Powered by '), findsOneWidget);
      expect(find.text('MAPLE PRO'), findsOneWidget);
    });
  });
}
