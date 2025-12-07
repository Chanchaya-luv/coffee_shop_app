import 'package:flutter/material.dart';
import '../models/model_menu.dart';

class CartItem {
  final MenuItem menu;
  int quantity;

  CartItem({required this.menu, this.quantity = 1});
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  // --- 🔥 เพิ่มตัวแปรเก็บเลข Order ล่าสุด ---
  String? _activeOrderId; 

  Map<String, CartItem> get items => _items;
  
  int get itemCount => _items.length; // นับจำนวนรายการ (เช่น 2 เมนู)

  // หรือถ้านับจำนวนแก้วรวม
  int get totalItemsCount {
    int count = 0;
    _items.forEach((key, item) {
      count += item.quantity;
    });
    return count;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.menu.price * cartItem.quantity;
    });
    return total;
  }

  // --- 🔥 Getter & Setter สำหรับ Order ID ---
  String? get activeOrderId => _activeOrderId;

  void setActiveOrder(String orderId) {
    _activeOrderId = orderId;
    notifyListeners(); // แจ้งเตือนหน้าจอให้แสดงปุ่มติดตาม
  }

  // --- ฟังก์ชันเดิม ---
  void addItem(MenuItem menu) {
    if (_items.containsKey(menu.id)) {
      _items.update(
        menu.id,
        (existing) => CartItem(
          menu: existing.menu,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        menu.id,
        () => CartItem(menu: menu),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String menuId) {
    if (!_items.containsKey(menuId)) return;
    if (_items[menuId]!.quantity > 1) {
      _items.update(
        menuId,
        (existing) => CartItem(
          menu: existing.menu,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(menuId);
    }
    notifyListeners();
  }
  
  int getQuantity(String menuId) {
    return _items.containsKey(menuId) ? _items[menuId]!.quantity : 0;
  }
  
  void updateQuantity(MenuItem menu, int change) {
    if (_items.containsKey(menu.id)) {
      int newQuantity = _items[menu.id]!.quantity + change;
      if (newQuantity > 0) {
        _items.update(
          menu.id,
          (existing) => CartItem(menu: existing.menu, quantity: newQuantity),
        );
      } else {
        _items.remove(menu.id);
      }
    } else if (change > 0) {
      _items.putIfAbsent(
        menu.id,
        () => CartItem(menu: menu, quantity: 1),
      );
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}