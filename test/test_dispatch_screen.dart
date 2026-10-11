import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/dispatch/dispatch_screen.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService()
      : super(ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Pump DispatchScreen directly', (tester) async {
    const teaProfile = UserProfileModel(
      id: 'tea-user-uuid',
      username: 'bm',
      fullName: 'Benchmark Tea Department',
      role: 'TEA_USER',
      permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => teaProfile),
          connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          dispatchesListProvider.overrideWith((ref, filter) async => <DispatchModel>[]),
        ],
        child: const MaterialApp(
          home: DispatchScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    print('DispatchScreen pumped successfully!');
    expect(find.byType(DispatchScreen), findsOneWidget);
  });
}
