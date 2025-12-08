import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_menu_screen.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  String _selectedCategory = "ทั้งหมด";

  // --- 🔥 ฟังก์ชันสลับสถานะของหมด ---
  void _toggleAvailability(String docId, bool currentValue) {
    FirebaseFirestore.instance.collection('menu_items').doc(docId).update({
      'isAvailable': !currentValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("จัดการเมนู (Admin)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

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

          var filteredDocs = docs;
          if (_selectedCategory != "ทั้งหมด") {
            filteredDocs = docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return (data['category'] ?? 'อื่นๆ') == _selectedCategory;
            }).toList();
          }

          return Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
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
                        child: Center(child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: filteredDocs.isEmpty 
                  ? Center(child: Text("ไม่มีเมนูในหมวด '$_selectedCategory'", style: const TextStyle(color: Colors.grey)))
                  : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.70, // ปรับให้ยาวขึ้นนิดนึงเพื่อใส่ Switch
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var data = filteredDocs[index].data() as Map<String, dynamic>;
                      String id = filteredDocs[index].id;
                      String name = data['name'] ?? '-';
                      double price = (data['price'] ?? 0).toDouble();
                      String category = data['category'] ?? 'อื่นๆ';
                      String imageUrl = data['imageUrl'] ?? '';
                      bool isAvailable = data['isAvailable'] ?? true; // ดึงสถานะ

                      return _buildAdminMenuCard(context, id, name, price, category, imageUrl, isAvailable, data);
                    },
                  ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFA6C48A),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMenuScreen())),
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มเมนู"),
      ),
    );
  }

  Widget _buildAdminMenuCard(BuildContext context, String id, String name, double price, String category, String imageUrl, bool isAvailable, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => AddMenuScreen(id: id, data: data)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          // ถ้าของหมด ให้ขอบเป็นสีแดงจางๆ
          border: isAvailable ? null : Border.all(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
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
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.grey))
                            : const Icon(Icons.coffee, size: 50, color: Colors.brown),
                      ),
                    ),
                    // ถ้าของหมด ให้ขึ้นป้าย Sold Out
                    if (!isAvailable)
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text("SOLD OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      )
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isAvailable ? Colors.black : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("฿${price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  // --- 🔥 สวิตช์เปิดปิดของหมด ---
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isAvailable,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      onChanged: (val) => _toggleAvailability(id, isAvailable),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}