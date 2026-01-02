import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 เพิ่ม Import นี้
import '../../models/model_menu.dart';

class VisualProductCustomizeDialog extends StatefulWidget {
  final MenuItem menu;
  final Function(String sweetness, String milk, String type, double priceAdjustment) onConfirm;

  const VisualProductCustomizeDialog({
    super.key,
    required this.menu,
    required this.onConfirm,
  });

  @override
  State<VisualProductCustomizeDialog> createState() => _VisualProductCustomizeDialogState();
}

class _VisualProductCustomizeDialogState extends State<VisualProductCustomizeDialog> with TickerProviderStateMixin {
  String _sweetness = 'ปกติ (100%)';
  String _milk = 'นมวัว';
  
  late String _type;
  double _priceAdj = 5.0; 
  
  // --- 🔥 ตัวแปรเก็บประเภทที่ขายได้จริง ---
  List<String> _availableTypes = [];

  late AnimationController _liquidController;
  late Animation<double> _liquidAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. ตั้งค่าเริ่มต้นจากข้อมูลที่ส่งมา (เผื่อไว้ก่อน)
    _availableTypes = widget.menu.availableTypes;
    
    // ถ้าค่าที่ส่งมาเป็นค่า Default (ครบ 3 อย่าง) หรือว่างเปล่า ให้ลองเช็คตามหมวดหมู่
    if (_availableTypes.isEmpty) {
      if (widget.menu.category == 'ผลไม้') _availableTypes = ['ปั่น'];
      else _availableTypes = ['ร้อน', 'เย็น', 'ปั่น'];
    }

    // 2. เลือกค่าเริ่มต้น
    _autoSelectType();

