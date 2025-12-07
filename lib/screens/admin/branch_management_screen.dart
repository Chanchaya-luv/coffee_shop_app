import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BranchManagementScreen extends StatelessWidget {
  final bool isReadOnly; // รับค่ามา

  const BranchManagementScreen({super.key, this.isReadOnly = false});

  void _showManageBranchDialog(BuildContext context, {String? id, Map<String, dynamic>? data}) {
    // ... (โค้ด Dialog เดิม ไม่ต้องแก้ แต่เราจะไม่เรียกใช้ถ้าเป็น ReadOnly) ...
    // เพื่อความกระชับ ผมละโค้ด Dialog ไว้ (ใช้ของเดิมได้เลย)
    // แต่ถ้าคุณต้องการโค้ดเต็มๆ บอกได้ครับ
    
    // (ใส่โค้ด Dialog เดิมที่นี่)
    final isEditing = id != null;
    final nameCtrl = TextEditingController(text: isEditing ? data!['name'] : '');
    final addressCtrl = TextEditingController(text: isEditing ? data!['address'] : '');
    final phoneCtrl = TextEditingController(text: isEditing ? data!['phone'] : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "แก้ไขข้อมูลสาขา" : "เพิ่มสาขาใหม่"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ชื่อสาขา")),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "ที่อยู่")),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "เบอร์โทร")),
            ],
          ),
        ),
        actions: [
          if (isEditing) TextButton(onPressed: (){/*ลบ*/}, child: const Text("ลบ", style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () {
               // Logic บันทึก (เหมือนเดิม)
               if (nameCtrl.text.isNotEmpty) {
                 final Map<String, dynamic> branchData = {
                  'name': nameCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                 };
                 if (isEditing) FirebaseFirestore.instance.collection('branches').doc(id).update(branchData);
                 else {
                   branchData['createdAt'] = FieldValue.serverTimestamp();
                   FirebaseFirestore.instance.collection('branches').add(branchData);
                 }
                 Navigator.pop(ctx);
               }
            }, 
            child: const Text("บันทึก")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("จัดการสาขา (Branches)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store_mall_directory, size: 80, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("ยังไม่มีข้อมูลสาขา", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),
                  // --- 🔥 ซ่อนปุ่มถ้าเป็น Read Only ---
                  if (!isReadOnly)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), foregroundColor: Colors.white),
                      onPressed: () => _showManageBranchDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text("เพิ่มสาขาแรก"),
                    )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String id = docs[index].id;
              String name = data['name'] ?? 'ไม่ระบุชื่อ';
              String address = data['address'] ?? '-';
              String phone = data['phone'] ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6F4E37).withOpacity(0.1),
                    child: const Icon(Icons.store, color: Color(0xFF6F4E37)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("$address\n$phone"),
                  // --- 🔥 ซ่อนปุ่มแก้ไขถ้าเป็น Read Only ---
                  trailing: isReadOnly ? null : const Icon(Icons.edit, color: Colors.grey),
                  onTap: () {
                    // ถ้าไม่ Read Only ถึงจะกดแก้ไขได้
                    if (!isReadOnly) _showManageBranchDialog(context, id: id, data: data);
                  },
                ),
              );
            },
          );
        },
      ),
      // --- 🔥 ซ่อนปุ่ม FAB ถ้าเป็น Read Only ---
      floatingActionButton: isReadOnly 
          ? null 
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFA6C48A),
              foregroundColor: Colors.white,
              onPressed: () => _showManageBranchDialog(context),
              icon: const Icon(Icons.add),
              label: const Text("เพิ่มสาขา"),
            ),
    );
  }
}