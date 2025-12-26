import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LoginHistoryScreen extends StatelessWidget {
  const LoginHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ประวัติการเข้าใช้งาน (Log)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('login_logs')
            .orderBy('timestamp', descending: true) // ล่าสุดขึ้นก่อน
            .limit(100) // ดู 100 รายการล่าสุด
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("ยังไม่มีประวัติการเข้าใช้งาน", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              
              String name = data['name'] ?? 'Unknown';
              String email = data['email'] ?? '-';
              String role = data['role'] ?? 'staff';
              Timestamp? ts = data['timestamp'];
              String timeStr = ts != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(ts.toDate()) : '-';

              // กำหนดสีและไอคอนตามยศ
              Color roleColor = Colors.grey;
              IconData roleIcon = Icons.person;
              if (role == 'owner') { roleColor = Colors.orange; roleIcon = Icons.star; }
              else if (role == 'manager') { roleColor = Colors.blue; roleIcon = Icons.manage_accounts; }
              else if (role == 'admin') { roleColor = Colors.purple; roleIcon = Icons.security; }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Icon(roleIcon, color: roleColor),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("เข้าสู่ระบบเมื่อ: $timeStr", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: roleColor.withOpacity(0.5)),
                  ),
                  child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}