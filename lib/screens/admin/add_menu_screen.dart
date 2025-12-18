import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMenuScreen extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;

  const AddMenuScreen({super.key, this.id, this.data});

  @override
  State<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends State<AddMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _imageUrlCtrl;
  
  final List<String> _categories = ["กาแฟ", "ชา", "นมสด", "ผลไม้", "เบเกอรี่","อื่นๆ"];
  String _selectedCategory = "กาแฟ";
  bool _isAvailable = true; // ตัวแปรสถานะ

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data?['name'] ?? '');
    _priceCtrl = TextEditingController(text: widget.data != null ? widget.data!['price'].toString() : '');
    _imageUrlCtrl = TextEditingController(text: widget.data?['imageUrl'] ?? '');
    
    if (widget.data != null) {
      String cat = widget.data!['category'] ?? 'กาแฟ';
      if (!_categories.contains(cat)) _categories.add(cat);
      _selectedCategory = cat;
      _isAvailable = widget.data!['isAvailable'] ?? true; // ดึงค่าเดิม
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        'category': _selectedCategory,
        'imageUrl': _imageUrlCtrl.text.trim(),
        'isAvailable': _isAvailable, // บันทึกสถานะ
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.id == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['recipe'] = [];
        await FirebaseFirestore.instance.collection('menu_items').add(data);
      } else {
        await FirebaseFirestore.instance.collection('menu_items').doc(widget.id).update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกเรียบร้อย"), backgroundColor: Colors.green));
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // (ฟังก์ชันลบ _deleteMenu ใช้ตัวเดิม)
  Future<void> _deleteMenu() async {
      // ... (ก๊อปจากโค้ดเดิมได้เลยครับ Logic การลบเหมือนเดิม)
      // เพื่อความกระชับ ขอละไว้ในฐานที่เข้าใจ
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("ยืนยันการลบ"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ลบ", style: TextStyle(color: Colors.red)))]));
      if (confirm == true) { await FirebaseFirestore.instance.collection('menu_items').doc(widget.id).delete(); if(mounted) Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.id != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(title: Text(isEditing ? "แก้ไขเมนู" : "เพิ่มเมนูใหม่"), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white, actions: [if (isEditing) IconButton(icon: const Icon(Icons.delete), onPressed: _isLoading ? null : _deleteMenu)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "ชื่อเมนู", border: OutlineInputBorder(), filled: true, fillColor: Colors.white), validator: (val) => val!.isEmpty ? 'กรุณากรอกชื่อ' : null),
              const SizedBox(height: 15),
              TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "ราคา", border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixText: "บาท"), validator: (val) => val!.isEmpty ? 'กรุณากรอกราคา' : null),
              const SizedBox(height: 15),
              DropdownButtonFormField(value: _selectedCategory, items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (val) => setState(() => _selectedCategory = val!), decoration: const InputDecoration(labelText: "หมวดหมู่", border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 15),
              TextFormField(controller: _imageUrlCtrl, decoration: const InputDecoration(labelText: "ลิงก์รูปภาพ", border: OutlineInputBorder(), filled: true, fillColor: Colors.white, prefixIcon: Icon(Icons.image))),
              
              const SizedBox(height: 20),
              
              // --- 🔥 สวิตช์เปิด/ปิด ของหมด ---
              SwitchListTile(
                title: const Text("สถานะสินค้า"),
                subtitle: Text(_isAvailable ? "พร้อมขาย (In Stock)" : "ของหมด (Out of Stock)", style: TextStyle(color: _isAvailable ? Colors.green : Colors.red)),
                value: _isAvailable,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _isAvailable = val),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              ),

              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isLoading ? null : _saveMenu, icon: const Icon(Icons.save), label: Text(isEditing ? "บันทึกการแก้ไข" : "บันทึกสินค้า", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }
}