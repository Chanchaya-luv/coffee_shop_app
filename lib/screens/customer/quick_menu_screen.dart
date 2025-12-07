import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart'; 
import '../../screens/admin/add_menu_screen.dart';

class QuickMenuScreen extends StatefulWidget {
  const QuickMenuScreen({super.key});

  @override
  State<QuickMenuScreen> createState() => _QuickMenuScreenState();
}

class _QuickMenuScreenState extends State<QuickMenuScreen> {
  final List<String> _categories = ["กาแฟ", "ชา", "นมสด", "ผลไม้"];
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Quick Menu", style: TextStyle(fontWeight: FontWeight.bold)),
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("ไม่มีสินค้าในเมนู"));

                String currentCategory = _categories[_selectedIndex];
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['category'] ?? 'กาแฟ') == currentCategory;
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
                    name: data['name'] ?? 'ไม่ระบุชื่อ', 
                    price: (data['price'] ?? 0).toDouble(),
                    category: data['category'] ?? 'อื่นๆ',
                    imageUrl: data['imageUrl'] ?? '',
                    recipe: recipeList,
                  );
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75, // สัดส่วนนี้จะช่วยให้การ์ดสูงพอที่รูปจะขยายได้
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // ใช้เงาที่นุ่มนวลขึ้นเหมือนฝั่งลูกค้า
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Padding(
        // เพิ่ม Padding เป็น 12 เพื่อให้มีช่องไฟมากขึ้น
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูปภาพขยายเต็มพื้นที่ที่เหลือ
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.brown[50], borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: menu.imageUrl.isNotEmpty
                      ? Image.network(
                          menu.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      // เพิ่มขนาดไอคอน Placeholder ให้ใหญ่ขึ้น
                      : const Icon(Icons.coffee, size: 50, color: Colors.brown),
                ),
              ),
            ),
            // เพิ่มระยะห่างเป็น 10
            const SizedBox(height: 10),
            // เพิ่มขนาดตัวอักษรชื่อเมนูเป็น 16
            Text(menu.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
            
            // แถวแสดงราคาและปุ่มเพิ่ม/ลด
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("฿${menu.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
                
                // ปุ่มควบคุมจำนวน
                Consumer<CartProvider>(
                  builder: (ctx, cart, child) {
                    int qty = cart.getQuantity(menu.id);
                    return Row(
                      children: [
                        InkWell(onTap: () => cart.updateQuantity(menu, -1), child: const Icon(Icons.remove_circle_outline, color: Colors.grey)),
                        const SizedBox(width: 8), // เพิ่มระยะห่างตัวเลข
                        Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8), // เพิ่มระยะห่างตัวเลข
                        InkWell(onTap: () => cart.updateQuantity(menu, 1), child: const Icon(Icons.add_circle, color: Color(0xFFA6C48A))),
                      ],
                    );
                  },
                )
              ],
            ),
          ],
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(tableNumber: 'TA-001')));
              },
              child: Text("Checkout ฿${cart.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}