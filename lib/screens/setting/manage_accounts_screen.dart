import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUserRole = 'staff'; // ค่าเริ่มต้นให้เป็นแค่พนักงานก่อน (ปลอดภัยไว้ก่อน)
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserRole();
  }

  // --- 🔥 ฟังก์ชันเช็คยศคนล็อกอิน ---
  Future<void> _checkCurrentUserRole() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (doc.exists) {
        setState(() {
          _currentUserRole = doc.data()?['role'] ?? 'staff';
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      print("Error checking role: $e");
      setState(() => _isLoadingRole = false);
    }
  }

  // เช็คว่ามีสิทธิ์บริหารจัดการไหม (ต้องเป็น manager หรือ owner)
  bool get _canManage {
    return _currentUserRole == 'manager' || _currentUserRole == 'owner';
  }

  void _showEmployeeDialog({String? id, Map<String, dynamic>? data}) {
    final isEditing = id != null;
    
    final emailCtrl = TextEditingController(text: isEditing ? (data!['email'] ?? '') : '');
    final passCtrl = TextEditingController(); 
    final nameCtrl = TextEditingController(text: isEditing ? (data!['name'] ?? '') : '');
    final photoCtrl = TextEditingController(text: isEditing ? (data!['photoUrl'] ?? '') : '');
    
    String selectedRole = isEditing ? (data!['role'] ?? 'staff') : 'staff';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "แก้ไขข้อมูลพนักงาน" : "เพิ่มบัญชีพนักงาน"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ชื่อพนักงาน", prefixIcon: Icon(Icons.badge))),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "อีเมล (Login)", prefixIcon: Icon(Icons.email)), enabled: !isEditing),
                if (!isEditing) TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "รหัสผ่าน", prefixIcon: Icon(Icons.key)), obscureText: true),
                TextField(controller: photoCtrl, decoration: const InputDecoration(labelText: "ลิงก์รูป (URL)", prefixIcon: Icon(Icons.image))),
                const SizedBox(height: 15),
                
                // เลือกตำแหน่ง
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "ตำแหน่ง / ยศ", border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'staff', child: Text("พนักงานทั่วไป (Staff)")),
                    const DropdownMenuItem(value: 'manager', child: Text("ผู้จัดการ (Manager)")),
                    // ให้เฉพาะ Owner เท่านั้นที่ตั้งคนอื่นเป็น Admin ได้ (ป้องกัน Manager ยึดอำนาจ)
                    if (_currentUserRole == 'owner') // 🔥
                       const DropdownMenuItem(value: 'admin', child: Text("ผู้ดูแลระบบ (Admin)")),
                  ],
                  onChanged: (val) => setState(() => selectedRole = val!),
                ),

                if (isEditing) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  TextButton.icon(
                    icon: const Icon(Icons.lock_reset, color: Colors.orange),
                    label: const Text("ส่งอีเมลรีเซ็ตรหัสผ่าน", style: TextStyle(color: Colors.orange)),
                    onPressed: () async {
                      try {
                        await AuthService().resetPassword(emailCtrl.text);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ส่งลิงก์แล้ว"), backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ส่งไม่สำเร็จ"), backgroundColor: Colors.red));
                      }
                    },
                  )
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  try {
                    if (isEditing) {
                      await AuthService().updateEmployeeData(id!, nameCtrl.text.trim(), selectedRole);
                    } else {
                      if (emailCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                        await AuthService().createEmployee(emailCtrl.text.trim(), passCtrl.text.trim(), nameCtrl.text.trim(), selectedRole, photoCtrl.text.trim());
                      }
                    }
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? "บันทึกแล้ว" : "เพิ่มสำเร็จ"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(isEditing ? "บันทึก" : "สร้างบัญชี"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("บัญชีและพนักงาน", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_,__) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String id = docs[index].id;
              String name = data['name'] ?? 'ไม่ระบุชื่อ';
              String role = data['role'] ?? 'staff';
              String email = data['email'] ?? '-';
              String photoUrl = data['photoUrl'] ?? '';

              String roleText = "พนักงานทั่วไป";
              Color roleColor = Colors.grey;
              if (role == 'owner') { roleText = "เจ้าของร้าน 👑"; roleColor = Colors.orange; }
              else if (role == 'manager') { roleText = "ผู้จัดการ"; roleColor = Colors.blue; }
              else if (role == 'admin') { roleText = "แอดมิน"; roleColor = Colors.purple; }

              bool isMe = id == currentUserId;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    backgroundColor: Colors.brown[100],
                    child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.brown) : null,
                  ),
                  title: Text(name + (isMe ? " (ฉัน)" : ""), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: roleColor, width: 0.5)),
                        child: Text(roleText, style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  // --- 🔥 จุดสำคัญ: ซ่อนปุ่มถ้าไม่ใช่ Manager/Owner ---
                  trailing: _canManage 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEmployeeDialog(id: id, data: data),
                            ),
                            // ห้ามลบเจ้าของร้าน และ ห้ามลบตัวเอง
                            if (role != 'owner' && !isMe)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text("ยืนยัน"), content: Text("ลบผู้ใช้ $name?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("ยกเลิก")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("ลบ", style: TextStyle(color: Colors.red)))]));
                                  if (confirm == true) {
                                    FirebaseFirestore.instance.collection('users').doc(id).delete();
                                  }
                                },
                              ),
                          ],
                        )
                      : null, // ถ้าเป็น staff ธรรมดา ไม่โชว์ปุ่มอะไรเลย
                ),
              );
            },
          );
        },
      ),
      // --- 🔥 ซ่อนปุ่มเพิ่มพนักงาน ถ้าไม่ใช่ Manager/Owner ---
      floatingActionButton: _canManage 
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFA6C48A),
              foregroundColor: Colors.white,
              onPressed: () => _showEmployeeDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text("เพิ่มพนักงาน"),
            )
          : null, // Staff เพิ่มไม่ได้
    );
  }
}