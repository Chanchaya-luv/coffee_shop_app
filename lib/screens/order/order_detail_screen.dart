import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'print_bill_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isExpanded = false; // เก็บสถานะการย่อ/ขยายรายการ

  // --- 🔥 ฟังก์ชันอัปเดตสถานะ (ปรับปรุงใหม่) ---
  void _handleStatusChange(BuildContext context, String currentStatus, String tableNo, String paymentMethod, double totalPrice) {
    
    // 1. ถ้าสถานะเป็น "รอทำ" (Pending) -> ให้ยืนยันการชำระเงินก่อน
    if (currentStatus == 'pending') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("ยืนยันการชำระเงิน"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("ตรวจสอบยอดเงินก่อนเริ่มทำออเดอร์"),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(paymentMethod == 'QR' ? Icons.qr_code : Icons.money, size: 20, color: paymentMethod == 'QR' ? Colors.blue : Colors.green),
                        const SizedBox(width: 5),
                        Text(paymentMethod == 'QR' ? "QR PromptPay" : "เงินสด (Cash)", style: TextStyle(fontWeight: FontWeight.bold, color: paymentMethod == 'QR' ? Colors.blue : Colors.green)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("ได้รับเงินครบถ้วนแล้วใช่หรือไม่?", style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatusInDb('cooking', 'ยืนยันรับเงิน & เริ่มทำ', tableNo);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle),
              label: const Text("รับเงินแล้ว / เริ่มทำ"),
            ),
          ],
        ),
      );
    } 
    // 2. สถานะอื่นๆ -> อัปเดตตามปกติ
    else if (currentStatus == 'cooking') {
      _updateStatusInDb('served', 'เสิร์ฟ/พร้อมส่ง', tableNo);
    } else if (currentStatus == 'served') {
      _updateStatusInDb('completed', 'จบออเดอร์', tableNo);
    }
  }

  void _updateStatusInDb(String newStatus, String actionLabel, String tableNo) {
    FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'status': newStatus,
    });

    if (newStatus == 'completed') {
      if (int.tryParse(tableNo) != null) {
        FirebaseFirestore.instance.collection('tables').doc(tableNo).update({
          'status': 'available' 
        }).catchError((e){});
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("บันทึกสถานะ: $actionLabel")),
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
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
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
          String paymentMethod = data['paymentMethod'] ?? 'Cash';
          
          Timestamp? ts = data['timestamp'];
          String dateStr = ts != null ? DateFormat('d MMM yy, HH.mm น.').format(ts.toDate()) : '-';
          
          double totalPrice = (data['totalPrice'] ?? 0).toDouble();
          double discount = (data['discount'] ?? 0).toDouble();
          double originalPrice = totalPrice + discount;

          List<dynamic> rawItems = data['items'] ?? [];
          Map<String, int> itemCounts = {};
          for (var item in rawItems) {
            itemCounts[item] = (itemCounts[item] ?? 0) + 1;
          }
          final itemEntries = itemCounts.entries.toList();

          bool isQR = paymentMethod == 'QR';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // --- 🔥 ส่วนแสดงสถานะการชำระเงิน (เพิ่มใหม่) ---
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.5), width: 2),
                          boxShadow: [BoxShadow(color: _getStatusColor(status).withOpacity(0.1), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("สถานะ: ${_getStatusText(status)}", style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(isQR ? Icons.qr_code : Icons.payments, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text("จ่ายด้วย: ${isQR ? 'QR PromptPay' : 'เงินสด'}", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 30),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),
                      Text("Order #$displayId - $tableNo", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                      Text(dateStr, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      
                      const SizedBox(height: 20),

                      // Card รายการอาหาร
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
                            ...itemEntries.take(_isExpanded ? itemEntries.length : 4).map((entry) {
                                String name = entry.key;
                                int qty = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            }).toList(),

                            if (itemEntries.length > 4)
                              InkWell(
                                onTap: () => setState(() => _isExpanded = !_isExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_isExpanded ? "ย่อรายการ" : "ดูเพิ่มเติม (${itemEntries.length - 4} รายการ)", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                      Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey)
                                    ],
                                  ),
                                ),
                              ),

                            const Divider(height: 30),
                            _buildPriceRow("ยอดรวมสินค้า", originalPrice, isBold: false),
                            if (discount > 0) _buildPriceRow("ส่วนลด", discount, color: Colors.red, isNegative: true),
                            const Divider(),
                            _buildPriceRow("ยอดสุทธิ", totalPrice, isBold: true, color: const Color(0xFFA6C48A), fontSize: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer: ปุ่มจัดการ
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                child: Column(
                  children: [
                    if (status != 'completed' && status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getNextStatusColor(status),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          // --- 🔥 กดปุ่มนี้แล้วไปเช็ค Logic ---
                          onPressed: () => _handleStatusChange(context, status, tableNo, paymentMethod, totalPrice),
                          icon: Icon(status == 'pending' ? Icons.payment : Icons.check, color: Colors.white),
                          label: Text(_getNextStatusText(status), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PrintBillScreen(orderId: widget.orderId))),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text("พิมพ์ใบเสร็จ"),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5D4037), side: const BorderSide(color: Color(0xFF5D4037)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, Color color = Colors.black87, double fontSize = 16, bool isNegative = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)), Text("${isNegative ? '-' : ''}฿${amount.toStringAsFixed(0)}", style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color))]));
  }

  Color _getStatusColor(String status) {
    switch (status) { case 'pending': return Colors.orange; case 'cooking': return Colors.blue; case 'served': return Colors.purple; case 'completed': return Colors.green; default: return Colors.grey; }
  }
  String _getStatusText(String status) {
    switch (status) { case 'pending': return "รอการชำระ/ยืนยัน"; case 'cooking': return "กำลังทำ"; case 'served': return "พร้อมเสิร์ฟ"; case 'completed': return "เสร็จสิ้น"; default: return status; }
  }
  IconData _getStatusIcon(String status) {
    switch (status) { case 'pending': return Icons.pending_actions; case 'cooking': return Icons.soup_kitchen; case 'served': return Icons.room_service; case 'completed': return Icons.check_circle; default: return Icons.help; }
  }
  String _getNextStatusText(String status) {
    switch (status) { case 'pending': return "ยืนยันรับเงิน & เริ่มทำ"; case 'cooking': return "ทำเสร็จแล้ว (พร้อมเสิร์ฟ)"; case 'served': return "จบงาน (เก็บโต๊ะ)"; default: return ""; }
  }
  Color _getNextStatusColor(String status) {
    switch (status) { case 'pending': return Colors.green[700]!; case 'cooking': return Colors.purple; case 'served': return Colors.grey; default: return Colors.grey; }
  }
}