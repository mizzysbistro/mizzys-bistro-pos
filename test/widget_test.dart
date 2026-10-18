import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizzy_bistro_pos/main.dart';

void setTestSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('orders and kitchen receive an order only after Save and reload it', (tester) async {
    setTestSize(tester);
    final store = MemoryOrderStore();
    await tester.pumpWidget(MizzyPosApp(orderStore: store));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Mark ready'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);

    // Recreate the app around the same store to exercise load-at-startup behavior.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MizzyPosApp(orderStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(find.text('Order #1001'), findsOneWidget);
    expect(find.text('1 × Classic Burger'), findsOneWidget);
  });

  testWidgets('save is disabled when cart is empty', (tester) async {
    setTestSize(tester);
    await tester.pumpWidget(MizzyPosApp(orderStore: MemoryOrderStore()));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byKey(const Key('save-order-button')));
    expect(button.onPressed, isNull);
  });
}
