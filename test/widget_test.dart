import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/constants/factory_constants.dart';
import 'package:mms_app/main.dart';

void main() {
  testWidgets('BenchmarkMmsApp boot smoke test renders AuthGate', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BenchmarkMmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state before authentication shows Login Screen with app name and Sign In card
    expect(find.text(FactoryConstants.appName), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
