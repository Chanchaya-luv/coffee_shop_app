import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ประวัติสต๊อก (Stock Logs)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stock_logs')
            .orderBy('timestamp', descending: true) // ใหม่สุดขึ้นก่อน
            .limit(100) // ดูแค่ 100 รายการล่าสุดพอก่อน
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("ยังไม่มีประวัติการเคลื่อนไหว", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              String name = data['ingredientName'] ?? '-';
              double change = (data['changeAmount'] ?? 0).toDouble();
              double remaining = (data['remainingStock'] ?? 0).toDouble();
              String reason = data['reason'] ?? '';
              // --- 🔥 ดึงชื่อคนทำรายการ ---
              String recorder = data['recorder'] ?? 'System';
              
              Timestamp? ts = data['timestamp'];
              String timeStr = ts != null ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : '-';

              bool isAdded = change > 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: isAdded ? Colors.green[50] : Colors.red[50],
                  child: Icon(
                    isAdded ? Icons.add : Icons.remove, 
                    color: isAdded ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$timeStr • $reason"),
                    // --- 🔥 แสดงชื่อคนทำรายการ ---
                    if (recorder != 'System')
                      Text("โดย: $recorder", style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${isAdded ? '+' : ''}$change",
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isAdded ? Colors.green : Colors.red
                      ),
                    ),
                    Text(
                      "คงเหลือ: $remaining",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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