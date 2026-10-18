import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'order_store.dart';

export 'models.dart';
export 'order_store.dart';

void main() => runApp(const MizzyPosApp());

class MizzyPosApp extends StatelessWidget {
  const MizzyPosApp({super.key, this.orderStore});

  /// Tests inject a memory store. Real app use defaults to on-device SQLite.
  final OrderStore? orderStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Mizzy's Bistro POS",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
          scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        ),
        home: PosHomePage(orderStore: orderStore ?? SqliteOrderStore()),
      );
}

class PosHomePage extends StatefulWidget {
  const PosHomePage({super.key, required this.orderStore});

  final OrderStore orderStore;

  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> {
  final List<CartLine> _cart = [];
  final List<PosOrder> _orders = [];
  String _category = 'All';
  String _service = 'Dine-in';
  String? _storageError;
  int _tab = 0;
  bool _loadingOrders = true;
  bool _savingOrder = false;

  List<String> get _categories => ['All', ...menu.map((e) => e.category).toSet()];
  List<MenuItem> get _filtered =>
      menu.where((e) => _category == 'All' || e.category == _category).toList();
  double get _subtotal => _cart.fold(0, (sum, line) => sum + line.total);

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrders());
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _storageError = null;
    });
    try {
      final loaded = await widget.orderStore.loadOrders();
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(loaded);
        _loadingOrders = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOrders = false;
        _storageError = error.toString();
      });
    }
  }

  void _add(MenuItem item) => setState(() {
        final index = _cart.indexWhere((line) => line.item.id == item.id);
        if (index == -1) {
          _cart.add(CartLine(item));
        } else {
          _cart[index].quantity++;
        }
      });

  void _quantity(String id, int delta) => setState(() {
        final i = _cart.indexWhere((line) => line.item.id == id);
        if (i < 0) return;
        _cart[i].quantity += delta;
        if (_cart[i].quantity <= 0) _cart.removeAt(i);
      });

  Future<void> _save() async {
    if (_cart.isEmpty || _savingOrder || _loadingOrders || _storageError != null) {
      return;
    }
    final order = PosOrder(
      number: _orders.isEmpty ? 1001 : _orders.first.number + 1,
      lines: _cart
          .map((line) => CartLine(line.item, quantity: line.quantity))
          .toList(),
      total: _subtotal,
      service: _service,
    );
    setState(() => _savingOrder = true);
    try {
      // Store the header and every order line before clearing the cashier cart.
      await widget.orderStore.saveOrder(order);
      if (!mounted) return;
      setState(() {
        _orders.insert(0, order);
        _cart.clear();
        _tab = 1;
        _savingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved to this device.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order was not saved. Cart retained. $error')),
      );
    }
  }

  Future<void> _setKitchenStatus(PosOrder order) async {
    try {
      await widget.orderStore.updateOrderStatus(order.number, 'Ready');
      if (!mounted) return;
      setState(() => order.kitchenStatus = 'Ready');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update kitchen status: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            CircleAvatar(
              backgroundColor: Color(0xFF176B55),
              foregroundColor: Colors.white,
              child: Icon(Icons.restaurant),
            ),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Mizzy's Bistro", style: TextStyle(fontWeight: FontWeight.w800)),
              Text('POINT OF SALE', style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
            ]),
          ]),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.phone_android, size: 16),
                label: Text('On-device'),
              ),
            ),
          ],
        ),
        body: _loadingOrders
            ? const Center(child: CircularProgressIndicator())
            : _storageError != null
                ? _storageFailure()
                : _tab == 0
                    ? _cashier()
                    : _orderList(kitchen: _tab == 2),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) {
            if (!_loadingOrders && _storageError == null) {
              setState(() => _tab = value);
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Cashier'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.soup_kitchen), label: 'Kitchen'),
          ],
        ),
      );

  Widget _storageFailure() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Local order storage could not be opened.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('No new order will be accepted until storage is available. $_storageError'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(_loadOrders()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry storage'),
              ),
            ],
          ),
        ),
      );

  Widget _cashier() => LayoutBuilder(builder: (context, constraints) {
        final menuPane = _menuPane();
        final cartPane = _cartPane();
        if (constraints.maxWidth < 760) {
          return Column(
            children: [Expanded(child: menuPane), SizedBox(height: 310, child: cartPane)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: menuPane),
            SizedBox(width: 370, child: cartPane),
          ],
        );
      });

  Widget _menuPane() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New order',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Text('Choose products, review your cart, then save.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _categories
                  .map((c) => ChoiceChip(
                        label: Text(c),
                        selected: c == _category,
                        onSelected: (_) => setState(() => _category = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                key: const Key('menu-grid'),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _add(item),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.fastfood, color: Color(0xFF176B55), size: 28),
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 2,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '₱${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const Icon(Icons.add_circle, color: Color(0xFF176B55)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _cartPane() => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE0E7E3))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_cart.fold<int>(0, (sum, line) => sum + line.quantity)} items',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Service'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _service,
                  items: const [
                    DropdownMenuItem(value: 'Dine-in', child: Text('Dine-in')),
                    DropdownMenuItem(value: 'Takeaway', child: Text('Takeaway')),
                  ],
                  onChanged: (v) => setState(() => _service = v ?? 'Dine-in'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 40, color: Colors.grey),
                          Text('Your cart is empty'),
                          Text('Tap a menu item to add it.'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, i) {
                        final line = _cart[i];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('₱${line.total.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Decrease quantity',
                              onPressed: () => _quantity(line.item.id, -1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${line.quantity}'),
                            IconButton(
                              tooltip: 'Increase quantity',
                              onPressed: () => _quantity(line.item.id, 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(),
            _summary('Subtotal', _subtotal),
            _summary('Tax', 0),
            _summary('Total', _subtotal, bold: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('save-order-button'),
                onPressed: _cart.isEmpty || _savingOrder ? null : _save,
                icon: _savingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_savingOrder ? 'Saving…' : 'Save order'),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Orders appear after Save. Stored on this device only.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      );

  Widget _summary(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text('₱${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _orderList({required bool kitchen}) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kitchen ? 'Kitchen display' : 'Orders',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(kitchen ? 'Only saved orders appear here.' : 'Saved orders from this device.'),
            const SizedBox(height: 16),
            Expanded(
              child: _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(kitchen ? Icons.soup_kitchen : Icons.receipt_long, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(kitchen ? 'Kitchen is clear' : 'No saved orders yet'),
                          const Text('Create an order in Cashier and tap Save order.'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _tab = 0),
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('Go to Cashier'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final order = _orders[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Order #${order.number}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                    ),
                                    Chip(label: Text(order.service)),
                                    if (kitchen) Chip(label: Text(order.kitchenStatus)),
                                    Text(
                                      '₱${order.total.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...order.lines.map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('${line.quantity} × ${line.item.name}'),
                                  ),
                                ),
                                if (kitchen)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonal(
                                      onPressed: order.kitchenStatus == 'Ready'
                                          ? null
                                          : () => unawaited(_setKitchenStatus(order)),
                                      child: Text(order.kitchenStatus == 'Ready' ? 'Ready' : 'Mark ready'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}
