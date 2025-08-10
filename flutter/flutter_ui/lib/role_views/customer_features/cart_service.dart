// cart_service.dart
import 'package:flutter/material.dart';

class CartItem {
  final int id;
  final String name;
  final String genericName;
  final String dosageForm;
  final String image;
  final double price;
  int quantity;
  final bool isPromo;
  int promoQuantity;

  CartItem({
    required this.id,
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.image,
    required this.price,
    required this.quantity,
    this.isPromo = false,
    this.promoQuantity = 0,
  });

  double get totalPrice => price * quantity;
}

class CartService with ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  void addToCart(CartItem item) {
    // Find an existing item that is NOT a promo item
    final existingIndex = _items.indexWhere(
      (i) => i.id == item.id && !i.isPromo,
    );

    if (existingIndex >= 0) {
      // If a paid item exists, update its quantities
      final existingItem = _items[existingIndex];
      existingItem.quantity += item.quantity;
      if (item.isPromo) {
        // Only update promoQuantity if the incoming item is a promo
        existingItem.promoQuantity += item.quantity;
      }
      // If the incoming item is not a promo, promoQuantity is not changed.
    } else {
      // If no existing paid item, add a new one.
      final newItem = CartItem(
        id: item.id,
        name: item.name,
        genericName: item.genericName,
        dosageForm: item.dosageForm,
        image: item.image,
        price: item.price,
        quantity: item.quantity,
        isPromo: item.isPromo, // Use the promo status of the incoming item
        promoQuantity: item.isPromo ? item.quantity : 0, // Set promoQuantity based on the flag
      );
      _items.add(newItem);
    }
    notifyListeners();
  }

  int get totalPaidQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPromoQuantity =>
      _items.fold(0, (sum, item) => sum + item.promoQuantity);

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
  
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void decreaseQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      if (item.quantity > 1) {
        item.quantity--;
        if (item.isPromo) {
          item.promoQuantity--;
        }
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void increaseQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      item.quantity++;
      if (item.isPromo) {
        item.promoQuantity++;
      }
      notifyListeners();
    }
  }
}