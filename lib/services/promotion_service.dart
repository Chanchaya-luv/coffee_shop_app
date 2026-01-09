import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_promotion.dart';
import '../providers/cart_provider.dart';
import '../models/model_menu.dart'; 

class PromotionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Promotion>> getActivePromotions() async {
    var snapshot = await _db.collection('promotions').where('isActive', isEqualTo: true).get();
    return snapshot.docs.map((doc) => Promotion.fromFirestore(doc)).toList();
  }

  // --- 🔥 ฟังก์ชันตรวจสอบโค้ดส่วนลด (ปรับปรุง) ---
  Future<Map<String, dynamic>> verifyPromoCode(String code, List<CartItem> items) async {
    try {
      // 1. ค้นหาโค้ด
      var snapshot = await _db.collection('promotions')
          .where('code', isEqualTo: code.toUpperCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'isValid': false, 'message': 'ไม่พบโค้ดส่วนลด หรือโค้ดหมดอายุ'};
      }

      var promoData = snapshot.docs.first.data();
      String type = promoData['type'] ?? 'quantity_discount';
      Map<String, dynamic> conditions = promoData['conditions'] ?? {};

      // 2. เช็คเงื่อนไขตามประเภท
      if (type == 'quantity_discount') {
        // ... (Logic เดิม: ลดเงิน) ...
        int totalQty = items.fold(0, (sum, item) => sum + item.quantity);
        int minQty = conditions['minQty'] ?? 0;
        double discountAmount = (conditions['discountAmount'] ?? 0).toDouble();

        if (totalQty >= minQty) {
          return {
            'isValid': true,
            'type': 'discount',
            'discountAmount': discountAmount,
            'promoName': promoData['name'],
            'message': 'ใช้โค้ดลดราคาสำเร็จ!'
          };
        } else {
          return {'isValid': false, 'message': 'ต้องซื้อครบ $minQty แก้ว ถึงจะใช้โค้ดนี้ได้'};
        }
      } 
      
      // --- 🔥 Logic ใหม่: ซื้อ X แถม Y ---
      else if (type == 'buy_x_get_y') {
        int buyQty = conditions['buy'] ?? 0;
        
        // กรองเฉพาะเครื่องดื่ม (ไม่นับเบเกอรี่)
        var drinkItems = items.where((item) => 
            ['กาแฟ', 'ชา', 'นมสด', 'ผลไม้'].contains(item.menu.category)
        ).toList();
        
        int totalDrinks = drinkItems.fold(0, (sum, item) => sum + item.quantity);

        if (totalDrinks >= buyQty) {
          // หา "ราคาต่ำสุด" ในบรรดาเครื่องดื่มที่ซื้อ เพื่อเป็นเพดานราคาของแถม (Equal or Lesser Value)
          double minPriceInCart = double.infinity;
          for (var item in drinkItems) {
            // ใช้ราคาจริง (รวม type adjustment) หรือราคาฐานก็ได้ ปกติใช้ราคาฐาน
            if (item.menu.price < minPriceInCart) {
              minPriceInCart = item.menu.price;
            }
          }
          if (minPriceInCart == double.infinity) minPriceInCart = 0;

          return {
            'isValid': true,
            'type': 'free_item', // บอกหน้า Checkout ว่าให้เปิด Popup เลือกของแถม
            'maxPrice': minPriceInCart, // ส่งราคาสูงสุดที่แลกได้ไป
            'promoName': promoData['name'],
            'message': 'เงื่อนไขถูกต้อง! กรุณาเลือกของแถม'
          };
        } else {
          return {'isValid': false, 'message': 'ต้องซื้อเครื่องดื่มครบ $buyQty แก้ว (ไม่รวมเบเกอรี่)'};
        }
      }

      return {'isValid': false, 'message': 'ประเภทโปรโมชั่นไม่รองรับในขณะนี้'};

    } catch (e) {
      return {'isValid': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  // ฟังก์ชันดึงรายการของแถม (ตามเงื่อนไขราคาและหมวดหมู่)
  Future<List<MenuItem>> getEligibleFreeItems(double maxPrice) async {
    // ดึงเมนูทั้งหมดที่ Active
    var snapshot = await _db.collection('menu_items')
        .where('isAvailable', isEqualTo: true)
        .get();

    List<MenuItem> candidates = [];
    for (var doc in snapshot.docs) {
      var data = doc.data();
      String category = data['category'] ?? '';
      double price = (data['price'] ?? 0).toDouble();

      // กรอง 1: ต้องเป็นเครื่องดื่มเท่านั้น (ไม่เอาเบเกอรี่)
      bool isDrink = ['กาแฟ', 'ชา', 'นมสด', 'ผลไม้'].contains(category);
      
      // กรอง 2: ราคาต้องน้อยกว่าหรือเท่ากับที่กำหนด
      bool isPriceValid = price <= maxPrice;

      if (isDrink && isPriceValid) {
         List<RecipeItem> recipeList = [];
         if (data['recipe'] != null && data['recipe'] is List) {
           for (var item in data['recipe']) {
             if (item is Map) recipeList.add(RecipeItem.fromMap(Map<String, dynamic>.from(item)));
           }
         }

         candidates.add(MenuItem(
            id: doc.id,
            name: data['name'] ?? '',
            price: price,
            category: category,
            imageUrl: data['imageUrl'] ?? '',
            recipe: recipeList,
            isAvailable: true,
         ));
      }
    }
    return candidates;
  }
  
  double calculateDiscount(Promotion p, List<CartItem> items, double total) => 0.0;
}