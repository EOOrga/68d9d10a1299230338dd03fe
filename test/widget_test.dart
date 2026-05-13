import 'package:drapier_philippe/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the operations dashboard and tab navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const DrapierPhilippeApp(screenshotModeOverride: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('DRAPIER PHILIPPE'), findsWidgets);
    expect(find.text('Arrivals today'), findsOneWidget);
    expect(find.text('Training average'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance queue'), findsOneWidget);
    expect(find.text('Main entrance'), findsOneWidget);
  });

  testWidgets('creates a local reservation record', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DrapierPhilippeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Northstar Group');
    await tester.enterText(find.byType(TextFormField).at(1), 'Boardroom B');
    await tester.enterText(find.byType(TextFormField).at(4), 'Projector check');
    await tester.tap(find.text('Save reservation'));
    await tester.pumpAndSettle();

    expect(find.text('Northstar Group'), findsOneWidget);
    expect(find.text('Boardroom B'), findsOneWidget);
  });

  testWidgets('advances training progress locally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const DrapierPhilippeApp(screenshotModeOverride: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    expect(find.text('88% complete'), findsOneWidget);

    await tester.tap(find.text('Advance').first);
    await tester.pumpAndSettle();

    expect(find.text('100% complete'), findsOneWidget);
  });
}
