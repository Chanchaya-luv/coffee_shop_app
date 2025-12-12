import 'package:flutter/material.dart';
import '../models/model_menu.dart';

class CartItem {
  final MenuItem menu;
  int quantity;
  final String sweetness; 
  final String milk;      

  CartItem({
    required this.menu,
    this.quantity = 1,
    this.sweetness = 'ปกติ (100%)',
    this.milk = 'นมวัว',            
  });

  // Key สำหรับระบุตัวตนสินค้า (รวม Option)
  String get key => "${menu.id}_${sweetness}_$milk";
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _activeOrderId; 

  Map<String, CartItem> get items => _items;
  String? get activeOrderId => _activeOrderId;

  int get itemCount => _items.length; 

  int get totalItemsCount {
    int count = 0;
    _items.forEach((key, item) => count += item.quantity);
    return count;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.menu.price * cartItem.quantity;
    });
    return total;
  }

  void setActiveOrder(String orderId) {
    _activeOrderId = orderId;
    notifyListeners();
  }

  // เพิ่มสินค้า (จากหน้าเมนู)
  void addItem(MenuItem menu, {String sweetness = 'ปกติ (100%)', String milk = 'นมวัว'}) {
    String itemKey = "${menu.id}_${sweetness}_$milk";
    if (_items.containsKey(itemKey)) {
      _items[itemKey]!.quantity += 1;
    } else {
      _items[itemKey] = CartItem(
        menu: menu, 
        quantity: 1,
        sweetness: sweetness,
        milk: milk,
      );
    }
    notifyListeners();
  }

  // --- 🔥 ฟังก์ชันใหม่: เพิ่มจำนวน (ปุ่ม + ใน Checkout) ---
  void addQuantity(String itemKey) {
    if (_items.containsKey(itemKey)) {
      _items[itemKey]!.quantity += 1;
      notifyListeners();
    }
  }

  // --- 🔥 ฟังก์ชันใหม่: ลดจำนวน (ปุ่ม - ใน Checkout) ---
  void removeSingleItem(String itemKey) {
    if (!_items.containsKey(itemKey)) return;
    
    if (_items[itemKey]!.quantity > 1) {
      _items[itemKey]!.quantity -= 1;
    } else {
      _items.remove(itemKey); // ถ้าเหลือ 1 ให้ลบออก
    }
    notifyListeners();
  }

  // --- 🔥 ฟังก์ชันใหม่: ลบทิ้งทันที (ปุ่มถังขยะ) ---
  void removeItem(String itemKey) {
    if (_items.containsKey(itemKey)) {
      _items.remove(itemKey);
      notifyListeners();
    }
  }
  
  int getQuantity(String menuId) {
    // ฟังก์ชันนี้ใช้นับรวมทุก Option ของเมนู ID เดียวกัน
    int total = 0;
    _items.forEach((key, item) {
      if (item.menu.id == menuId) {
        total += item.quantity;
      }
    });
    return total;
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}