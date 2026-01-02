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
      
      // 1. อ่านตัวนับออเดอร์ (Counter)
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      int currentCount = 0;
      String lastDate = '';
      DateTime now = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(now); // ใช้สำหรับเช็ควันตัดรอบ

      if (counterSnapshot.exists && counterSnapshot.data() != null) {
        var data = counterSnapshot.data() as Map<String, dynamic>;
        currentCount = data['count'] ?? 0;
        lastDate = data['date'] ?? '';
      }

      // ถ้าวันเปลี่ยน ให้รีเซ็ตเลขเป็น 1, ถ้าวันเดิม ให้นับต่อ
      int newCount = (lastDate == todayStr) ? currentCount + 1 : 1;
      
      // --- สร้าง Order ID รูปแบบใหม่: YYYYMMDD-XXXX ---
      String datePrefix = DateFormat('yyyyMMdd').format(now); // 20251227
      String runningSuffix = newCount.toString().padLeft(4, '0'); // 0001
      String fullOrderId = "$datePrefix-$runningSuffix"; // 20251227-0001

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
      
      // --- WRITES (เขียนลง DB) ---

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
        // --- 🔥 คำนวณราคาโดยรวมส่วนต่าง (Price Adjustment) ---
        double itemPrice = cartItem.menu.price + cartItem.priceAdjustment;
        totalPrice += (itemPrice * cartItem.quantity);

        for (int i = 0; i < cartItem.quantity; i++) {
           String detail = "${cartItem.menu.name}";
           
           // --- 🔥 บันทึกประเภท (Type) ต่อท้ายชื่อ ---
           if (cartItem.type != 'ปกติ') {
             detail += " (${cartItem.type})";
           }
           
           bool showOption = (cartItem.sweetness != '-' && cartItem.sweetness != 'ปกติ (100%)') ||
                             (cartItem.milk != '-' && cartItem.milk != 'นมวัว');
           // ใช้ [] เพื่อแยกส่วน Option ให้ดูง่ายขึ้น
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

      // 6. อัปเดตสถานะโต๊ะ
      if (int.tryParse(tableNumber) != null) {
        DocumentReference tableRef = _db.collection('tables').doc(tableNumber);
        transaction.set(tableRef, {'id': tableNumber, 'status': 'occupied'}, SetOptions(merge: true));
      }

      return fullOrderId; 
    }).then((orderId) {
      // บันทึก Log แยก
      _logOrderUsage(cartItems, orderId, recorderName);
      return orderId;
    });
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