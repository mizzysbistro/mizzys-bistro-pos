import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Order persistence contract. The memory implementation is used by widget tests.
abstract interface class OrderStore {
  Future<List<PosOrder>> loadOrders();
  Future<void> saveOrder(PosOrder order);
  Future<void> updateOrderStatus(int orderNumber, String status);
}

/// Device-local SQLite storage. Saving an order and all its lines is one transaction.
class SqliteOrderStore implements OrderStore {
  SqliteOrderStore({DatabaseFactory? factory, this.databasePath})
      : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? databasePath;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = databasePath ??
        p.join(await _factory.getDatabasesPath(), 'mizzy_bistro_pos.db');
    _database = await _factory.openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders (
            number INTEGER PRIMARY KEY,
            service TEXT NOT NULL,
            total REAL NOT NULL CHECK (total >= 0),
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE order_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_number INTEGER NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT NOT NULL,
            category TEXT NOT NULL,
            unit_price REAL NOT NULL CHECK (unit_price >= 0),
            quantity INTEGER NOT NULL CHECK (quantity > 0),
            FOREIGN KEY (order_number) REFERENCES orders(number) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_order_lines_order_number ON order_lines(order_number)',
        );
      },
    );
    return _database!;
  }

  /// Closes this connection. The on-device app normally leaves the connection
  /// open for the lifetime of the process; tests close it to verify reopening.
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  @override
  Future<List<PosOrder>> loadOrders() async {
    final db = await _db;
    final rows = await db.query('orders', orderBy: 'number DESC');
    final orders = <PosOrder>[];
    for (final row in rows) {
      final number = row['number'] as int;
      final lineRows = await db.query(
        'order_lines',
        where: 'order_number = ?',
        whereArgs: [number],
        orderBy: 'id ASC',
      );
      final lines = lineRows.map((line) {
        final item = MenuItem(
          line['product_id'] as String,
          line['product_name'] as String,
          line['category'] as String,
          (line['unit_price'] as num).toDouble(),
        );
        return CartLine(item, quantity: line['quantity'] as int);
      }).toList();
      orders.add(
        PosOrder(
          number: number,
          lines: lines,
          total: (row['total'] as num).toDouble(),
          service: row['service'] as String,
          kitchenStatus: row['status'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }
    return orders;
  }

  @override
  Future<void> saveOrder(PosOrder order) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('orders', {
        'number': order.number,
        'service': order.service,
        'total': order.total,
        'status': order.kitchenStatus,
        'created_at': order.createdAt.toUtc().toIso8601String(),
      });
      for (final line in order.lines) {
        await txn.insert('order_lines', {
          'order_number': order.number,
          'product_id': line.item.id,
          'product_name': line.item.name,
          'category': line.item.category,
          'unit_price': line.item.price,
          'quantity': line.quantity,
        });
      }
    });
  }

  @override
  Future<void> updateOrderStatus(int orderNumber, String status) async {
    final db = await _db;
    final changed = await db.update(
      'orders',
      {'status': status},
      where: 'number = ?',
      whereArgs: [orderNumber],
    );
    if (changed != 1) {
      throw StateError('Order $orderNumber was not found in local storage.');
    }
  }
}

/// Isolated store for deterministic widget tests; production uses SQLite.
class MemoryOrderStore implements OrderStore {
  final List<PosOrder> _orders = [];

  @override
  Future<List<PosOrder>> loadOrders() async =>
      _orders.map(_copyOrder).toList();

  @override
  Future<void> saveOrder(PosOrder order) async {
    if (_orders.any((saved) => saved.number == order.number)) {
      throw StateError('Duplicate order number: ${order.number}');
    }
    _orders.insert(0, _copyOrder(order));
  }

  @override
  Future<void> updateOrderStatus(int orderNumber, String status) async {
    final index = _orders.indexWhere((order) => order.number == orderNumber);
    if (index == -1) throw StateError('Order $orderNumber does not exist.');
    _orders[index].kitchenStatus = status;
  }

  PosOrder _copyOrder(PosOrder order) => PosOrder(
        number: order.number,
        lines: order.lines
            .map((line) => CartLine(line.item, quantity: line.quantity))
            .toList(),
        total: order.total,
        service: order.service,
        kitchenStatus: order.kitchenStatus,
        createdAt: order.createdAt,
      );
}
