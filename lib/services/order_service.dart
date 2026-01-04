import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart'; 

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> placeOrder(
    List<CartItem> cartItems, 
    String tableNumber, 
    String paymentMethod, 
    String branchName, 
    double discount, 
    [String? memberId, String? recorderName]
  ) async {
    return await _db.runTransaction((transaction) async {
      
      // 1. อ่านตัวนับออเดอร์
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      int currentCount = 0;
      String lastDate = '';
      DateTime now = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(now);

      if (counterSnapshot.exists && counterSnapshot.data() != null) {
        var data = counterSnapshot.data() as Map<String, dynamic>;
        currentCount = data['count'] ?? 0;
        lastDate = data['date'] ?? '';
      }

      int newCount = (lastDate == todayStr) ? currentCount + 1 : 1;
      
      String datePrefix = DateFormat('yyyyMMdd').format(now); 
      String runningSuffix = newCount.toString().padLeft(4, '0');
      String fullOrderId = "$datePrefix-$runningSuffix"; 

      // 2. อ่านและเตรียมตัดสต๊อก
      Map<String, DocumentSnapshot> ingredientSnapshots = {};
      Set<String> ingredientIdsToCheck = {};
      for (var cartItem in cartItems) {
        for (var recipe in cartItem.menu.recipe) {
          if (recipe.ingredientId.isNotEmpty) ingredientIdsToCheck.add(recipe.ingredientId);
        }
      }

      for (String ingId in ingredientIdsToCheck) {
        DocumentReference ref = _db.collection('ingredients').doc(ingId);
        DocumentSnapshot snap = await transaction.get(ref);
        ingredientSnapshots[ingId] = snap;
      }

      Map<String, double> stockUpdates = {}; 
      ingredientSnapshots.forEach((id, snap) {
        if (snap.exists) {
           var data = snap.data() as Map<String, dynamic>;
           stockUpdates[id] = (data['currentStock'] ?? 0).toDouble();
        }
      });

      // คำนวณสต๊อกใหม่
      for (var cartItem in cartItems) {
        for (int i = 0; i < cartItem.quantity; i++) {
           for (var recipe in cartItem.menu.recipe) {
              String id = recipe.ingredientId;
              if (stockUpdates.containsKey(id)) {
                stockUpdates[id] = stockUpdates[id]! - recipe.quantityUsed;
              }
           }
        }
      }
      
      // --- WRITES ---

      // 3. อัปเดตตัวนับ
      transaction.set(counterRef, {
        'count': newCount, 
        'date': todayStr
      });

      // 4. อัปเดตสต๊อก
      stockUpdates.forEach((id, newStock) {
        DocumentReference ref = _db.collection('ingredients').doc(id);
        transaction.update(ref, {'currentStock': newStock});
      });

      // 5. สร้างออเดอร์ใหม่
      DocumentReference orderRef = _db.collection('orders').doc(fullOrderId);
      
      List<String> itemNames = [];
      double totalPrice = 0;

      for (var cartItem in cartItems) {
        double itemPrice = cartItem.menu.price + cartItem.priceAdjustment;
        totalPrice += (itemPrice * cartItem.quantity);

        for (int i = 0; i < cartItem.quantity; i++) {
           String detail = "${cartItem.menu.name}";
           
           if (cartItem.type != 'ปกติ') {
             detail += " (${cartItem.type})";
           }
           
           bool showOption = (cartItem.sweetness != '-' && cartItem.sweetness != 'ปกติ (100%)') ||
                             (cartItem.milk != '-' && cartItem.milk != 'นมวัว');
           if (showOption) { 
             detail += " [${cartItem.sweetness}, ${cartItem.milk}]"; 
           }
           
           itemNames.add(detail);
        }
      }
      double netPrice = totalPrice - discount;
      if (netPrice < 0) netPrice = 0;

      transaction.set(orderRef, {
        'orderId': fullOrderId,
        'tableNumber': tableNumber, 
        'items': itemNames,         
        'totalPrice': netPrice,     
        'originalPrice': totalPrice,
        'discount': discount,       
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'branchName': branchName,
        'recorder': recorderName ?? 'Unknown',
        'memberId': memberId,
        'timestamp': FieldValue.serverTimestamp(), 
      });

      if (int.tryParse(tableNumber) != null) {
        DocumentReference tableRef = _db.collection('tables').doc(tableNumber);
        transaction.set(tableRef, {'id': tableNumber, 'status': 'occupied'}, SetOptions(merge: true));
      }

      return fullOrderId; 
    }).then((orderId) {
      // บันทึก Log และ ยอดขายเมนู
      _logOrderUsage(cartItems, orderId, recorderName);
      _updateMenuSalesCount(cartItems); // 🔥 เพิ่มฟังก์ชันนี้
      return orderId;
    });
  }

  // --- 🔥 ฟังก์ชันอัปเดตยอดขายเมนู (Best Seller) ---
  Future<void> _updateMenuSalesCount(List<CartItem> cartItems) async {
    final batch = _db.batch();
    
    // รวมจำนวนสินค้าชนิดเดียวกันในออเดอร์เดียว
    Map<String, int> menuCounts = {};
    for (var item in cartItems) {
      // ถ้าเป็นสินค้าพิเศษ (Promo/Free/Gacha) อาจจะไม่นับรวม หรือจะนับก็ได้
      // ในที่นี้ให้นับเฉพาะสินค้าปกติ หรือ ID หลัก
      String menuId = item.menu.id.split('_')[0]; // ตัด _PROMO ออกเพื่อนับรวม
      menuCounts[menuId] = (menuCounts[menuId] ?? 0) + item.quantity;
    }

    menuCounts.forEach((menuId, quantity) {
      DocumentReference menuRef = _db.collection('menu_items').doc(menuId);
      // ใช้ FieldValue.increment เพื่อบวกจำนวนเข้าไป
      batch.update(menuRef, {'orderCount': FieldValue.increment(quantity)});
    });

    try {
      await batch.commit();
    } catch (e) {
      print("Error updating menu stats: $e");
      // ไม่ต้อง throw error เพราะไม่ใช่งานหลัก
    }
  }

  Future<void> _logOrderUsage(List<CartItem> cartItems, String orderId, String? recorderName) async {
    Set<String> ingredientIds = {};
    for (var item in cartItems) {
       for (var recipe in item.menu.recipe) {
          if (recipe.ingredientId.isNotEmpty) ingredientIds.add(recipe.ingredientId);
       }
    }
    if (ingredientIds.isEmpty) return;

    Map<String, String> ingredientNames = {};
    Map<String, double> ingredientStocks = {};
    try {
      for (String id in ingredientIds) {
         var doc = await _db.collection('ingredients').doc(id).get();
         if (doc.exists) {
            var data = doc.data()!;
            ingredientNames[id] = data['name'] ?? 'Unknown';
            ingredientStocks[id] = (data['currentStock'] ?? 0).toDouble(); 
         }
      }
    } catch (e) {
      print("Log Error: $e");
    }

    WriteBatch batch = _db.batch();
    for (var cartItem in cartItems) {
      for (int i = 0; i < cartItem.quantity; i++) {
        for (var recipe in cartItem.menu.recipe) {
           if (recipe.ingredientId.isNotEmpty) {
             String name = ingredientNames[recipe.ingredientId] ?? 'ID: ${recipe.ingredientId}';
             double remaining = ingredientStocks[recipe.ingredientId] ?? 0;
             DocumentReference logRef = _db.collection('stock_logs').doc();
             batch.set(logRef, {
               'ingredientName': name,
               'changeAmount': -recipe.quantityUsed, 
               'remainingStock': remaining,
               'reason': 'Order #$orderId (${cartItem.menu.name})',
               'recorder': recorderName ?? 'System',
               'timestamp': FieldValue.serverTimestamp(),
             });
           }
        }
      }
    }
    await batch.commit();
  }

  
}