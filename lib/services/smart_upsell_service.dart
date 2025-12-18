import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_menu.dart';
import '../providers/cart_provider.dart';

class SmartUpsellService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 🔥 แก้ไข: คืนค่าเป็น List<MenuItem> เพื่อให้ลูกค้าเลือกได้ ---
  Future<List<MenuItem>> getUpsellItems(List<CartItem> cartItems) async {
    // 1. กฎการเชียร์ขาย: ถ้ามี "เครื่องดื่ม" แต่ไม่มี "เบเกอรี่"
    bool hasDrink = cartItems.any((item) => ['กาแฟ', 'ชา', 'นมสด'].contains(item.menu.category));
    bool hasBakery = cartItems.any((item) => item.menu.category == 'เบเกอรี่'); // ตรวจสอบชื่อหมวดใน DB ให้ตรง

    if (hasDrink && !hasBakery) {
      // ดึงสินค้าหมวด "เบเกอรี่" มาแนะนำ (เอามา 5 รายการให้เลือก)
      var snapshot = await _db.collection('menu_items')
          .where('category', isEqualTo: 'เบเกอรี่') // หรือ 'ผลไม้' ตามที่มีในร้าน
          .where('isAvailable', isEqualTo: true)
          .limit(5)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          
          List<RecipeItem> recipeList = [];
          if (data['recipe'] != null && data['recipe'] is List) {
              for (var item in data['recipe']) {
                  if (item is Map) recipeList.add(RecipeItem.fromMap(Map<String, dynamic>.from(item)));
              }
          }

          return MenuItem(
              id: doc.id,
              name: data['name'] ?? 'สินค้าแนะนำ',
              price: (data['price'] ?? 0).toDouble(),
              category: data['category'] ?? 'เบเกอรี่',
              imageUrl: data['imageUrl'] ?? '',
              recipe: recipeList,
              isAvailable: true,
          );
        }).toList();
      }
    }
    return []; // ถ้าไม่เข้าเงื่อนไข คืนค่า List ว่าง
  }
}