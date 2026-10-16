import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/presentation/owner/owner_login_screen.dart';

void main() {
  Widget createTestWidget({
    Size screenSize = const Size(390, 844),
    double textScale = 1.0,
    double bottomInset = 0.0,
    EdgeInsets padding = const EdgeInsets.only(top: 44, bottom: 34),
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            padding: padding,
            viewInsets: EdgeInsets.only(bottom: bottomInset),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const OwnerLoginScreen(),
        ),
      ),
    );
  }

  group('Owner Login Responsive Phone Breakpoints Tests', () {
    final phoneSizes = <String, Size>{
      '320x568 (Small Phone)': const Size(320, 568),
      '360x640 (Compact Android)': const Size(360, 640),
      '360x800 (Normal Android)': const Size(360, 800),
      '375x812 (iPhone X/12 Mini)': const Size(375, 812),
      '390x844 (Standard Phone)': const Size(390, 844),
      '393x873 (Pixel 7/8)': const Size(393, 873),
      '412x915 (Pixel Pro)': const Size(412, 915),
      '430x932 (Large Phone)': const Size(430, 932),
    };

    for (final entry in phoneSizes.entries) {
      testWidgets('Renders cleanly on ${entry.key} without any overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: entry.value));
        await tester.pumpAndSettle();

        // Verify key widgets are present
        expect(find.text('BENCHMARK MMS'), findsOneWidget);
        expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);
        expect(find.text('MANAGEMENT USERNAME / ID'), findsOneWidget);
        expect(find.text('PASSWORD'), findsOneWidget);
        expect(find.text('SIGN IN'), findsOneWidget);
        expect(find.text('Authorized management access only.'), findsOneWidget);
        expect(find.text('Operator Login'), findsOneWidget);

        // Verify no RenderFlex errors occurred
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Owner Login Landscape Mode Tests', () {
    final landscapeSizes = <String, Size>{
      '800x360 (Phone Landscape)': const Size(800, 360),
      '844x390 (Standard Landscape)': const Size(844, 390),
      '932x430 (Large Phone Landscape)': const Size(932, 430),
    };

    for (final entry in landscapeSizes.entries) {
      testWidgets('Renders and scrolls in landscape on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(
          screenSize: entry.value,
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 10),
        ));
        await tester.pumpAndSettle();

        expect(find.text('BENCHMARK MMS'), findsOneWidget);
        expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);

        // In landscape, verify scrollable to the bottom without overflow
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
        await tester.pumpAndSettle();

        expect(find.text('SIGN IN'), findsOneWidget);
        expect(find.text('Authorized management access only.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Owner Login Tablet Breakpoints Tests', () {
    final tabletSizes = <String, Size>{
      '600x960 (7-inch Tablet Portrait)': const Size(600, 960),
      '800x1280 (10-inch Tablet Portrait)': const Size(800, 1280),
      '1280x800 (10-inch Tablet Landscape)': const Size(1280, 800),
    };

    for (final entry in tabletSizes.entries) {
      testWidgets('Renders centered and constrained on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: entry.value));
        await tester.pumpAndSettle();

        expect(find.text('BENCHMARK MMS'), findsOneWidget);
        expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);
        expect(find.text('SIGN IN'), findsOneWidget);

        // Check that the form card does not stretch across the entire width
        final cardFinder = find.byType(Form);
        expect(cardFinder, findsOneWidget);
        final cardSize = tester.getSize(cardFinder);
        expect(cardSize.width, lessThanOrEqualTo(420.0));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Owner Login Keyboard & View Insets Tests', () {
    testWidgets('Stays completely usable when keyboard opens on 320x568 small phone', (tester) async {
      const size = Size(320, 568);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Keyboard opening with 260dp height
      await tester.pumpWidget(createTestWidget(
        screenSize: size,
        bottomInset: 260,
      ));
      await tester.pumpAndSettle();

      expect(find.text('BENCHMARK MMS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll to ensure button is reachable
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('SIGN IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stays completely usable when keyboard opens on 360x800 normal phone', (tester) async {
      const size = Size(360, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Keyboard opening with 300dp height
      await tester.pumpWidget(createTestWidget(
        screenSize: size,
        bottomInset: 300,
      ));
      await tester.pumpAndSettle();

      expect(find.text('BENCHMARK MMS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll to sign in
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(find.text('SIGN IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Owner Login Font Scaling & Error State Tests', () {
    testWidgets('Renders without overflow at large accessibility font scaling 1.4x', (tester) async {
      const size = Size(360, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(
        screenSize: size,
        textScale: 1.4,
      ));
      await tester.pumpAndSettle();

      expect(find.text('BENCHMARK MMS'), findsOneWidget);
      expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Form validation displays error text cleanly without overflow', (tester) async {
      const size = Size(360, 640);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(screenSize: size));
      await tester.pumpAndSettle();

      // Clear the email field and submit empty to trigger errors
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, '');
      await tester.pumpAndSettle();

      final signInButton = find.text('SIGN IN');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Expect validation error text
      expect(find.text('Please enter username or ID'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
