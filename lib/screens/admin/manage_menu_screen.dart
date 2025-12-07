import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_menu_screen.dart'; // Import หน้าเพิ่ม/แก้ไข

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  String _selectedCategory = "ทั้งหมด"; // ตัวแปรเก็บหมวดที่เลือก

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
      // --- 🔥 ใช้ StreamBuilder ครอบทั้งหน้าเพื่อดึงหมวดหมู่มาสร้างปุ่ม ---
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          // 1. สกัดหมวดหมู่ทั้งหมดที่มีอยู่จริง (Dynamic Categories)
          Set<String> categorySet = {"ทั้งหมด"}; 
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['category'] != null && data['category'].toString().isNotEmpty) {
              categorySet.add(data['category']);
            }
          }
          List<String> dynamicCategories = categorySet.toList();
          // เรียงลำดับหมวดหมู่ (เอา 'ทั้งหมด' ไว้หน้าสุดเสมอ)
          dynamicCategories.sort((a, b) {
            if (a == "ทั้งหมด") return -1;
            if (b == "ทั้งหมด") return 1;
            return a.compareTo(b);
          });

          // 2. กรองรายการเมนูตามหมวดที่เลือก
          var filteredDocs = docs;
          if (_selectedCategory != "ทั้งหมด") {
            filteredDocs = docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return (data['category'] ?? 'อื่นๆ') == _selectedCategory;
            }).toList();
          }

          return Column(
            children: [
              // --- แถบหมวดหมู่ด้านบน ---
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                ),
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

              // --- รายการเมนู (Filtered List) ---
              Expanded(
                child: filteredDocs.isEmpty 
                  ? Center(child: Text("ไม่มีเมนูในหมวด '$_selectedCategory'", style: const TextStyle(color: Colors.grey)))
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var data = filteredDocs[index].data() as Map<String, dynamic>;
                      String id = filteredDocs[index].id;
                      String name = data['name'] ?? '-';
                      double price = (data['price'] ?? 0).toDouble();
                      String category = data['category'] ?? 'อื่นๆ';
                      String imageUrl = data['imageUrl'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 60,
                              height: 60,
                              color: Colors.brown[50],
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.grey))
                                  : const Icon(Icons.coffee, color: Colors.brown),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(category, style: TextStyle(fontSize: 10, color: Colors.grey[800])),
                              ),
                              const SizedBox(height: 4),
                              Text("฿${price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: () {
                              // ไปหน้าแก้ไข
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddMenuScreen(id: id, data: data),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                             Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddMenuScreen(id: id, data: data),
                                ),
                              );
                          },
                        ),
                      );
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
        onPressed: () {
          // เพิ่มเมนูใหม่
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMenuScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มเมนู"),
      ),
    );
  }
}