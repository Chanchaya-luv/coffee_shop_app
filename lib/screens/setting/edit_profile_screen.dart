import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _nameCtrl.text = data['name'] ?? '';
        _photoCtrl.text = data['photoUrl'] ?? '';
        setState(() {}); // รีเฟรชหน้าจอ
      }
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().updateProfile(
        name: _nameCtrl.text.trim(),
        photoUrl: _photoCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลเรียบร้อย"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetPassword() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      AuthService().resetPassword(user.email!);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("ส่งลิงก์เปลี่ยนรหัสผ่านแล้ว"),
          content: Text("กรุณาตรวจสอบอีเมล ${user.email} เพื่อตั้งรหัสผ่านใหม่"),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ตกลง"))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(title: const Text("แก้ไขข้อมูลส่วนตัว"), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Preview รูป
            CircleAvatar(
              radius: 60,
              backgroundImage: _photoCtrl.text.isNotEmpty ? NetworkImage(_photoCtrl.text) : null,
              backgroundColor: Colors.grey[300],
              child: _photoCtrl.text.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
            ),
            const SizedBox(height: 30),
            
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "ชื่อที่แสดง", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 15),
            TextField(controller: _photoCtrl, decoration: const InputDecoration(labelText: "ลิงก์รูปโปรไฟล์ (URL)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), onChanged: (v) => setState((){})),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("บันทึกการเปลี่ยนแปลง", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _resetPassword, 
              icon: const Icon(Icons.lock_reset, color: Colors.grey), 
              label: const Text("ส่งอีเมลเปลี่ยนรหัสผ่าน", style: TextStyle(color: Colors.grey))
            )
          ],
        ),
      ),
    );
  }
}