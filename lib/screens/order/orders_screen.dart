import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        // เปลี่ยนชื่อหัวข้อให้ชัดเจนว่าดูของวันนี้
        title: const Text("ออเดอร์วันนี้ (Today)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFA6C48A),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: "ทั้งหมด"), Tab(text: "ระหว่างทำ"), Tab(text: "เสร็จสิ้น")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList("all"),
          _buildOrderList("active"),
          _buildOrderList("completed"),
        ],
      ),
    );
  }

  Widget _buildOrderList(String filterType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // --- 🔥 กรองเฉพาะ "วันนี้" ---
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] == null) return false;
          
          final ts = (data['timestamp'] as Timestamp).toDate();
          final dateStr = DateFormat('yyyy-MM-dd').format(ts);
          
          return dateStr == todayStr; // เอาเฉพาะที่วันที่ตรงกับวันนี้
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.today, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("ยังไม่มีออเดอร์สำหรับวันนี้", style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          );
        }

        // เรียงลำดับ (ใหม่ -> เก่า)
        docs.sort((a, b) {
          Timestamp? t1 = (a.data() as Map)['timestamp'];
          Timestamp? t2 = (b.data() as Map)['timestamp'];
          if (t1 == null || t2 == null) return 0;
          return t2.compareTo(t1);
        });

        // กรองตาม Tab (Status Filter)
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? 'pending';
          
          if (filterType == 'active') return ['pending', 'cooking', 'served'].contains(status);
          if (filterType == 'completed') return ['paid', 'completed', 'cancelled'].contains(status);
          return true; 
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("ไม่มีรายการในสถานะนี้"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String docId, Map<String, dynamic> data) {
    String orderIdDisplay = data['orderId']?.toString() ?? '---';
    if (orderIdDisplay.length < 3) orderIdDisplay = "#$orderIdDisplay";
    
    String status = data['status']?.toString() ?? 'pending';
    String tableNo = data['tableNumber']?.toString() ?? '-';
    double totalPrice = 0.0;
    if (data['totalPrice'] != null) totalPrice = double.tryParse(data['totalPrice'].toString()) ?? 0.0;

    String itemsText = "ไม่ระบุรายการ";
    if (data['items'] != null) {
      var itemsRaw = data['items'];
      if (itemsRaw is List && itemsRaw.isNotEmpty) {
        itemsText = itemsRaw.join(", ");
      }
    }

    String timeStr = "";
    if (data['timestamp'] != null) {
      timeStr = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
    }

    bool isTakeAway = tableNo.toUpperCase().contains("TA");
    Color boxColor = isTakeAway ? Colors.orange : const Color(0xFFA6C48A);
    String boxText = isTakeAway ? "TA" : tableNo;

    Color statusColor = Colors.orange;
    String statusText = "รอทำ";
    if (status == 'cooking') { statusColor = Colors.blue; statusText = "กำลังทำ"; }
    else if (status == 'served') { statusColor = Colors.purple; statusText = "เสิร์ฟแล้ว"; }
    else if (status == 'completed') { statusColor = Colors.green; statusText = "เสร็จสิ้น"; }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(orderId: docId)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(boxText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Order $orderIdDisplay", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037))),
                        Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(itemsText, style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor, width: 0.5)),
                          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    )
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}