import 'package:flutter/material.dart';
import '../models/model_menu.dart';

class CartItem {
  final MenuItem menu;
  int quantity;
  final String sweetness; 
  final String milk;
  
  // --- 🔥 เพิ่มตัวแปรใหม่ ---
  final String type;           // ร้อน, เย็น, ปั่น
  final double priceAdjustment; // -5, +5, +10

  CartItem({
    required this.menu,
    this.quantity = 1,
    this.sweetness = 'ปกติ (100%)',
    this.milk = 'นมวัว',
    this.type = 'เย็น',         // ค่าเริ่มต้น
    this.priceAdjustment = 5.0, // ค่าเริ่มต้น (เย็น +5)
  });

  // สร้าง Key ให้ไม่ซ้ำกันตามตัวเลือก
  String get key => "${menu.id}_${sweetness}_${milk}_$type";
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

  // --- 🔥 ปรับสูตรคำนวณราคารวม ---
  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      // ราคาต่อแก้ว = ราคาฐาน + ส่วนต่าง
      double itemPrice = cartItem.menu.price + cartItem.priceAdjustment;
      total += itemPrice * cartItem.quantity;
    });
    return total;
  }

  void setActiveOrder(String orderId) {
    _activeOrderId = orderId;
    notifyListeners();
  }

  // --- 🔥 อัปเดตฟังก์ชัน addItem รับค่า type และ priceAdjustment ---
  void addItem(MenuItem menu, {
    String sweetness = 'ปกติ (100%)', 
    String milk = 'นมวัว',
    String type = 'เย็น',
    double priceAdjustment = 5.0,
  }) {
    String itemKey = "${menu.id}_${sweetness}_${milk}_$type";
    
    if (_items.containsKey(itemKey)) {
      _items[itemKey]!.quantity += 1;
    } else {
      _items[itemKey] = CartItem(
        menu: menu, 
        quantity: 1,
        sweetness: sweetness,
        milk: milk,
        type: type,
        priceAdjustment: priceAdjustment,
      );
    }
    notifyListeners();
  }

  void addQuantity(String itemKey) {
    if (_items.containsKey(itemKey)) {
      _items[itemKey]!.quantity += 1;
      notifyListeners();
    }
  }

  void removeSingleItem(String itemKey) {
    if (!_items.containsKey(itemKey)) return;
    if (_items[itemKey]!.quantity > 1) {
      _items[itemKey]!.quantity -= 1;
    } else {
      _items.remove(itemKey); 
    }
    notifyListeners();
  }

  void removeItem(String itemKey) {
    if (_items.containsKey(itemKey)) {
      _items.remove(itemKey);
      notifyListeners();
    }
  }
  
  int getQuantity(String menuId) {
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