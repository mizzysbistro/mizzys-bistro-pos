import 'package:flutter/material.dart';

void main() => runApp(const MizzyPosApp());

class MenuItem {
  const MenuItem(this.id, this.name, this.category, this.price);
  final String id;
  final String name;
  final String category;
  final double price;
}

class CartLine {
  CartLine(this.item, {this.quantity = 1});
  final MenuItem item;
  int quantity;
  double get total => item.price * quantity;
}

class PosOrder {
  PosOrder({required this.number, required this.lines, required this.total});
  final int number;
  final List<CartLine> lines;
  final double total;
  String kitchenStatus = 'New';
}

const menu = <MenuItem>[
  MenuItem('burger', 'Classic Burger', 'Meals', 189),
  MenuItem('chicken', 'Crispy Chicken', 'Meals', 219),
  MenuItem('pasta', 'Creamy Pasta', 'Meals', 175),
  MenuItem('fries', 'French Fries', 'Sides', 89),
  MenuItem('rice', 'Steamed Rice', 'Sides', 35),
  MenuItem('icedtea', 'Iced Tea', 'Drinks', 55),
  MenuItem('water', 'Bottled Water', 'Drinks', 30),
  MenuItem('coffee', 'Hot Coffee', 'Drinks', 65),
];

class MizzyPosApp extends StatelessWidget {
  const MizzyPosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Mizzy's Bistro POS",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
          scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        ),
        home: const PosHomePage(),
      );
}

class PosHomePage extends StatefulWidget {
  const PosHomePage({super.key});
  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> {
  final List<CartLine> _cart = [];
  final List<PosOrder> _orders = [];
  String _category = 'All';
  String _service = 'Dine-in';
  int _tab = 0;

  List<String> get _categories => ['All', ...menu.map((e) => e.category).toSet()];
  List<MenuItem> get _filtered => menu.where((e) => _category == 'All' || e.category == _category).toList();
  double get _subtotal => _cart.fold(0, (sum, line) => sum + line.total);

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

  void _save() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item before saving.')));
      return;
    }
    setState(() {
      final copiedLines = _cart.map((line) => CartLine(line.item, quantity: line.quantity)).toList();
      _orders.insert(0, PosOrder(number: _orders.isEmpty ? 1001 : _orders.first.number + 1, lines: copiedLines, total: _subtotal));
      _cart.clear();
      _tab = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved to Orders and Kitchen.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            CircleAvatar(backgroundColor: Color(0xFF176B55), foregroundColor: Colors.white, child: Icon(Icons.restaurant)),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Mizzy's Bistro", style: TextStyle(fontWeight: FontWeight.w800)),
              Text('POINT OF SALE', style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
            ]),
          ]),
          actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Chip(avatar: Icon(Icons.cloud_off, size: 16), label: Text('Local demo')))],
        ),
        body: _tab == 0 ? _cashier() : _orderList(kitchen: _tab == 2),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Cashier'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.soup_kitchen), label: 'Kitchen'),
          ],
        ),
      );

  Widget _cashier() => LayoutBuilder(builder: (context, constraints) {
        final menuPane = _menuPane();
        final cartPane = _cartPane();
        if (constraints.maxWidth < 760) {
          return Column(children: [Expanded(child: menuPane), SizedBox(height: 310, child: cartPane)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 6, child: menuPane), SizedBox(width: 370, child: cartPane)]);
      });

  Widget _menuPane() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New order', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const Text('Choose products, review your cart, then save.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _categories.map((c) => ChoiceChip(
              label: Text(c),
              selected: c == _category,
              onSelected: (_) => setState(() => _category = c),
            )).toList(),
          ),
          const SizedBox(height: 10),
          Expanded(child: GridView.builder(
            key: const Key('menu-grid'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 3 : 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.35),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final item = _filtered[index];
              return InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _add(item), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Icon(Icons.fastfood, color: Color(0xFF176B55), size: 28),
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2),
                Row(children: [Expanded(child: Text('₱${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))), const Icon(Icons.add_circle, color: Color(0xFF176B55))]),
              ]))));
            },
          )),
        ]),
      );

  Widget _cartPane() => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Color(0xFFE0E7E3)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('Current order', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const Spacer(), Text('${_cart.fold<int>(0, (sum, line) => sum + line.quantity)} items')]),
          Row(children: [const Text('Service'), const SizedBox(width: 12), DropdownButton<String>(value: _service, items: const [DropdownMenuItem(value: 'Dine-in', child: Text('Dine-in')), DropdownMenuItem(value: 'Takeaway', child: Text('Takeaway'))], onChanged: (v) => setState(() => _service = v ?? 'Dine-in'))]),
          const Divider(),
          Expanded(child: _cart.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_basket_outlined, size: 40, color: Colors.grey), Text('Your cart is empty'), Text('Tap a menu item to add it.')])) : ListView.builder(itemCount: _cart.length, itemBuilder: (context, i) {
            final line = _cart[i];
            return Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('₱${line.total.toStringAsFixed(2)}')])), IconButton(tooltip: 'Decrease quantity', onPressed: () => _quantity(line.item.id, -1), icon: const Icon(Icons.remove_circle_outline)), Text('${line.quantity}'), IconButton(tooltip: 'Increase quantity', onPressed: () => _quantity(line.item.id, 1), icon: const Icon(Icons.add_circle_outline))]);
          })),
          const Divider(),
          _summary('Subtotal', _subtotal),
          _summary('Tax', 0),
          _summary('Total', _subtotal, bold: true),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(key: const Key('save-order-button'), onPressed: _cart.isEmpty ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save order'))),
          const SizedBox(height: 4),
          const Text('Nothing reaches Orders or Kitchen until saved.', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      );

  Widget _summary(String label, double value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Text(label, style: style), const Spacer(), Text('₱${value.toStringAsFixed(2)}', style: style)]));
  }

  Widget _orderList({required bool kitchen}) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kitchen ? 'Kitchen display' : 'Orders', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(kitchen ? 'Only saved orders appear here.' : 'Saved orders from the cashier.'),
          const SizedBox(height: 16),
          Expanded(child: _orders.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(kitchen ? Icons.soup_kitchen : Icons.receipt_long, size: 48, color: Colors.grey), const SizedBox(height: 8), Text(kitchen ? 'Kitchen is clear' : 'No saved orders yet'), const Text('Create an order in Cashier and tap Save order.'), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => setState(() => _tab = 0), icon: const Icon(Icons.point_of_sale), label: const Text('Go to Cashier'))])) : ListView.separated(itemCount: _orders.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) {
            final order = _orders[i];
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('Order #${order.number}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const Spacer(), if (kitchen) Chip(label: Text(order.kitchenStatus)), Text('₱${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))]),
              const SizedBox(height: 8),
              ...order.lines.map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${line.quantity} × ${line.item.name}'))),
              if (kitchen) Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: order.kitchenStatus == 'Ready' ? null : () => setState(() => order.kitchenStatus = 'Ready'), child: Text(order.kitchenStatus == 'Ready' ? 'Ready' : 'Mark ready'))),
            ])));
          })),
        ]),
      );
}
