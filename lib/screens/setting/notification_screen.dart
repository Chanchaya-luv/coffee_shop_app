import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

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
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "ล้างการแจ้งเตือน",
            onPressed: () => _clearNotifications(context),
          ),
        ],
      ),
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
                _buildSectionHeader("⚠️ วัตถุดิบที่ต้องเติม (Low Stock)", Colors.red[800]!),
                _buildLowStockList(),

                const SizedBox(height: 10),

                _buildSectionHeader("🕒 กิจกรรมล่าสุด (Timeline)", const Color(0xFF5D4037)),
                // --- 🔥 ใช้ Widget Timeline แบบรวม ---
                _buildUnifiedTimeline(lastClearedAt), 
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

  // --- 🔥 2. Widget Timeline แบบรวม (Income + Expense) ---
  Widget _buildUnifiedTimeline(Timestamp? lastClearedAt) {
    // ใช้ StreamBuilder ซ้อนกันเพื่อดึงข้อมูลจาก 2 Collections
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).limit(30).snapshots(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('expenses').orderBy('date', descending: true).limit(30).snapshots(),
          builder: (context, expenseSnapshot) {
            if (!orderSnapshot.hasData || !expenseSnapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }

            // 1. แปลงข้อมูล Order
            List<Map<String, dynamic>> activities = [];
            for (var doc in orderSnapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['type'] = 'order'; // ระบุประเภท
              data['sortTime'] = data['timestamp']; // ใช้ timestamp ในการเรียง
              activities.add(data);
            }

            // 2. แปลงข้อมูล Expense
            for (var doc in expenseSnapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['type'] = 'expense';
              data['sortTime'] = data['date']; // ใช้ date ในการเรียง
              activities.add(data);
            }

            // 3. กรองและเรียงลำดับ
            var filteredActivities = activities.where((data) {
              Timestamp? ts = data['sortTime'];
              if (ts == null) return false;
              if (lastClearedAt != null && ts.compareTo(lastClearedAt) <= 0) return false;
              return true;
            }).toList();

            // เรียงใหม่สุดขึ้นก่อน
            filteredActivities.sort((a, b) {
              Timestamp t1 = a['sortTime'];
              Timestamp t2 = b['sortTime'];
              return t2.compareTo(t1);
            });

            if (filteredActivities.isEmpty) {
               return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีกิจกรรมใหม่", style: TextStyle(color: Colors.grey))));
            }

            // 4. แสดงผล
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                var data = filteredActivities[index];
                bool isLast = index == filteredActivities.length - 1;
                
                if (data['type'] == 'order') {
                  return _buildOrderTile(data, isLast);
                } else {
                  return _buildExpenseTile(data, isLast);
                }
              },
            );
          }
        );
      }
    );
  }

  // Widget แสดงรายการ Order (เงินเข้า)
  Widget _buildOrderTile(Map<String, dynamic> data, bool isLast) {
    String orderId = data['orderId'] ?? '-';
    String tableNo = data['tableNumber'] ?? '-';
    double totalPrice = (data['totalPrice'] ?? 0).toDouble();
    String method = data['paymentMethod'] ?? 'Cash';
    Timestamp ts = data['timestamp'];
    String timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());

    bool isQR = method == 'QR';
    Color iconColor = isQR ? Colors.blue : Colors.green;
    IconData iconData = isQR ? Icons.qr_code_2 : Icons.attach_money;

    return _buildTimelineItem(
      icon: iconData,
      iconColor: iconColor,
      timeStr: timeStr,
      title: "ได้รับเงินเข้า (Order #$orderId)",
      amount: "+฿${NumberFormat('#,##0').format(totalPrice)}",
      amountColor: iconColor,
      subtitle: "โต๊ะ: $tableNo | ${isQR ? 'PromptPay' : 'เงินสด'}",
      isLast: isLast,
    );
  }

  // Widget แสดงรายการ Expense (เงินออก)
  Widget _buildExpenseTile(Map<String, dynamic> data, bool isLast) {
    String title = data['title'] ?? 'รายจ่ายทั่วไป';
    double amount = (data['amount'] ?? 0).toDouble();
    Timestamp ts = data['date'];
    String timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());
    
    // --- 🔥 แก้ไข: ดึงชื่อคนบันทึกมาแสดง ---
    String recorder = data['recorder'] ?? 'Admin';

    return _buildTimelineItem(
      icon: Icons.money_off,
      iconColor: Colors.orange,
      timeStr: timeStr,
      title: "รายจ่าย: $title",
      amount: "-฿${NumberFormat('#,##0').format(amount)}",
      amountColor: Colors.red,
      subtitle: "บันทึกโดย $recorder", // ✅ แสดงชื่อจริง
      isLast: isLast,
    );
  }

  // Template สำหรับ Timeline Row
  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String timeStr,
    required String title,
    required String amount,
    required Color amountColor,
    required String subtitle,
    required bool isLast,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0), // ระยะห่างจัดการโดย Column ภายใน
      child: IntrinsicHeight( // ให้เส้นสูงเท่าเนื้อหา
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.grey[200])),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 15),
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
                          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                          Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
                          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}