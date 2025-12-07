import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// ✅ 1. เพิ่ม import นี้
import 'package:intl/date_symbol_data_local.dart'; 
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  
  // ✅ 2. สร้างตัวแปร Future เพื่อรอโหลดภาษา
  late Future<void> _initializeLocaleFuture;

  @override
  void initState() {
    super.initState();
    // ✅ 3. สั่งโหลดข้อมูลภาษาไทยตอนเริ่มหน้าจอ
    _initializeLocaleFuture = initializeDateFormatting('th', null);
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6F4E37),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 4. ใช้ FutureBuilder เพื่อรอให้ภาษาโหลดเสร็จก่อนแสดงผล
    return FutureBuilder(
      future: _initializeLocaleFuture,
      builder: (context, snapshot) {
        // ถ้ายังโหลดไม่เสร็จ ให้หมุนรอไปก่อน (กัน Error)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9F9F9),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // โหลดเสร็จแล้ว รันโค้ดแสดงผลได้เลย
        String dateFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);
        String displayDate = DateFormat('d MMMM yyyy', 'th').format(_selectedDate); 

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            title: const Text("ประวัติออเดอร์ย้อนหลัง", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF6F4E37),
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // --- ส่วนเลือกวันที่ ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("เลือกวันที่ดูประวัติ:", style: TextStyle(color: Colors.grey)),
                        Text(displayDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: Color(0xFFA6C48A)),
                      onPressed: () => _pickDate(context),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- รายการออเดอร์ ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("ไม่มีข้อมูล"));

                    // กรองข้อมูลตามวันที่เลือก
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['timestamp'] == null) return false;
                      
                      final ts = (data['timestamp'] as Timestamp).toDate();
                      final docDateStr = DateFormat('yyyy-MM-dd').format(ts);
                      
                      return docDateStr == dateFilter;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_toggle_off, size: 60, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text("ไม่พบออเดอร์ของวันที่ $dateFilter", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        var doc = filteredDocs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return _buildHistoryCard(doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildHistoryCard(String docId, Map<String, dynamic> data) {
    String orderIdDisplay = data['orderId']?.toString() ?? '---';
    String status = data['status'] ?? 'pending';
    double totalPrice = 0.0;
    if (data['totalPrice'] != null) totalPrice = double.tryParse(data['totalPrice'].toString()) ?? 0.0;
    
    String timeStr = "";
    if (data['timestamp'] != null) {
      timeStr = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.brown[100],
          child: const Icon(Icons.receipt, color: Colors.brown),
        ),
        title: Text("Order #$orderIdDisplay", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("เวลา: $timeStr | ฿${totalPrice.toStringAsFixed(0)}"),
        trailing: Chip(
          label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: status == 'completed' ? Colors.green : Colors.grey,
          padding: EdgeInsets.zero,
        ),
        onTap: () {
           Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(orderId: docId)));
        },
      ),
    );
  }
}