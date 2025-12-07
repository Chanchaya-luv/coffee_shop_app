import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // --- ฟังก์ชันกดเคลียร์ (บันทึกเวลาปัจจุบันลง Database) ---
  Future<void> _clearNotifications(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ล้างประวัติแจ้งเตือน"),
        content: const Text("คุณต้องการซ่อนการแจ้งเตือนเก่าทั้งหมดใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ล้าง", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // บันทึกเวลาปัจจุบันลง metadata
      await FirebaseFirestore.instance.collection('metadata').doc('notifications').set({
        'lastClearedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ล้างการแจ้งเตือนแล้ว")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("การแจ้งเตือนทั้งหมด", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          // --- 🔥 ปุ่มถังขยะ (เคลียร์แจ้งเตือน) ---
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "ล้างการแจ้งเตือน",
            onPressed: () => _clearNotifications(context),
          ),
        ],
      ),
      // 1. ดึงเวลาที่เคลียร์ล่าสุดมาก่อน
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('metadata').doc('notifications').snapshots(),
        builder: (context, metaSnapshot) {
          
          Timestamp? lastClearedAt;
          if (metaSnapshot.hasData && metaSnapshot.data!.exists) {
            final data = metaSnapshot.data!.data() as Map<String, dynamic>;
            lastClearedAt = data['lastClearedAt'] as Timestamp?;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ส่วนที่ 1: แจ้งเตือนวัตถุดิบ (อันนี้ไม่ควรเคลียร์ เพราะเป็นสถานะจริง) ---
                _buildSectionHeader("⚠️ วัตถุดิบที่ต้องเติม (Low Stock)", Colors.red[800]!),
                _buildLowStockList(),

                const SizedBox(height: 10),

                // --- ส่วนที่ 2: ไทม์ไลน์กิจกรรม (เคลียร์ได้) ---
                _buildSectionHeader("🕒 กิจกรรมล่าสุด (Money & Orders)", const Color(0xFF5D4037)),
                _buildActivityTimeline(lastClearedAt), // ส่งเวลาไปกรอง
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Icon(Icons.label_important, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 1. Stream วัตถุดิบ (เหมือนเดิม)
  Widget _buildLowStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ingredients').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator(minHeight: 2));
        
        var lowStockItems = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          double current = (data['currentStock'] ?? 0).toDouble();
          double min = (data['minThreshold'] ?? 0).toDouble();
          return current <= min;
        }).toList();

        if (lowStockItems.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("สต๊อกวัตถุดิบเพียงพอทุกรายการ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            var data = lowStockItems[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.red[50],
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                ),
                title: Text(data['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text("เหลือ: ${data['currentStock']} ${data['unit']} (ต่ำกว่ากำหนด)", style: TextStyle(fontSize: 12, color: Colors.red[800])),
                trailing: const Text("เติมด่วน", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Stream กิจกรรม (เพิ่ม Logic การกรองเวลา)
  Widget _buildActivityTimeline(Timestamp? lastClearedAt) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(50) // ดึงมาเยอะหน่อย แล้วค่อยกรองออก
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
        
        // --- 🔥 กรองข้อมูล: เอาเฉพาะที่เกิด "หลัง" จากเวลาที่กดเคลียร์ ---
        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] == null) return false;
          
          // ถ้าเคยกดเคลียร์ ให้เช็คว่าเก่าน่ากว่าเวลาที่เคลียร์ไหม
          if (lastClearedAt != null) {
            Timestamp orderTime = data['timestamp'];
            // ถ้าเวลาของออเดอร์ น้อยกว่า เวลาที่กดเคลียร์ -> ซ่อน
            if (orderTime.compareTo(lastClearedAt) <= 0) return false;
          }
          return true;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("ไม่มีกิจกรรมใหม่", style: TextStyle(color: Colors.grey))));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            
            String orderId = data['orderId'] ?? '-';
            String tableNo = data['tableNumber'] ?? '-';
            double totalPrice = (data['totalPrice'] ?? 0).toDouble();
            String method = data['paymentMethod'] ?? 'Cash';
            
            String timeStr = "เมื่อสักครู่";
            if (data['timestamp'] != null) {
              Timestamp ts = data['timestamp'];
              timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());
            }

            bool isQR = method == 'QR';
            Color iconColor = isQR ? Colors.blue : Colors.green;
            IconData iconData = isQR ? Icons.qr_code_2 : Icons.attach_money;

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: iconColor.withOpacity(0.5)),
                        ),
                        child: Icon(iconData, size: 18, color: iconColor),
                      ),
                      if (index != docs.length - 1)
                        Container(width: 2, height: 40, color: Colors.grey[200]),
                    ],
                  ),
                  const SizedBox(width: 15),
                  
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("ได้รับเงินเข้า (Order #$orderId)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("฿${NumberFormat('#,##0').format(totalPrice)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: iconColor)),
                              const SizedBox(width: 5),
                              Text("ผ่านช่องทาง ${isQR ? 'QR PromptPay' : 'เงินสด'}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF6F4E37).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text("โต๊ะ: $tableNo", style: const TextStyle(fontSize: 10, color: Color(0xFF6F4E37), fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}