import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromotionManagementScreen extends StatefulWidget {
  const PromotionManagementScreen({super.key});

  @override
  State<PromotionManagementScreen> createState() => _PromotionManagementScreenState();
}

class _PromotionManagementScreenState extends State<PromotionManagementScreen> {
  
  // ฟังก์ชันแสดง Dialog (ใช้ทั้งเพิ่มและแก้ไข)
  void _showManageDialog(BuildContext context, {String? id, Map<String, dynamic>? data}) {
    final isEditing = id != null;
    
    final nameCtrl = TextEditingController(text: isEditing ? data!['name'] : '');
    
    // --- 🔥 เปลี่ยน Default เป็น flat_amount ---
    String type = isEditing ? data!['type'] : 'flat_amount';

// 🔥 ปรับของเก่าที่เป็น flat_percent ให้เข้ากับระบบใหม่
if (type == 'flat_percent') {
  type = 'flat_amount';
}

    
    // ตัวแปรสำหรับเงื่อนไข
    final val1Ctrl = TextEditingController(); // amount / buy / start
    final val2Ctrl = TextEditingController(); // - / get / end

    // ดึงข้อมูลเดิมมาใส่ (ถ้าแก้ไข)
    if (isEditing) {
      Map conditions = data!['conditions'] ?? {};
      
      // --- 🔥 แก้ไขการดึงข้อมูล ---
      if (type == 'flat_amount') {
        val1Ctrl.text = (conditions['amount'] ?? 0).toString(); // ดึงค่า amount
      } else if (type == 'flat_percent') { 
        // เผื่อของเก่าที่เป็น percent ยังมีอยู่
        val1Ctrl.text = (conditions['percent'] ?? 0).toString();
      } else if (type == 'buy_x_get_y') {
        val1Ctrl.text = (conditions['buy'] ?? 1).toString();
        val2Ctrl.text = (conditions['get'] ?? 1).toString();
      } else if (type == 'time_based') {
        val1Ctrl.text = conditions['start'] ?? '';
        val2Ctrl.text = conditions['end'] ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "แก้ไขโปรโมชั่น" : "สร้างโปรโมชั่นใหม่"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(labelText: "ชื่อโปรโมชั่น", hintText: "เช่น ส่วนลด 10 บาท, Happy Hour")
                ),
                const SizedBox(height: 10),
                
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: "ประเภท"),
                  items: const [
                    // --- 🔥 เปลี่ยนตัวเลือก ---
                    DropdownMenuItem(value: 'flat_amount', child: Text("ลด (บาท) ท้ายบิล")),
                    DropdownMenuItem(value: 'time_based', child: Text("Happy Hour (ลดตามเวลา)")),
                    DropdownMenuItem(value: 'buy_x_get_y', child: Text("ซื้อ X แถม Y")),
                  ],
                  onChanged: (val) => setState(() => type = val!),
                ),
                const SizedBox(height: 10),
                
                // Input ตามประเภท
                // --- 🔥 เปลี่ยนช่องกรอกเป็น บาท ---
                if (type == 'flat_amount' || type == 'flat_percent')
                  TextField(
                    controller: val1Ctrl, 
                    decoration: const InputDecoration(labelText: "จำนวนเงินที่ลด (บาท)"), 
                    keyboardType: TextInputType.number
                  ),
                
                if (type == 'buy_x_get_y')
                  Row(
                    children: [
                      Expanded(child: TextField(controller: val1Ctrl, decoration: const InputDecoration(labelText: "ซื้อ (Buy)"), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: val2Ctrl, decoration: const InputDecoration(labelText: "แถม (Get)"), keyboardType: TextInputType.number)),
                    ],
                  ),
                  
                if (type == 'time_based') ...[
                  TextField(controller: val1Ctrl, decoration: const InputDecoration(labelText: "เวลาเริ่ม (เช่น 14:00)", hintText: "HH:mm")),
                  const SizedBox(height: 10),
                  TextField(controller: val2Ctrl, decoration: const InputDecoration(labelText: "เวลาจบ (เช่น 16:00)", hintText: "HH:mm")),
                  const SizedBox(height: 5),
                  const Text("ลด 50% (Fix)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  Map<String, dynamic> conditions = {};
                  
                  // --- 🔥 บันทึกเป็น amount ---
                  if (type == 'flat_amount') {
                    conditions['amount'] = int.tryParse(val1Ctrl.text) ?? 0;
                  } else if (type == 'flat_percent') {
                     // แปลงของเก่าให้เป็นแบบใหม่ (หรือเก็บแบบเดิมถ้าต้องการ)
                     type = 'flat_amount';
                     conditions['amount'] = int.tryParse(val1Ctrl.text) ?? 0;
                  } 
                  else if (type == 'buy_x_get_y') {
                    conditions['buy'] = int.tryParse(val1Ctrl.text) ?? 1;
                    conditions['get'] = int.tryParse(val2Ctrl.text) ?? 1;
                  } else if (type == 'time_based') {
                    conditions['start'] = val1Ctrl.text;
                    conditions['end'] = val2Ctrl.text;
                    conditions['percent'] = 50; 
                  }

                  final promoData = {
                    'name': nameCtrl.text,
                    'type': type,
                    'conditions': conditions,
                    'isActive': true, 
                  };

                  if (isEditing) {
                    await FirebaseFirestore.instance.collection('promotions').doc(id).update(promoData);
                  } else {
                    await FirebaseFirestore.instance.collection('promotions').add(promoData);
                  }
                  
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: Text(isEditing ? "บันทึก" : "สร้าง"),
            )
          ],
        ),
      ),
    );
  }

  void _deletePromotion(String id) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text("ต้องการลบโปรโมชั่นนี้ใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () {
               FirebaseFirestore.instance.collection('promotions').doc(id).delete();
               Navigator.pop(ctx);
            }, 
            child: const Text("ลบ", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("จัดการโปรโมชั่น", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF6F4E37), 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('promotions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("ยังไม่มีโปรโมชั่น"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isActive = data['isActive'] ?? true;
              String type = data['type'] ?? '';
              Map conditions = data['conditions'] ?? {};

              String detail = "";
              // --- 🔥 แสดงผลเป็นบาท ---
              if (type == 'flat_amount') detail = "ลด ${conditions['amount']} บาท";
              else if (type == 'flat_percent') detail = "ลด ${conditions['percent']}%"; // รองรับของเก่า
              else if (type == 'buy_x_get_y') detail = "ซื้อ ${conditions['buy']} แถม ${conditions['get']}";
              else if (type == 'time_based') detail = "${conditions['start']} - ${conditions['end']} (ลด ${conditions['percent']}%)";

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green[50] : Colors.grey[200],
                    child: Icon(Icons.local_offer, color: isActive ? Colors.green : Colors.grey),
                  ),
                  title: Text(data['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey)),
                  subtitle: Text(detail),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('promotions').doc(docs[index].id).update({'isActive': val});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showManageDialog(context, id: docs[index].id, data: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePromotion(docs[index].id),
                      ),
                    ],
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
        onPressed: () => _showManageDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มโปรโมชั่น"),
      ),
    );
  }
}