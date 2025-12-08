import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/model_menu.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔥 เพิ่ม parameter: discount (ส่วนลด)
  Future<String> placeOrder(List<MenuItem> items, String tableNumber, String paymentMethod, String branchName, double discount) async {
    return await _db.runTransaction((transaction) async {
      
      // 1. อ่านข้อมูลที่จำเป็น (เหมือนเดิม)
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      // (ส่วนอ่านวัตถุดิบ... เหมือนเดิม ผมละไว้เพื่อความกระชับ)
      Map<String, DocumentSnapshot> ingredientSnapshots = {};
      Set<String> ingredientIdsToCheck = {};
      for (var item in items) {
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

      // 2. คำนวณสต๊อกและตัดยอด (เหมือนเดิม)
      Map<String, double> stockUpdates = {}; 
      ingredientSnapshots.forEach((id, snap) {
        if (snap.exists) {
          var data = snap.data() as Map<String, dynamic>;
          stockUpdates[id] = (data['currentStock'] ?? 0).toDouble();
        }
      });
      for (var item in items) {
        for (var recipeItem in item.recipe) {
          String id = recipeItem.ingredientId;
          if (stockUpdates.containsKey(id)) {
            stockUpdates[id] = stockUpdates[id]! - recipeItem.quantityUsed;
          }
        }
      }
      stockUpdates.forEach((id, newStock) {
        DocumentReference ref = _db.collection('ingredients').doc(id);
        transaction.update(ref, {'currentStock': newStock});
      });

      // 3. คำนวณราคา (เพิ่มส่วนลด)
      List<String> itemNames = items.map((e) => e.name).toList();
      double totalPrice = items.fold(0, (sum, item) => sum + item.price);
      
      // 🔥 คำนวณยอดสุทธิ (Net Price)
      double netPrice = totalPrice - discount;
      if (netPrice < 0) netPrice = 0; // กันติดลบ

      // 4. สร้าง ID
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

      // 5. บันทึกออเดอร์ (เพิ่ม field discount, netPrice)
      DocumentReference orderRef = _db.collection('orders').doc(runningId);
      transaction.set(orderRef, {
        'orderId': runningId,       
        'tableNumber': tableNumber, 
        'items': itemNames,         
        'totalPrice': netPrice,     // 🔥 บันทึกยอดที่ลดแล้วเป็นยอดขายจริง
        'originalPrice': totalPrice, // เก็บราคาเต็มไว้ดูเล่น
        'discount': discount,       // เก็บยอดส่วนลด
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