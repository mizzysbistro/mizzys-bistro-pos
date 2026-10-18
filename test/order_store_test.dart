import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mizzy_bistro_pos/models.dart';
import 'package:mizzy_bistro_pos/order_store.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('mizzy-pos-sqlite-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('order, lines, and kitchen status survive database reopen', () async {
    final path = p.join(tempDirectory.path, 'orders.db');
    final store = SqliteOrderStore(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final order = PosOrder(
      number: 1001,
      lines: [
        CartLine(menu[0], quantity: 2),
        CartLine(menu[3], quantity: 1),
      ],
      total: 467,
      service: 'Dine-in',
    );

    await store.saveOrder(order);
    await store.updateOrderStatus(1001, 'Ready');
    await store.close();

    final reopenedStore = SqliteOrderStore(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final loaded = await reopenedStore.loadOrders();

    expect(loaded, hasLength(1));
    expect(loaded.single.number, 1001);
    expect(loaded.single.service, 'Dine-in');
    expect(loaded.single.kitchenStatus, 'Ready');
    expect(loaded.single.total, 467);
    expect(loaded.single.lines, hasLength(2));
    expect(loaded.single.lines[0].item.id, 'burger');
    expect(loaded.single.lines[0].quantity, 2);
    expect(loaded.single.lines[1].item.id, 'fries');
    await reopenedStore.close();
  });

  test('a bad order line rolls back the order header transaction', () async {
    final store = SqliteOrderStore(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'rollback.db'),
    );
    final invalidOrder = PosOrder(
      number: 1002,
      lines: [CartLine(menu[0], quantity: 0)],
      total: 0,
    );

    await expectLater(store.saveOrder(invalidOrder), throwsA(anything));
    expect(await store.loadOrders(), isEmpty);
    await store.close();
  });
}
