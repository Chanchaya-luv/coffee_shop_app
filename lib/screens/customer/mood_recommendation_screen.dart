import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';
import '../common/product_customize_dialog.dart';

class MoodRecommendationScreen extends StatefulWidget {
  const MoodRecommendationScreen({super.key});

  @override
  State<MoodRecommendationScreen> createState() => _MoodRecommendationScreenState();
}

class _MoodRecommendationScreenState extends State<MoodRecommendationScreen> {
  String _selectedMood = "";
  List<MenuItem> _recommendedItems = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _moods = [
    {'label': 'ง่วงนอน 😴', 'key': 'sleepy', 'color': Colors.blue},
    {'label': 'ร้อน/กระหาย 🥵', 'key': 'fresh', 'color': Colors.orange},
    {'label': 'เครียด/อยากหวาน 🤯', 'key': 'sweet', 'color': Colors.pink},
    {'label': 'รักสุขภาพ 🌿', 'key': 'healthy', 'color': Colors.green},
  ];

  void _recommendByMood(String moodKey) async {
    setState(() {
      _selectedMood = moodKey;
      _isLoading = true;
    });

    // ดึงเมนูทั้งหมดมาคัดกรอง (ในระบบจริงอาจจะ Tag ไว้ใน DB แต่ตอนนี้เราใช้ Logic กรองจากชื่อ/หมวด)
    var snapshot = await FirebaseFirestore.instance.collection('menu_items').where('isAvailable', isEqualTo: true).get();
    
    List<MenuItem> allItems = snapshot.docs.map((doc) {
       Map<String, dynamic> data = doc.data();
       return MenuItem(
          id: doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          category: data['category'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          recipe: [], // ไม่ต้องใช้สูตรในหน้านี้
          isAvailable: true
       );
    }).toList();

    List<MenuItem> filtered = [];

    // --- 🤖 Logic AI (แบบง่าย) ---
    if (moodKey == 'sleepy') {
      // ง่วง -> กาแฟเข้มๆ
      filtered = allItems.where((i) => i.category == 'กาแฟ' || i.name.contains('เอสเพรสโซ') || i.name.contains('อเมริกาโน')).toList();
    } else if (moodKey == 'fresh') {
      // ร้อน -> โซดา, ผลไม้
      filtered = allItems.where((i) => i.category == 'ผลไม้' || i.name.contains('โซดา') || i.name.contains('เย็น') || i.name.contains('ปั่น')).toList();
    } else if (moodKey == 'sweet') {
      // เครียด -> นม, คาราเมล, ช็อกโกแลต
      filtered = allItems.where((i) => i.category == 'นมสด' || i.category == 'เบเกอรี่' || i.name.contains('คาราเมล') || i.name.contains('โกโก้')).toList();
    } else if (moodKey == 'healthy') {
      // สุขภาพ -> ชาใส, ไม่ใส่นม
      filtered = allItems.where((i) => i.category == 'ชา' || i.name.contains('น้ำผึ้ง') || i.name.contains('มะนาว')).toList();
    }

    // สุ่มมาโชว์สัก 3-4 อย่าง ไม่ให้เยอะเกิน
    filtered.shuffle();
    if (filtered.length > 4) filtered = filtered.sublist(0, 4);

    setState(() {
      _recommendedItems = filtered;
      _isLoading = false;
    });
  }

  void _openCustomizeDialog(MenuItem menu) {
    // ใช้ Dialog เดิมที่มีอยู่
    if (['เบเกอรี่', 'ขนม', 'เค้ก', 'ของหวาน', 'ผลไม้'].contains(menu.category)) {
      Provider.of<CartProvider>(context, listen: false).addItem(menu, sweetness: '-', milk: '-');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เพิ่ม ${menu.name} แล้ว"), duration: const Duration(milliseconds: 500)));
    } else {
      showDialog(
        context: context,
        builder: (context) => ProductCustomizeDialog(
          menu: menu,
          onConfirm: (sweetness, milk) {
            Provider.of<CartProvider>(context, listen: false).addItem(menu, sweetness: sweetness, milk: milk);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เพิ่ม ${menu.name} แล้ว"), duration: const Duration(milliseconds: 500)));
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("แนะนำเมนูตามอารมณ์", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Question
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: const Column(
              children: [
                Text("วันนี้คุณรู้สึกอย่างไร?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                Text("เลือกอารมณ์ของคุณ แล้วให้เราช่วยเลือกเมนูให้", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Mood Buttons
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_,__) => const SizedBox(width: 15),
              itemBuilder: (context, index) {
                var mood = _moods[index];
                bool isSelected = _selectedMood == mood['key'];
                return GestureDetector(
                  onTap: () => _recommendByMood(mood['key']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isSelected ? 110 : 100,
                    decoration: BoxDecoration(
                      color: isSelected ? mood['color'] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mood['color'], width: 2),
                      boxShadow: [if(isSelected) BoxShadow(color: (mood['color'] as Color).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(mood['label'].toString().split(' ')[1], style: const TextStyle(fontSize: 32)), // Emoji
                        const SizedBox(height: 5),
                        Text(mood['label'].toString().split(' ')[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),

          // Results
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedMood.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.touch_app, size: 60, color: Colors.grey), SizedBox(height: 10), Text("แตะที่อารมณ์ด้านบนเพื่อเริ่ม", style: TextStyle(color: Colors.grey))]))
                  : _recommendedItems.isEmpty
                      ? const Center(child: Text("ไม่พบเมนูที่ตรงกับอารมณ์นี้", style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: _recommendedItems.length,
                          itemBuilder: (context, index) {
                            var item = _recommendedItems[index];
                            return GestureDetector(
                              onTap: () => _openCustomizeDialog(item),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                        child: item.imageUrl.isNotEmpty 
                                          ? Image.network(item.imageUrl, fit: BoxFit.cover, width: double.infinity)
                                          : Container(color: Colors.brown[50], child: const Center(child: Icon(Icons.coffee, size: 40, color: Colors.brown))),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("฿${item.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
                                              const Icon(Icons.add_circle, color: Color(0xFFA6C48A))
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }
}