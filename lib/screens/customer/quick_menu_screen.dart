import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart'; 
import '../../screens/admin/add_menu_screen.dart';
import '../common/product_customize_dialog.dart';

class QuickMenuScreen extends StatefulWidget {
  const QuickMenuScreen({super.key});

  @override
  State<QuickMenuScreen> createState() => _QuickMenuScreenState();
}

class _QuickMenuScreenState extends State<QuickMenuScreen> {
  // เพิ่มหมวด "เบเกอรี่" เข้าไปในรายการ
  final List<String> _categories = ["กาแฟ", "ชา", "นมสด", "ผลไม้", "เบเกอรี่"];
  int _selectedIndex = 0;

  void _openCustomizeDialog(MenuItem menu) {
    // --- 🔥 Logic เช็คหมวดหมู่ (เหมือนฝั่งลูกค้า) ---
    // ถ้าเป็น เบเกอรี่ หรือ ของหวาน ไม่ต้องถามความหวาน/นม
    if (['เบเกอรี่', 'ขนม', 'เค้ก', 'ของหวาน', 'ผลไม้'].contains(menu.category)) {
      
      // เพิ่มลงตะกร้าทันที (ระบุ option เป็น '-')
      Provider.of<CartProvider>(context, listen: false).addItem(
        menu, 
        sweetness: '-', 
        milk: '-'
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("เพิ่ม ${menu.name} แล้ว"), 
          duration: const Duration(milliseconds: 500) // ลดเวลาให้เร็วขึ้นสำหรับ Admin
        )
      );
      return; 
    }

    // ถ้าเป็นเครื่องดื่ม ค่อยโชว์ Popup
    showDialog(
      context: context,
      builder: (context) => ProductCustomizeDialog(
        menu: menu,
        onConfirm: (sweetness, milk) {
          Provider.of<CartProvider>(context, listen: false).addItem(menu, sweetness: sweetness, milk: milk);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เพิ่ม ${menu.name} ($sweetness, $milk) แล้ว"), duration: const Duration(milliseconds: 500)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Quick Menu (Admin)", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
               Provider.of<CartProvider>(context, listen: false).clearCart();
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ล้างตะกร้าแล้ว")));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Category Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFA6C48A) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              _categories[index],
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
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMenuScreen())),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFFA6C48A)),
                  label: const Text("เพิ่มเมนู", style: TextStyle(color: Color(0xFFA6C48A), fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),

          // 2. Product Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("ไม่มีสินค้าในเมนู"));
                }

                String currentCategory = _categories[_selectedIndex];
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  // ใช้ try-catch เพื่อความปลอดภัย
                  try {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['category'] ?? 'กาแฟ') == currentCategory;
                  } catch (e) {
                    return false;
                  }
                }).toList();

                if (filteredDocs.isEmpty) return Center(child: Text("ไม่มีสินค้าในหมวด $currentCategory"));

                final menus = filteredDocs.map((doc) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  
                  List<RecipeItem> recipeList = [];
                  if (data['recipe'] != null && data['recipe'] is List) {
                    for (var item in data['recipe']) {
                      if (item is Map) recipeList.add(RecipeItem.fromMap(Map<String, dynamic>.from(item)));
                    }
                  }

                  return MenuItem(
                    id: doc.id,
                    name: data.containsKey('name') ? data['name'] : 'ไม่ระบุชื่อ', 
                    price: (data['price'] ?? 0).toDouble(),
                    category: data['category'] ?? 'อื่นๆ',
                    imageUrl: data['imageUrl'] ?? '',
                    recipe: recipeList,
                    isAvailable: data['isAvailable'] ?? true, 
                  );
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75, 
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: menus.length,
                  itemBuilder: (ctx, i) => _buildProductCard(context, menus[i]),
                );
              },
            ),
          ),
          
          _buildCheckoutBar(context),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, MenuItem menu) {
    return GestureDetector(
      onTap: menu.isAvailable ? () => _openCustomizeDialog(menu) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              
              Text(
                menu.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: menu.isAvailable ? Colors.black : Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("฿${menu.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
                  
                  if (menu.isAvailable)
                    InkWell(
                      onTap: () => _openCustomizeDialog(menu), 
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFA6C48A), shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    )
                  else
                     const Text("ของหมด", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        if (cart.itemCount == 0) return const SizedBox();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA6C48A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(tableNumber: 'TA-001', isCustomer: false)));
              },
              child: Text("Checkout ฿${cart.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}