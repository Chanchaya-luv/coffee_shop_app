import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart';
import 'customer_tracking_screen.dart';
// --- 🔥 เพิ่ม Import หน้าต่างเลือกตัวเลือก (Visual) ---
import '../common/visual_product_customize_dialog.dart';
// --- 🔥 เพิ่ม Import หน้า Mood ---
import 'mood_recommendation_screen.dart';

class MenuScreen extends StatefulWidget {
  final String tableNumber; 

  const MenuScreen({super.key, required this.tableNumber});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final List<String> _categories = ["กาแฟ", "ชา", "นมสด", "ผลไม้", "เบเกอรี่"];
  String _selectedCategory = "ทั้งหมด"; 

  // --- 🔥 ฟังก์ชันเปิดหน้าต่างเลือกตัวเลือก (แก้ไขใหม่) ---
  void _openCustomizeDialog(MenuItem menu) {
    // 1. เช็คหมวดหมู่ที่ไม่ต้องเลือก Option (เช่น เบเกอรี่)
    if (['เบเกอรี่', 'ขนม', 'เค้ก', 'ของหวาน'].contains(menu.category)) {
      
      // เพิ่มลงตะกร้าเลย (ใส่ค่า '-' เพื่อบอกว่าไม่มี Option)
      Provider.of<CartProvider>(context, listen: false).addItem(
        menu, 
        sweetness: '-', 
        milk: '-'
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("เพิ่ม ${menu.name} แล้ว"), 
          duration: const Duration(milliseconds: 800)
        )
      );
      return; // จบการทำงาน ไม่เปิด Dialog
    }

    // 2. ถ้าเป็นหมวดอื่นๆ (เครื่องดื่ม) ให้เปิด Visual Dialog
    showDialog(
      context: context,
      builder: (context) => VisualProductCustomizeDialog( // 👈 ใช้ตัวใหม่นี้
        menu: menu,
        onConfirm: (sweetness, milk) {
          // เพิ่มลงตะกร้าพร้อมตัวเลือก
          Provider.of<CartProvider>(context, listen: false).addItem(menu, sweetness: sweetness, milk: milk);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("เพิ่ม ${menu.name} ($sweetness, $milk) แล้ว"), 
              duration: const Duration(milliseconds: 800)
            )
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("สั่งอาหาร", style: TextStyle(fontSize: 16)),
            Text("โต๊ะ: ${widget.tableNumber}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFA6C48A))),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6F4E37),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) {
              if (cart.activeOrderId != null) {
                return IconButton(
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerTrackingScreen(orderId: cart.activeOrderId!)));
                  },
                );
              }
              return const SizedBox();
            },
          ),
          Consumer<CartProvider>(
            builder: (_, cart, ch) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(icon: const Icon(Icons.shopping_bag_outlined), onPressed: () => _goToCheckout(context)),
                if (cart.totalItemsCount > 0)
                   Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)), constraints: const BoxConstraints(minWidth: 14, minHeight: 14), child: Text('${cart.totalItemsCount}', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center)))
              ],
            ),
          ),
        ],
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          // สกัดหมวดหมู่
          Set<String> categorySet = {"ทั้งหมด"};
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['category'] != null && data['category'].toString().isNotEmpty) {
              categorySet.add(data['category']);
            }
          }
          List<String> dynamicCategories = categorySet.toList();
          dynamicCategories.sort((a, b) {
             if (a == "ทั้งหมด") return -1;
             if (b == "ทั้งหมด") return 1;
             return a.compareTo(b);
          });

          // กรองสินค้า
          var filteredDocs = docs;
          if (_selectedCategory != "ทั้งหมด") {
            filteredDocs = docs.where((doc) {
               var data = doc.data() as Map<String, dynamic>;
               return (data['category'] ?? 'อื่นๆ') == _selectedCategory;
            }).toList();
          }

          return Column(
            children: [
              // Category Bar
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    String cat = dynamicCategories[index];
                    bool isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFA6C48A) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- 🔥 ปุ่มพิเศษ "Mood Recommender" ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MoodRecommendationScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6F4E37),
                      elevation: 2,
                      side: const BorderSide(color: Color(0xFF6F4E37), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.auto_awesome, color: Colors.orange),
                    label: const Text("ไม่รู้จะกินอะไร? ให้เราช่วยเลือก", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              // Menu Grid
              Expanded(
                child: filteredDocs.isEmpty
                  ? Center(child: Text("ไม่พบเมนูในหมวด '$_selectedCategory'", style: const TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredDocs.length,
                      itemBuilder: (ctx, i) {
                        var doc = filteredDocs[i];
                        var data = doc.data() as Map<String, dynamic>;
                        List<RecipeItem> recipeList = [];
                        if (data['recipe'] != null && data['recipe'] is List) {
                          for (var item in data['recipe']) {
                            if (item is Map) {
                              recipeList.add(RecipeItem.fromMap(Map<String, dynamic>.from(item)));
                            }
                          }
                        }

                        MenuItem menu = MenuItem(
                          id: doc.id,
                          name: data['name'] ?? 'ไม่ระบุชื่อ',
                          price: (data['price'] ?? 0).toDouble(),
                          category: data['category'] ?? 'อื่นๆ',
                          imageUrl: data['imageUrl'] ?? '',
                          recipe: recipeList,
                          isAvailable: data['isAvailable'] ?? true, 
                        );

                        return _buildMenuCard(context, menu);
                      },
                    ),
              ),
            ],
          );
        },
      ),
      
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) return const SizedBox();
          return FloatingActionButton.extended(
            onPressed: () => _goToCheckout(context),
            label: Text("ตะกร้า ฿${cart.totalAmount.toStringAsFixed(0)}"),
            icon: const Icon(Icons.shopping_cart),
            backgroundColor: const Color(0xFFA6C48A),
          );
        },
      ),
    );
  }

  void _goToCheckout(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(tableNumber: widget.tableNumber, isCustomer: true)));
  }

  Widget _buildMenuCard(BuildContext context, MenuItem menu) {
    return GestureDetector(
      onTap: menu.isAvailable ? () => _openCustomizeDialog(menu) : null,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.brown[50], borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // --- 🔥 แสดงรูปภาพ ---
                      child: menu.imageUrl.isNotEmpty
                          ? ColorFiltered(
                              colorFilter: menu.isAvailable 
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) 
                                : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                              child: Image.network(
                                  menu.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                                )
                            )
                          : const Icon(Icons.coffee, size: 50, color: Colors.brown),
                    ),
                  ),
                  
                  if (!menu.isAvailable)
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Text("SOLD OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            Text(menu.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: menu.isAvailable ? Colors.black : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("฿${menu.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
              
              if (menu.isAvailable)
                InkWell(
                  onTap: () => _openCustomizeDialog(menu), 
                  child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFA6C48A), shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 20))
                )
              else
                const Text("ของหมด", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
            ])
          ]),
        ),
      ),
    );
  }
}