import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizzy_bistro_pos/main.dart';

void main() {
  testWidgets('orders and kitchen only receive an order after Save', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MizzyPosApp());
    expect(find.text('No saved orders yet'), findsOneWidget);
    await tester.tap(find.text('Classic Burger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(find.text('No saved orders yet'), findsOneWidget);

    await tester.tap(find.text('Cashier').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-order-button')));
    await tester.pumpAndSettle();
    expect(find.text('Order #1001'), findsOneWidget);
    expect(find.text('1 × Classic Burger'), findsOneWidget);

    await tester.tap(find.text('Kitchen').last);
    await tester.pumpAndSettle();
    expect(find.text('Order #1001'), findsOneWidget);
  });

  testWidgets('save is disabled when cart is empty', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MizzyPosApp());
    final button = tester.widget<FilledButton>(find.byKey(const Key('save-order-button')));
    expect(button.onPressed, isNull);
  });
}
