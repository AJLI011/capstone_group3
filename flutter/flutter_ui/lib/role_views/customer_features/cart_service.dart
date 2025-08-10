// cart_service.dart
class CartItem {
  final int id;
  final String name;
  final String genericName;
  final String dosageForm;
  final String image;
  final double price;
  int quantity;
  final bool isPromo; // The property is non-nullable

  CartItem({
    required this.id,
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.image,
    required this.price,
    required this.quantity,
    this.isPromo = false, // The default value 'false' prevents the error
  });

  double get totalPrice => price * quantity;
}

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  void addToCart(CartItem item) {
    final existingIndex = _items.indexWhere(
      (i) => i.id == item.id && i.isPromo == item.isPromo, // Now checks both ID and isPromo
    );
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
  }

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  void clearCart() => _items.clear();
}