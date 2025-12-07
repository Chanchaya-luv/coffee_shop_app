import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/model_menu.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> placeOrder(List<MenuItem> items, String tableNumber, String paymentMethod, String s) async {
    return await _db.runTransaction((transaction) async {
      
      // ====================================================
      // 🟢 PHASE 1: อ่านข้อมูลที่จำเป็นทั้งหมดก่อน (Reads)
      // ====================================================

      // 1.1 อ่านตัวนับเลข (Order Counter)
      DocumentReference counterRef = _db.collection('metadata').doc('order_counter');
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      // 1.2 อ่านข้อมูลวัตถุดิบทั้งหมดที่ต้องใช้ (Ingredients)
      // (เก็บ Snapshot ไว้ใน Map เพื่อเอาไปคำนวณทีหลัง)
      Map<String, DocumentSnapshot> ingredientSnapshots = {};
      
      // รวบรวม ID วัตถุดิบทั้งหมดที่ไม่ซ้ำกันก่อน
      Set<String> ingredientIdsToCheck = {};
      for (var item in items) {
        if (item.recipe.isNotEmpty) {
          for (var recipeItem in item.recipe) {
            if (recipeItem.ingredientId.isNotEmpty) {
              ingredientIdsToCheck.add(recipeItem.ingredientId);
            }
          }
        }
      }

      // วนลูปอ่านข้อมูลวัตถุดิบ (Read Only)
      for (String ingId in ingredientIdsToCheck) {
        DocumentReference ref = _db.collection('ingredients').doc(ingId);
        DocumentSnapshot snap = await transaction.get(ref); // อ่านแล้วเก็บไว้
        ingredientSnapshots[ingId] = snap;
      }

      // ====================================================
      // 🔴 PHASE 2: คำนวณและบันทึกข้อมูล (Writes)
      // ====================================================

      // 2.1 คำนวณสต๊อกใหม่ใน Memory (ยังไม่บันทึก)
      Map<String, double> stockUpdates = {}; 

      // เริ่มต้นด้วยค่าสต๊อกปัจจุบันจากที่อ่านมา
      ingredientSnapshots.forEach((id, snap) {
        if (snap.exists) {
          var data = snap.data() as Map<String, dynamic>;
          stockUpdates[id] = (data['currentStock'] ?? 0).toDouble();
        }
      });

      // วนลูปตัดยอดจาก Memory
      for (var item in items) {
        for (var recipeItem in item.recipe) {
          String id = recipeItem.ingredientId;
          if (stockUpdates.containsKey(id)) {
            // ตัดยอดสะสม
            stockUpdates[id] = stockUpdates[id]! - recipeItem.quantityUsed;
          }
        }
      }

      // 2.2 บันทึกค่าสต๊อกใหม่ลง Database (Write จริง)
      stockUpdates.forEach((id, newStock) {
        DocumentReference ref = _db.collection('ingredients').doc(id);
        transaction.update(ref, {'currentStock': newStock});
      });

      // 2.3 คำนวณเลข Order ID (จากที่อ่านมาในข้อ 1.1)
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

      // 2.4 สร้างและบันทึกออเดอร์ (Write)
      DocumentReference orderRef = _db.collection('orders').doc(runningId); // ใช้ runningId เป็น Doc ID
      List<String> itemNames = items.map((e) => e.name).toList();
      double totalPrice = items.fold(0, (sum, item) => sum + item.price);

      transaction.set(orderRef, {
        'orderId': runningId,       
        'tableNumber': tableNumber, 
        'items': itemNames,         
        'totalPrice': totalPrice,   
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'timestamp': FieldValue.serverTimestamp(), 
      });

      // 2.5 บันทึกตัวนับเลขใหม่ (Write)
      transaction.set(counterRef, {
        'count': newCount,
        'date': todayStr
      });

      // 2.6 อัปเดตสถานะโต๊ะ (Write)
      if (int.tryParse(tableNumber) != null) {
        DocumentReference tableRef = _db.collection('tables').doc(tableNumber);
        transaction.set(tableRef, {'id': tableNumber, 'status': 'occupied'}, SetOptions(merge: true));
      }

      return runningId; 
    });
  }
}