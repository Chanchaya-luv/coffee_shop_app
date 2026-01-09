import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'promotion_management_screen.dart'; // 🔥 เพิ่ม Import นี้

class AddPromotionScreen extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;

  const AddPromotionScreen({super.key, this.id, this.data});

  @override
  State<AddPromotionScreen> createState() => _AddPromotionScreenState();
}

class _AddPromotionScreenState extends State<AddPromotionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(); // สำหรับส่วนลด (บาท)
  final _minQtyCtrl = TextEditingController();   // สำหรับจำนวนขั้นต่ำ
  
  // ตัวแปรสำหรับ Buy X Get Y
  final _buyXCtrl = TextEditingController();
  final _getYCtrl = TextEditingController();

  String _type = 'quantity_discount'; // quantity_discount, buy_x_get_y
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    // ถ้ามีข้อมูลส่งมา (แก้ไข) ให้ใส่ลงใน Controller
    if (widget.data != null) {
      _nameCtrl.text = widget.data!['name'] ?? '';
      _codeCtrl.text = widget.data!['code'] ?? '';
      _isActive = widget.data!['isActive'] ?? true;
      _type = widget.data!['type'] ?? 'quantity_discount';
      
      Map<String, dynamic> cond = widget.data!['conditions'] ?? {};
      
      if (_type == 'quantity_discount') {
        _discountCtrl.text = (cond['discountAmount'] ?? 0).toString();
        _minQtyCtrl.text = (cond['minQty'] ?? 0).toString();
      } else if (_type == 'buy_x_get_y') {
        _buyXCtrl.text = (cond['buy'] ?? 0).toString();
        _getYCtrl.text = (cond['get'] ?? 0).toString();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _discountCtrl.dispose();
    _minQtyCtrl.dispose();
    _buyXCtrl.dispose();
    _getYCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePromotion() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> conditions = {};
    
    if (_type == 'quantity_discount') {
      conditions = {
        'minQty': int.parse(_minQtyCtrl.text.trim()),
        'discountAmount': double.parse(_discountCtrl.text.trim()),
      };
    } else if (_type == 'buy_x_get_y') {
      conditions = {
        'buy': int.parse(_buyXCtrl.text.trim()),
        'get': int.parse(_getYCtrl.text.trim()),
      };
    }

    final data = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'type': _type,
      'isActive': _isActive,
      'conditions': conditions,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('promotions').add(data);
    } else {
      await FirebaseFirestore.instance.collection('promotions').doc(widget.id).update(data);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกโปรโมชั่นแล้ว"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.id != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "แก้ไขโปรโมชั่น" : "สร้างโปรโมชั่นใหม่", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        actions: [
            // --- 🔥 เพิ่มปุ่มไปหน้าจัดการโปรโมชั่น ---
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: "ดูโปรโมชั่นทั้งหมด",
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const PromotionManagementScreen())
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "ชื่อโปรโมชั่น", hintText: "เช่น ซื้อ 2 แก้ว ลด 5 บาท", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "กรุณากรอกชื่อ" : null,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: "รหัสโค้ดส่วนลด (Promo Code)", 
                  hintText: "เช่น SAVE5", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number)
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v!.isEmpty ? "กรุณากำหนดโค้ด" : null,
              ),
              
              const SizedBox(height: 20),
              const Text("ประเภทโปรโมชั่น", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text("ลดราคา (บาท)"),
                      subtitle: const Text("เช่น ซื้อ 2 ลด 5บ."),
                      value: 'quantity_discount',
                      groupValue: _type,
                      activeColor: const Color(0xFF6F4E37),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _type = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text("ของแถม (Free)"),
                      subtitle: const Text("เช่น ซื้อ 2 แถม 1"),
                      value: 'buy_x_get_y',
                      groupValue: _type,
                      activeColor: const Color(0xFF6F4E37),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _type = val!),
                    ),
                  ),
                ],
              ),
              
              const Divider(),
              const SizedBox(height: 10),
              
              // --- แสดงฟอร์มตามประเภท ---
              if (_type == 'quantity_discount') ...[
                const Text("เงื่อนไขการลดราคา", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "ซื้อครบ (แก้ว)", border: OutlineInputBorder(), suffixText: "แก้ว"),
                        validator: (v) => v!.isEmpty ? "ระบุจำนวน" : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "ลดทันที (บาท)", border: OutlineInputBorder(), suffixText: "บาท"),
                        validator: (v) => v!.isEmpty ? "ระบุยอดลด" : null,
                      ),
                    ),
                  ],
                ),
              ] else if (_type == 'buy_x_get_y') ...[
                const Text("เงื่อนไขของแถม", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyXCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "ซื้อ (Buy)", border: OutlineInputBorder(), suffixText: "ชิ้น"),
                        validator: (v) => v!.isEmpty ? "ระบุจำนวน" : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _getYCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "แถม (Get)", border: OutlineInputBorder(), suffixText: "ชิ้น"),
                        validator: (v) => v!.isEmpty ? "ระบุจำนวน" : null,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text("สถานะ: เปิดใช้งาน (Active)"),
                value: _isActive,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _isActive = val),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _savePromotion,
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? "บันทึกการแก้ไข" : "สร้างโปรโมชั่น"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}