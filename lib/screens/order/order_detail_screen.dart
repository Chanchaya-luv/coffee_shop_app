import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'print_bill_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  // --- 🛠️ ฟังก์ชันอัปเดตสถานะ (แก้ไขให้รับ tableNo มาด้วย) ---
  void _updateStatus(BuildContext context, String currentStatus, String tableNo) {
    String newStatus = '';
    String actionLabel = '';

    // Logic เปลี่ยนสถานะตามลำดับ
    if (currentStatus == 'pending') {
      newStatus = 'cooking';
      actionLabel = 'เริ่มทำอาหาร (Cooking)';
    } else if (currentStatus == 'cooking') {
      newStatus = 'served';
      actionLabel = 'เสิร์ฟ/พร้อมส่ง (Served)';
    } else if (currentStatus == 'served') {
      newStatus = 'completed';
      actionLabel = 'จบออเดอร์ (Completed)';
    } else {
      return; // ถ้าจบแล้วไม่ต้องทำอะไร
    }

    // 1. อัปเดตสถานะออเดอร์
    FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
    });

    // --- 🔥 2. จุดสำคัญ: ถ้าจบออเดอร์ ให้เปลี่ยนสถานะโต๊ะเป็น "ว่าง" (สีเขียว) ---
    if (newStatus == 'completed') {
      // เช็คว่าเป็นเลขโต๊ะไหม (ถ้าเป็น TA หรือขีด - ไม่ต้องทำ)
      if (int.tryParse(tableNo) != null) {
        FirebaseFirestore.instance.collection('tables').doc(tableNo).set({
          'id': tableNo,
          'status': 'available' // ✅ คืนสถานะว่างทันที
        }, SetOptions(merge: true));
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("อัปเดตสถานะเป็น: $actionLabel")),
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
        title: const Text("รายละเอียดออเดอร์", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูลออเดอร์"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          String displayId = data['orderId'] ?? 'Unknown';
          String tableNo = data['tableNumber'] ?? '-';
          String status = data['status'] ?? 'pending';
          Timestamp? ts = data['timestamp'];
          String dateStr = ts != null ? DateFormat('d MMM yy, HH.mm น.').format(ts.toDate()) : '-';
          double totalPrice = (data['totalPrice'] ?? 0).toDouble();

          List<dynamic> rawItems = data['items'] ?? [];
          Map<String, int> itemCounts = {};
          for (var item in rawItems) {
            itemCounts[item] = (itemCounts[item] ?? 0) + 1;
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // แสดงสถานะ
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          "สถานะ: ${_getStatusText(status)}",
                          style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text("Order #$displayId - $tableNo", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                      Text(dateStr, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      
                      const SizedBox(height: 20),

                      // รายการอาหาร
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: itemCounts.length,
                              itemBuilder: (context, index) {
                                String name = itemCounts.keys.elementAt(index);
                                int qty = itemCounts[name]!;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                      CircleAvatar(
                                        backgroundColor: Colors.brown[50],
                                        radius: 15,
                                        child: Text("x$qty", style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("ยอดรวม", style: TextStyle(fontWeight: FontWeight.bold)),
                                Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFA6C48A))),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    // ปุ่มเปลี่ยนสถานะ
                    if (status != 'completed' && status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getNextStatusColor(status),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          // --- 🔥 เรียกใช้ฟังก์ชันโดยส่ง tableNo เข้าไปด้วย ---
                          onPressed: () => _updateStatus(context, status, tableNo),
                          child: Text(_getNextStatusText(status), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    
                    const SizedBox(height: 10),

                    // ปุ่มพิมพ์บิล
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PrintBillScreen(orderId: orderId)));
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text("พิมพ์บิล"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5D4037), 
                          side: const BorderSide(color: Color(0xFF5D4037)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'cooking': return Colors.blue;
      case 'served': return Colors.purple;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return "รอทำ (Pending)";
      case 'cooking': return "กำลังทำ (Cooking)";
      case 'served': return "พร้อมเสิร์ฟ (Served)";
      case 'completed': return "เสร็จสิ้น (Completed)";
      default: return status;
    }
  }

  String _getNextStatusText(String status) {
    switch (status) {
      case 'pending': return "รับออเดอร์ (เริ่มทำ)";
      case 'cooking': return "ทำเสร็จแล้ว (พร้อมเสิร์ฟ)";
      case 'served': return "จบงาน (รับเงิน/เก็บโต๊ะ)";
      default: return "";
    }
  }

  Color _getNextStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.blue;
      case 'cooking': return Colors.purple;
      case 'served': return Colors.green;
      default: return Colors.grey;
    }
  }
}