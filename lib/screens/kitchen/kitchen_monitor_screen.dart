import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // อย่าลืมลง package: intl ใน pubspec.yaml

class KitchenMonitorScreen extends StatelessWidget {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ฟังก์ชันเปลี่ยนสถานะออเดอร์
  void _updateStatus(String orderId, String currentStatus) {
    String nextStatus = '';
    if (currentStatus == 'pending') nextStatus = 'cooking';
    else if (currentStatus == 'cooking') nextStatus = 'served';
    
    // ถ้าสถานะเปลี่ยนเป็น served อาจจะ trigger notification ไปหาพนักงานเสิร์ฟได้ตรงนี้
    if (nextStatus.isNotEmpty) {
      _db.collection('orders').doc(orderId).update({
        'status': nextStatus,
      });
    }
  }

  // คำนวณเวลาที่ผ่านไป (เช่น "5 นาทีที่แล้ว")
  String _timeAgo(Timestamp timestamp) {
    DateTime time = timestamp.toDate();
    Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "เมื่อสักครู่";
    return "${diff.inMinutes} นาทีที่แล้ว";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.red.shade100; // แดงอ่อน เตือนใจว่างานใหม่
      case 'cooking': return Colors.orange.shade100; // ส้ม กำลังลุย
      default: return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("👨‍🍳 Kitchen Monitor"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          // ตัวอย่าง Filter เลือกดูเฉพาะของร้อน/เย็น ได้ถ้าต้องการ
          IconButton(icon: Icon(Icons.filter_list), onPressed: () {})
        ],
      ),
      backgroundColor: Colors.blueGrey[50],
      body: StreamBuilder<QuerySnapshot>(
        // Query เฉพาะออเดอร์ที่ยังทำไม่เสร็จ (ตัด 'served' และ 'paid' ออก)
        // เรียงตามเวลา ใครมาก่อนต้องได้ทำก่อน (FIFO)
        stream: _db.collection('orders')
            .where('status', whereIn: ['pending', 'cooking'])
            .orderBy('timestamp', descending: false) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 20),
                  Text("เคลียร์ออเดอร์หมดแล้ว!", style: TextStyle(fontSize: 20, color: Colors.grey)),
                ],
              ),
            );
          }

          // ใช้ GridView เพื่อให้แสดงผลบน Tablet แนวนอนได้หลายใบพร้อมกัน
          return GridView.builder(
            padding: EdgeInsets.all(10),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300, // ความกว้างสูงสุดของการ์ดแต่ละใบ
              childAspectRatio: 0.7, // สัดส่วน กว้าง:สูง (ปรับตามความยาวเนื้อหา)
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var order = orders[index];
              var data = order.data() as Map<String, dynamic>;
              String status = data['status'];
              List items = data['items'] ?? [];

              return Card(
                elevation: 4,
                color: _getStatusColor(status),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    // --- Header: โต๊ะ และ เวลา ---
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "โต๊ะ ${data['tableNumber']}", 
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            data['timestamp'] != null ? _timeAgo(data['timestamp']) : '...',
                            style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // --- Body: รายการอาหาร ---
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (ctx, i) => Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              "${i + 1}. ${items[i]}", // แสดงลำดับ 1. ลาเต้...
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        },
                      ),
                    ),

                    // --- Footer: ปุ่ม Action ---
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'pending' ? Colors.blue : Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _updateStatus(order.id, status),
                          child: Text(
                            status == 'pending' ? "รับออเดอร์ (Cooking)" : "เสร็จแล้ว (Done)",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}