    _liquidController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _liquidAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOut),
    );
    
    // --- 🔥 3. ดึงข้อมูลล่าสุดจาก Database ทันที (แก้ปัญหาข้อมูลไม่อัปเดต) ---
    _fetchRealTimeMenuData();
  }

  // ฟังก์ชันดึงข้อมูลสดๆ
  Future<void> _fetchRealTimeMenuData() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('menu_items').doc(widget.menu.id).get();
      if (doc.exists && mounted) {
        var data = doc.data()!;
        if (data['availableTypes'] != null) {
          List<String> realTypes = List<String>.from(data['availableTypes']);
          
          if (realTypes.isNotEmpty) {
            setState(() {
              _availableTypes = realTypes;
              // ถ้าประเภทที่เลือกอยู่เดิม ไม่มีในรายการใหม่ ให้เปลี่ยน
              if (!_availableTypes.contains(_type)) {
                 _autoSelectType();
              }
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching menu details: $e");
    }
  }

  // ฟังก์ชันเลือกค่าเริ่มต้นอัตโนมัติ
  void _autoSelectType() {
    if (_availableTypes.contains('เย็น')) {
      _type = 'เย็น';
    } else if (_availableTypes.isNotEmpty) {
      // ถ้าไม่มีเย็น ให้เลือกอันแรกที่มี
      _type = _availableTypes.first;
    } else {
      _type = 'เย็น'; // Fallback สุดท้าย
    }
    _updatePriceAdj(_type);
  }

  void _updatePriceAdj(String type) {
    // --- 🔥 แก้ไข: ถ้าเป็นหมวดผลไม้ ไม่ต้องบวกราคาเพิ่ม (ราคาตามป้าย) ---
    if (widget.menu.category == 'ผลไม้') {
      _priceAdj = 0.0;
      return;
    }

    if (type == 'ร้อน') _priceAdj = -5.0;
    else if (type == 'ปั่น') _priceAdj = 10.0;
    else _priceAdj = 0.0; 
    
    if (type == 'เย็น') _priceAdj = 5.0; 
  }

  @override
  void dispose() {
    _liquidController.dispose();
    super.dispose();
  }

  Color _getDrinkColor() {
    Color baseColor;
    if (widget.menu.category == 'ผลไม้') {
      baseColor = Colors.orangeAccent; 
    } else if (widget.menu.category == 'ชา') {
      baseColor = const Color(0xFFB77B5E); 
    } else if (widget.menu.category == 'นมสด') {
      baseColor = Colors.white; 
    } else {
      baseColor = const Color(0xFF3E2723); 
    }

    if (_milk == 'นมวัว' && widget.menu.category != 'นมสด') {
       if (widget.menu.category != 'ผลไม้') baseColor = Color.alphaBlend(Colors.white.withOpacity(0.4), baseColor);
    } else if (_milk == 'นมโอ๊ต (+10)') {
       baseColor = Color.alphaBlend(const Color(0xFFD7CCC8).withOpacity(0.5), baseColor);
    } else if (_milk == 'นมถั่วเหลือง') {
       baseColor = Color.alphaBlend(const Color(0xFFFFECB3).withOpacity(0.5), baseColor);
    }
    
    if (_sweetness == '0%') return baseColor.withOpacity(0.9);
    if (_sweetness == '125%') return baseColor.withOpacity(0.7);

    return baseColor;
  }

  int _getSugarCount() {
    if (_sweetness == '0%') return 0;
    if (_sweetness == '25%') return 1;
    if (_sweetness == '50%') return 2;
    if (_sweetness == 'ปกติ (100%)') return 3;
    if (_sweetness == '125%') return 4;
    return 3;
  }

  void _selectType(String type) {
    setState(() {
      _type = type;
      _updatePriceAdj(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    double finalPrice = widget.menu.price + _priceAdj;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: double.infinity,
        height: 680, 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // 1. Visualizer
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF3E0), Colors.white],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    child: Column(
                      children: [
                        Text(widget.menu.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                        Text("$_type ฿${finalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, color: Colors.brown, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    child: SizedBox(
                      width: 180,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          AnimatedBuilder(
                            animation: _liquidAnimation,
                            builder: (context, child) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: 140 + _liquidAnimation.value, 
                                height: _type == 'ร้อน' ? 150 : 220, 
                                decoration: BoxDecoration(
                                  color: _getDrinkColor(), 
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                                ),
                              );
                            },
                          ),
                          Positioned(bottom: 50, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_getSugarCount(), (index) => Padding(padding: const EdgeInsets.all(2.0), child: Icon(Icons.crop_square, size: 20, color: Colors.white.withOpacity(0.8)))))),
                          Container(
                            width: 150, height: _type == 'ร้อน' ? 160 : 230, 
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400, width: 3), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)), color: Colors.transparent),
                          ),
                          if (_type != 'ร้อน')
                            Positioned(top: -20, right: 40, child: Transform.rotate(angle: 0.2, child: Container(width: 10, height: 100, color: Colors.orange))),
                          
                          if (_type == 'ร้อน')
                             const Positioned(top: 20, child: Icon(Icons.air, color: Colors.white54, size: 40)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Controls
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 🔥 แสดงเฉพาะปุ่มที่มีใน _availableTypes (ที่ดึงมาจาก DB ล่าสุด) ---
                    const Text("เลือกประเภท (Type)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_availableTypes.contains('ร้อน')) _buildTypeChip("ร้อน (-5฿)", "ร้อน"),
                        if (_availableTypes.contains('เย็น')) _buildTypeChip("เย็น (+5฿)", "เย็น"),
                        if (_availableTypes.contains('ปั่น')) 
                          // 🔥 ถ้าเป็นผลไม้ ปั่นไม่บวกเพิ่ม
                          _buildTypeChip(widget.menu.category == 'ผลไม้' ? "ปั่น" : "ปั่น (+10฿)", "ปั่น"),
                      ],
                    ),
                    const SizedBox(height: 15),

                    const Text("ระดับความหวาน (Sweetness)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal, 
                      child: Row(
                        children: ['0%', '25%', '50%', 'ปกติ', '125%'].map((val) {
                          bool isSelected = (val == 'ปกติ' && _sweetness == 'ปกติ (100%)') || (_sweetness == val);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0), 
                            child: ChoiceChip(
                              label: Text(val), 
                              selected: isSelected, 
                              selectedColor: const Color(0xFFA6C48A), 
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black), 
                              onSelected: (sel) => setState(() => _sweetness = val == 'ปกติ' ? 'ปกติ (100%)' : val)
                            )
                          );
                        }).toList()
                      )
                    ),
                    
                    const SizedBox(height: 15),
                    const Text("ประเภทนม (Milk)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['นมวัว', 'นมโอ๊ต (+10)', 'นมถั่วเหลือง'].map((val) => Padding(padding: const EdgeInsets.only(right: 8.0), child: ChoiceChip(label: Text(val), selected: _milk == val, selectedColor: const Color(0xFF6F4E37), labelStyle: TextStyle(color: _milk == val ? Colors.white : Colors.black), onSelected: (sel) => setState(() => _milk = val)))).toList())),
                    
                    const Spacer(),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { widget.onConfirm(_sweetness, _milk, _type, _priceAdj); Navigator.pop(context); }, child: Text("เพิ่ม ฿${finalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    bool isSelected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: value == 'ร้อน' ? Colors.red[100] : (value == 'เย็น' ? Colors.blue[100] : Colors.purple[100]),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.grey[700], 
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      onSelected: (selected) {
        if (selected) _selectType(value);
      },
    );
  }
}