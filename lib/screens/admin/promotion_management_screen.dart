import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'add_promotion_screen.dart'; // Import หน้าเพิ่ม/แก้ไข

class PromotionManagementScreen extends StatefulWidget {
  const PromotionManagementScreen({super.key});

  @override
  State<PromotionManagementScreen> createState() => _PromotionManagementScreenState();
}

class _PromotionManagementScreenState extends State<PromotionManagementScreen> {
  
  // ฟังก์ชันลบโปรโมชั่น
  void _deletePromotion(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: Text("คุณต้องการลบโปรโมชั่น '$name' ใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('promotions').doc(id).delete();
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบเรียบร้อย")));
            }, 
            child: const Text("ลบ", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสลับสถานะเปิด/ปิด
  void _toggleActive(String id, bool currentValue) {
    FirebaseFirestore.instance.collection('promotions').doc(id).update({
      'isActive': !currentValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("จัดการโปรโมชั่น", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('promotions').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("ยังไม่มีโปรโมชั่น", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_,__) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              String name = data['name'] ?? 'ไม่ระบุชื่อ';
              String code = data['code'] ?? '-';
              String type = data['type'] ?? 'quantity_discount';
              bool isActive = data['isActive'] ?? false;
              Map<String, dynamic> conditions = data['conditions'] ?? {};

              String detailText = "";
              if (type == 'quantity_discount') {
                detailText = "ซื้อครบ ${conditions['minQty']} แก้ว ลด ${conditions['discountAmount']} บาท";
              } else if (type == 'buy_x_get_y') {
                detailText = "ซื้อ ${conditions['buy']} แถม ${conditions['get']}";
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                // ถ้าปิดใช้งาน การ์ดจะเป็นสีเทา
                color: isActive ? Colors.white : Colors.grey[200],
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // กดที่การ์ดเพื่อแก้ไข
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => AddPromotionScreen(id: doc.id, data: data))
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.orange[50] : Colors.grey[300],
                                shape: BoxShape.circle
                              ),
                              child: Icon(Icons.local_offer, color: isActive ? Colors.orange : Colors.grey),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3))
                                    ),
                                    child: Text("CODE: $code", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(detailText, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                // สวิตช์เปิด/ปิด
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: isActive,
                                    activeColor: Colors.green,
                                    onChanged: (val) => _toggleActive(doc.id, isActive),
                                  ),
                                ),
                                // ปุ่มลบ
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deletePromotion(doc.id, name),
                                )
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFA6C48A),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPromotionScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text("สร้างโปรโมชั่น"),
      ),
    );
  }
}