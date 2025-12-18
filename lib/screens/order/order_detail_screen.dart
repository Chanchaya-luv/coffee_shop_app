import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'print_bill_screen.dart';

// --- เปลี่ยนเป็น StatefulWidget เพื่อเก็บสถานะ _isExpanded ---
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isExpanded = false; // เก็บสถานะว่ากดดูเพิ่มเติมหรือยัง

  // --- ฟังก์ชันอัปเดตสถานะ ---
  void _updateStatus(BuildContext context, String currentStatus, String tableNo) {
    String newStatus = '';
    String actionLabel = '';

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
      return; 
    }

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
          // แปลง Map เป็น List เพื่อให้ง่ายต่อการตัดแสดงผล
          final itemEntries = itemCounts.entries.toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // ป้ายสถานะ
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

                      // --- Card รายการอาหาร ---
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
                            // --- 🔥 แสดงรายการแบบย่อ/ขยาย ---
                            ...itemEntries.take(_isExpanded ? itemEntries.length : 4).map((entry) {
                                String name = entry.key;
                                int qty = entry.value;
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
                            }).toList(),

                            // --- ปุ่มกดดูเพิ่มเติม ---
                            if (itemEntries.length > 4)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isExpanded ? "ย่อรายการ" : "ดูเพิ่มเติม (${itemEntries.length - 4} รายการ)",
                                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                      Icon(
                                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.grey,
                                      )
                                    ],
                                  ),
                                ),
                              ),

                            const Divider(height: 30),
                            
                            _buildPriceRow("ยอดรวมสินค้า", originalPrice, isBold: false),
                            
                            if (discount > 0)
                              _buildPriceRow("ส่วนลด", discount, color: Colors.red, isNegative: true),
                            
                            const Divider(),
                            _buildPriceRow("ยอดสุทธิ", totalPrice, isBold: true, color: const Color(0xFFA6C48A), fontSize: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Footer ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    if (status != 'completed' && status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getNextStatusColor(status),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _updateStatus(context, status, tableNo),
                          child: Text(_getNextStatusText(status), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PrintBillScreen(orderId: widget.orderId)));
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

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, Color color = Colors.black87, double fontSize = 16, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(
            "${isNegative ? '-' : ''}฿${amount.toStringAsFixed(0)}", 
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)
          ),
        ],
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