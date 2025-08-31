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
  final int availableStock;

  CartItem({
    required this.id,
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.image,
    required this.price,
    required this.quantity,
    required this.availableStock,
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
    final existingIndex = _items.indexWhere(
      (i) => i.id == item.id && i.isPromo == item.isPromo,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
      _items[existingIndex].promoQuantity += item.promoQuantity;
    } else {
      _items.add(item);
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
      
      // We are adding one paid item and potentially one free item.
      final quantityAdded = item.isPromo ? 2 : 1; 

      // Check if the current total quantity plus the new quantity will exceed the stock
      if ((item.quantity + item.promoQuantity + quantityAdded) <= item.availableStock) {
        item.quantity++;
        if (item.isPromo) {
          item.promoQuantity++;
        }
        notifyListeners();
      } else {
        print("Cannot add more. Exceeded available stock of ${item.availableStock}");
      }
    }
  }
}
