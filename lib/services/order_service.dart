import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart'; 

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 🔥 แก้ไข Signature: เพิ่ม memberId และ recorderName เป็น Optional ---
  Future<String> placeOrder(
    List<CartItem> cartItems, 
    String tableNumber, 
    String paymentMethod, 
    String branchName, 
    double discount, 
    [String? memberId, String? recorderName] // รับชื่อคนขาย (Optional)
  ) async {
    return await _db.runTransaction((transaction) async {
      
      // --- Phase 1: อ่านข้อมูล (Reads) ---
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      Map<String, DocumentSnapshot> ingredientSnapshots = {};
      Set<String> ingredientIdsToCheck = {};
      
      for (var cartItem in cartItems) {
        if (cartItem.menu.recipe.isNotEmpty) {
          for (var recipeItem in cartItem.menu.recipe) {
            if (recipeItem.ingredientId.isNotEmpty) ingredientIdsToCheck.add(recipeItem.ingredientId);
          }
        }
      }

      for (String ingId in ingredientIdsToCheck) {
        DocumentReference ref = _db.collection('ingredients').doc(ingId);
        DocumentSnapshot snap = await transaction.get(ref);
        ingredientSnapshots[ingId] = snap;
      }

      // --- Phase 2: คำนวณและเขียนข้อมูล (Writes) ---
      Map<String, double> stockUpdates = {}; 
      ingredientSnapshots.forEach((id, snap) {
        if (snap.exists) {
          var data = snap.data() as Map<String, dynamic>;
          stockUpdates[id] = (data['currentStock'] ?? 0).toDouble();
        }
      });

      // ตัดสต๊อก
      for (var cartItem in cartItems) {
        for (int i = 0; i < cartItem.quantity; i++) {
           for (var recipeItem in cartItem.menu.recipe) {
              String id = recipeItem.ingredientId;
              if (stockUpdates.containsKey(id)) {
                stockUpdates[id] = stockUpdates[id]! - recipeItem.quantityUsed;
              }
           }
        }
      }
      
      // บันทึกสต๊อกใหม่
      stockUpdates.forEach((id, newStock) {
        DocumentReference ref = _db.collection('ingredients').doc(id);
        transaction.update(ref, {'currentStock': newStock});
      });

      // สร้างเลข Order
      int currentCount = 0;
      String lastDate = '';
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (counterSnapshot.exists && counterSnapshot.data() != null) {
        var data = counterSnapshot.data() as Map<String, dynamic>;
        currentCount = data['count'] ?? 0;
        lastDate = data['date'] ?? '';
      }

      int newCount = (lastDate == todayStr) ? currentCount + 1 : 1;
      String runningId = newCount.toString().padLeft(4, '0');

      // บันทึกออเดอร์
      DocumentReference orderRef = _db.collection('orders').doc(runningId);
      List<String> itemNames = [];
      double totalPrice = 0;

      for (var cartItem in cartItems) {
        totalPrice += (cartItem.menu.price * cartItem.quantity);
        for (int i = 0; i < cartItem.quantity; i++) {
           String detail = "${cartItem.menu.name}";
           // เพิ่ม Option ต่อท้าย (ถ้ามี)
           bool showOption = (cartItem.sweetness != '-' && cartItem.sweetness != 'ปกติ (100%)') ||
                             (cartItem.milk != '-' && cartItem.milk != 'นมวัว');
           if (showOption) { detail += " (${cartItem.sweetness}, ${cartItem.milk})"; }
           itemNames.add(detail);
        }
      }
      
      double netPrice = totalPrice - discount;
      if (netPrice < 0) netPrice = 0;

      transaction.set(orderRef, {
        'orderId': runningId,       
        'tableNumber': tableNumber, 
        'items': itemNames,         
        'totalPrice': netPrice,     
        'originalPrice': totalPrice,
        'discount': discount,       
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'branchName': branchName,
        'recorder': recorderName ?? 'Unknown', // --- 🔥 บันทึกชื่อคนขาย ---
        'memberId': memberId, // บันทึก ID สมาชิก (ถ้ามี)
        'timestamp': FieldValue.serverTimestamp(), 
      });

      transaction.set(counterRef, {'count': newCount, 'date': todayStr});

      if (int.tryParse(tableNumber) != null) {
        DocumentReference tableRef = _db.collection('tables').doc(tableNumber);
        transaction.set(tableRef, {'id': tableNumber, 'status': 'occupied'}, SetOptions(merge: true));
      }

      return runningId; 
    }).then((orderId) {
      // เรียกฟังก์ชันบันทึก Log และส่งชื่อคนขายไปด้วย
      _logOrderUsage(cartItems, orderId, recorderName);
      return orderId;
    });
  }

  // --- 🔥 ฟังก์ชันบันทึก Log (รับ recorderName) ---
  Future<void> _logOrderUsage(List<CartItem> cartItems, String orderId, String? recorderName) async {
    // 1. รวบรวม ID วัตถุดิบ
    Set<String> ingredientIds = {};
    for (var item in cartItems) {
       for (var recipe in item.menu.recipe) {
          if (recipe.ingredientId.isNotEmpty) ingredientIds.add(recipe.ingredientId);
       }
    }

    if (ingredientIds.isEmpty) return;

    // 2. ดึงชื่อและสต๊อกล่าสุด
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
      print("Error fetching ingredient info: $e");
    }

    // 3. บันทึก Log (Batch)
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
               'recorder': recorderName ?? 'System', // --- 🔥 บันทึกชื่อคนขายใน Log ---
               'timestamp': FieldValue.serverTimestamp(),
             });
           }
        }
      }
    }
    await batch.commit();
  }
}