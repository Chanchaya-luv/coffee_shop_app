import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BranchManagementScreen extends StatelessWidget {
  const BranchManagementScreen({super.key});

  // ฟังก์ชันแสดง Dialog เพิ่ม/แก้ไข สาขา
  void _showManageBranchDialog(BuildContext context, {String? id, Map<String, dynamic>? data}) {
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
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "ชื่อสาขา", hintText: "เช่น สาขาสยาม, สาขาลาดพร้าว", prefixIcon: Icon(Icons.store)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: "ที่อยู่ / จุดสังเกต", prefixIcon: Icon(Icons.location_on)),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "เบอร์โทรศัพท์สาขา", prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text("ยืนยันการลบ"),
                    content: Text("ต้องการลบ '${nameCtrl.text}' ใช่หรือไม่?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("ยกเลิก")),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("ลบ", style: TextStyle(color: Colors.red))),
                    ],
                  )
                );

                if (confirm == true) {
                  FirebaseFirestore.instance.collection('branches').doc(id).delete();
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text("ลบ", style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final Map<String, dynamic> branchData = {
                  'name': nameCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  FirebaseFirestore.instance.collection('branches').doc(id).update(branchData);
                } else {
                  branchData['createdAt'] = FieldValue.serverTimestamp();
                  FirebaseFirestore.instance.collection('branches').add(branchData);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? "บันทึก" : "เพิ่มสาขา"),
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(address, style: const TextStyle(fontSize: 12)))],),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.phone, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(phone, style: const TextStyle(fontSize: 12, color: Colors.blue))],),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                  onTap: () => _showManageBranchDialog(context, id: id, data: data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFA6C48A),
        foregroundColor: Colors.white,
        onPressed: () => _showManageBranchDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มสาขา"),
      ),
    );
  }
}