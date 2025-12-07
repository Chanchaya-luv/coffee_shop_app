import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String orderId; // รับเลขคิว เช่น "0001"

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("สถานะออเดอร์", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('orderId', isEqualTo: orderId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text("ไม่พบออเดอร์หมายเลข #$orderId", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 10),
                  const Text("กรุณาติดต่อพนักงาน", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var doc = snapshot.data!.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          
          String status = data['status'] ?? 'pending';
          String displayId = data['orderId'] ?? '-';
          String tableNo = data['tableNumber'] ?? '-';
          
          List<String> items = [];
          if (data['items'] != null) {
             var raw = data['items'];
             if (raw is List) items = raw.map((e) => e.toString()).toList();
          }
          
          double totalPrice = 0.0;
          if (data['totalPrice'] != null) totalPrice = double.tryParse(data['totalPrice'].toString()) ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text("Order #$displayId", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                Text("โต๊ะ: $tableNo", style: const TextStyle(fontSize: 20, color: Colors.grey)),
                
                const SizedBox(height: 15),
                
                // --- 🔥 เพิ่มป้าย "จ่ายเงินแล้ว" ตรงนี้ ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text("จ่ายเงินแล้ว (Paid)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Step Indicator
                _buildStatusStepper(status),

                const SizedBox(height: 40),

                // รายการที่สั่ง
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("รายการของคุณ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Divider(),
                      if (items.isEmpty) const Text("- ไม่ระบุรายการ -", style: TextStyle(color: Colors.grey)),
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.coffee, size: 18, color: Color(0xFFA6C48A)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                      )).toList(),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("ยอดรวมสุทธิ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF5D4037))),
                        ],
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6F4E37), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("กลับหน้าหลัก / สั่งเพิ่ม", style: TextStyle(color: Color(0xFF5D4037), fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusStepper(String currentStatus) {
    int currentStep = 0;
    if (currentStatus == 'cooking') currentStep = 1;
    else if (currentStatus == 'served') currentStep = 2;
    else if (currentStatus == 'completed') currentStep = 3;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepCircle(0, currentStep, Icons.receipt_long, "รับออเดอร์"),
            _buildLine(0, currentStep),
            _buildStepCircle(1, currentStep, Icons.soup_kitchen, "กำลังทำ"),
            _buildLine(1, currentStep),
            _buildStepCircle(2, currentStep, Icons.room_service, "เสิร์ฟแล้ว"),
          ],
        ),
        if (currentStatus == 'completed')
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text("ออเดอร์เสร็จสิ้น ขอบคุณครับ/ค่ะ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildStepCircle(int stepIndex, int currentStep, IconData icon, String label) {
    bool isActive = currentStep >= stepIndex;
    Color color = isActive 
        ? (currentStep == stepIndex ? const Color(0xFF6F4E37) : const Color(0xFFA6C48A)) 
        : Colors.grey[300]!;
        
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
          fontSize: 12, 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? const Color(0xFF5D4037) : Colors.grey
        )),
      ],
    );
  }

  Widget _buildLine(int stepIndex, int currentStep) {
    bool isActive = currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA6C48A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}