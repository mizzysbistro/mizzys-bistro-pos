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
  PosOrder({
    required this.number,
    required this.lines,
    required this.total,
    this.service = 'Dine-in',
    this.kitchenStatus = 'New',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int number;
  final List<CartLine> lines;
  final double total;
  final String service;
  String kitchenStatus;
  final DateTime createdAt;
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
