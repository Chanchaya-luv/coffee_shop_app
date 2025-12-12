import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import CartProvider เพื่อใช้ Class CartItem
import '../providers/cart_provider.dart'; 

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 🔥 แก้ตรงนี้: รับ List<CartItem> แทน MenuItem ---
  Future<String> placeOrder(List<CartItem> cartItems, String tableNumber, String paymentMethod, String branchName, double discount) async {
    return await _db.runTransaction((transaction) async {
      
      // ... (Phase 1: อ่านข้อมูล - เหมือนเดิม) ...
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      Map<String, DocumentSnapshot> ingredientSnapshots = {};
      Set<String> ingredientIdsToCheck = {};
      
      // วนลูป CartItem เพื่อหาสูตร
      for (var cartItem in cartItems) {
        var item = cartItem.menu;
        if (item.recipe.isNotEmpty) {
          for (var recipeItem in item.recipe) {
            if (recipeItem.ingredientId.isNotEmpty) ingredientIdsToCheck.add(recipeItem.ingredientId);
          }
        }
      }

      for (String ingId in ingredientIdsToCheck) {
        DocumentReference ref = _db.collection('ingredients').doc(ingId);
        DocumentSnapshot snap = await transaction.get(ref);
        ingredientSnapshots[ingId] = snap;
      }

      // ... (Phase 2: คำนวณสต๊อก - เหมือนเดิม) ...
      Map<String, double> stockUpdates = {}; 
      ingredientSnapshots.forEach((id, snap) {
        if (snap.exists) {
          var data = snap.data() as Map<String, dynamic>;
          stockUpdates[id] = (data['currentStock'] ?? 0).toDouble();
        }
      });

      // ตัดสต๊อก (วนลูปตามจำนวนแก้ว)
      for (var cartItem in cartItems) {
        // ทำซ้ำตามจำนวน quantity
        for (int i = 0; i < cartItem.quantity; i++) {
           for (var recipeItem in cartItem.menu.recipe) {
              String id = recipeItem.ingredientId;
              if (stockUpdates.containsKey(id)) {
                stockUpdates[id] = stockUpdates[id]! - recipeItem.quantityUsed;
              }
           }
        }
      }
      
      // บันทึกสต๊อก
      stockUpdates.forEach((id, newStock) {
        DocumentReference ref = _db.collection('ingredients').doc(id);
        transaction.update(ref, {'currentStock': newStock});
      });

      // ... (คำนวณราคาและ ID - เหมือนเดิม) ...
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

      // --- 🔥 สร้างรายชื่อเมนูพร้อม Option (สำคัญ!) ---
      List<String> itemNames = [];
      double totalPrice = 0;

      for (var cartItem in cartItems) {
        // ราคารวม
        totalPrice += (cartItem.menu.price * cartItem.quantity);
        
        // สร้างชื่อ เช่น "ลาเต้ (หวาน 50%, นมโอ๊ต) x2"
        // หรือจะแยกเป็นบรรทัดก็ได้
        for (int i = 0; i < cartItem.quantity; i++) {
           String detail = "${cartItem.menu.name}";
           // ถ้ามี Option ให้วงเล็บต่อท้าย
           if (cartItem.sweetness != 'ปกติ (100%)' || cartItem.milk != 'นมวัว') {
              detail += " (${cartItem.sweetness}, ${cartItem.milk})";
           }
           itemNames.add(detail);
        }
      }
      
      double netPrice = totalPrice - discount;
      if (netPrice < 0) netPrice = 0;

      // บันทึกออเดอร์
      DocumentReference orderRef = _db.collection('orders').doc(runningId);
      transaction.set(orderRef, {
        'orderId': runningId,       
        'tableNumber': tableNumber, 
        'items': itemNames,         // รายชื่อพร้อม Option
        'totalPrice': netPrice,     
        'originalPrice': totalPrice,
        'discount': discount,       
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'branchName': branchName,
        'timestamp': FieldValue.serverTimestamp(), 
      });

      transaction.set(counterRef, {'count': newCount, 'date': todayStr});

      if (int.tryParse(tableNumber) != null) {
        DocumentReference tableRef = _db.collection('tables').doc(tableNumber);
        transaction.set(tableRef, {'id': tableNumber, 'status': 'occupied'}, SetOptions(merge: true));
      }

      return runningId; 
    });
  }
}