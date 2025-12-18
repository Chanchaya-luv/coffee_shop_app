import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart';
import 'customer_tracking_screen.dart';
// --- 🔥 เพิ่ม Import หน้าต่างเลือกตัวเลือก ---
import '../common/product_customize_dialog.dart';

class MenuScreen extends StatefulWidget {
  final String tableNumber; 

  const MenuScreen({super.key, required this.tableNumber});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final List<String> _categories = ["กาแฟ", "ชา", "นมสด", "ผลไม้","เบเกอรี่"];
  int _selectedIndex = 0;

  // --- 🔥 ฟังก์ชันเปิดหน้าต่างเลือกตัวเลือก (เหมือน Admin) ---
  void _openCustomizeDialog(MenuItem menu) {
    showDialog(
      context: context,
      builder: (context) => ProductCustomizeDialog(
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
      body: Column(
        children: [
          // Category Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                bool isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: isSelected ? const Color(0xFFA6C48A) : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                    child: Center(child: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                  ),
                );
              },
            ),
          ),

          // Menu Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                String currentCategory = _categories[_selectedIndex];
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  String itemCategory = data['category'] ?? 'กาแฟ'; 
                  return itemCategory == currentCategory;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.menu_book, size: 60, color: Colors.grey), const SizedBox(height: 10), Text("ไม่พบเมนูในหมวด $currentCategory", style: const TextStyle(color: Colors.grey))]));
                }

                final menus = filteredDocs.map((doc) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  
                  List<RecipeItem> recipeList = [];
                  if (data['recipe'] != null && data['recipe'] is List) {
                    for (var item in data['recipe']) {
                      if (item is Map) {
                        recipeList.add(RecipeItem.fromMap(Map<String, dynamic>.from(item)));
                      }
                    }
                  }

                  return MenuItem(
                    id: doc.id,
                    name: data['name'] ?? 'Unknown',
                    price: (data['price'] ?? 0).toDouble(),
                    category: data['category'] ?? 'อื่นๆ',
                    imageUrl: data['imageUrl'] ?? '',
                    recipe: recipeList,
                    isAvailable: data['isAvailable'] ?? true, 
                  );
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
                  itemCount: menus.length,
                  itemBuilder: (ctx, i) => _buildMenuCard(context, menus[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) return const SizedBox();
          return FloatingActionButton.extended(onPressed: () => _goToCheckout(context), label: Text("ตะกร้า ฿${cart.totalAmount.toStringAsFixed(0)}"), icon: const Icon(Icons.shopping_cart), backgroundColor: const Color(0xFFA6C48A));
        },
      ),
    );
  }

  void _goToCheckout(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(tableNumber: widget.tableNumber, isCustomer: true)));
  }

  Widget _buildMenuCard(BuildContext context, MenuItem menu) {
    // --- 🔥 ใช้ GestureDetector ครอบเพื่อกดที่การ์ดแล้วเด้ง Popup ---
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
            
            Text(menu.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: menu.isAvailable ? Colors.black : Colors.grey), maxLines: 1),
            
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("฿${menu.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
              
              if (menu.isAvailable)
                InkWell(
                  onTap: () => _openCustomizeDialog(menu), // กดบวกก็เปิด Popup เหมือนกัน
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