import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 เพิ่ม Import Auth
import 'stock_history_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _selectedFilter = "ทั้งหมด";

  // --- 🔥 ฟังก์ชันดึงชื่อคนล็อกอิน ---
  Future<String> _getRecorderName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['name'] ?? 'พนักงาน';
        }
      } catch (e) {
        print("Error getting user name: $e");
      }
    }
    return 'Admin'; 
  }

  // --- 🔥 อัปเดตฟังก์ชันบันทึก Log ให้ใส่ชื่อคนทำ ---
  Future<void> _logStockChange(String name, double change, double finalStock, String reason) async {
    String recorder = await _getRecorderName(); // ดึงชื่อ
    await FirebaseFirestore.instance.collection('stock_logs').add({
      'ingredientName': name,
      'changeAmount': change,
      'remainingStock': finalStock,
      'reason': reason,
      'recorder': recorder, // ✅ บันทึกชื่อลง Database
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ฟังก์ชันจัดการวัตถุดิบ (เพิ่ม/แก้ไข)
  void _showManageIngredientDialog(BuildContext context, {String? id, Map<String, dynamic>? data}) {
    final isEditing = id != null;
    
    final nameCtrl = TextEditingController(text: isEditing ? data!['name'] : '');
    final stockCtrl = TextEditingController(text: isEditing ? data!['currentStock'].toString() : '');
    final unitCtrl = TextEditingController(text: isEditing ? data!['unit'] : '');
    final customCatCtrl = TextEditingController(); 

    // ตัวแปรต้นทุน
    final costCtrl = TextEditingController(text: isEditing && data!['purchasePrice'] != null ? data['purchasePrice'].toString() : '');
    final packSizeCtrl = TextEditingController(text: isEditing && data!['packSize'] != null ? data['packSize'].toString() : '');

    List<String> baseCategories = ["ผง", "น้ำตาล", "นม", "ไซรัป", "เมล็ดกาแฟ", "แก้ว/ฝา", "อื่นๆ"];
    
    String selectedCat = isEditing ? (data!['category'] ?? 'อื่นๆ') : 'ผง';
    bool isCustomCat = false;
    
    if (!baseCategories.contains(selectedCat) && selectedCat != "ทั้งหมด") {
      isCustomCat = true;
      customCatCtrl.text = selectedCat;
      selectedCat = "กำหนดเอง";
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          double price = double.tryParse(costCtrl.text) ?? 0;
          double size = double.tryParse(packSizeCtrl.text) ?? 0;
          double costPerUnit = (size > 0) ? price / size : 0;

          return AlertDialog(
            title: Text(isEditing ? "แก้ไขวัตถุดิบ" : "เพิ่มวัตถุดิบใหม่"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ชื่อวัตถุดิบ", prefixIcon: Icon(Icons.label), hintText: "เช่น ผงชาไทย")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCat,
                    decoration: const InputDecoration(labelText: "หมวดหมู่", prefixIcon: Icon(Icons.category)),
                    items: [...baseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))), const DropdownMenuItem(value: "กำหนดเอง", child: Text("+ เพิ่มหมวดเอง..."))], 
                    onChanged: (val) { setState(() { selectedCat = val!; isCustomCat = (val == "กำหนดเอง"); }); }
                  ),
                  if (isCustomCat) Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: customCatCtrl, decoration: const InputDecoration(labelText: "ชื่อหมวดหมู่ใหม่"))),
                  const SizedBox(height: 10),
                  Row(children: [Expanded(flex: 2, child: TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: "คงเหลือ"), keyboardType: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 10), Expanded(flex: 1, child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "หน่วย")))]),
                  const SizedBox(height: 15),
                  const Divider(),
                  const Text("ตั้งค่าต้นทุน", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Row(children: [Expanded(child: TextField(controller: costCtrl, decoration: const InputDecoration(labelText: "ราคาซื้อ"), keyboardType: TextInputType.number, onChanged: (v)=>setState((){}))), const SizedBox(width: 10), Expanded(child: TextField(controller: packSizeCtrl, decoration: const InputDecoration(labelText: "ปริมาณต่อแพ็ค"), keyboardType: TextInputType.number, onChanged: (v)=>setState((){})))]),
                  if (price > 0 && size > 0) Text("ตกเฉลี่ย: ${costPerUnit.toStringAsFixed(3)} /หน่วย", style: const TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              if (isEditing) TextButton(onPressed: () { FirebaseFirestore.instance.collection('ingredients').doc(id).delete(); Navigator.pop(ctx); }, child: const Text("ลบ", style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    String finalCategory = isCustomCat ? customCatCtrl.text.trim() : selectedCat;
                    if (finalCategory.isEmpty) finalCategory = "อื่นๆ";
                    double newStock = double.tryParse(stockCtrl.text) ?? 0;
                    double oldStock = isEditing ? (data!['currentStock'] ?? 0).toDouble() : 0;
                    double pPrice = double.tryParse(costCtrl.text) ?? 0;
                    double pSize = double.tryParse(packSizeCtrl.text) ?? 0;
                    double costPerUnit = (pSize > 0) ? pPrice / pSize : 0;

                    final Map<String, dynamic> ingredientData = {
                      'name': nameCtrl.text.trim(),
                      'category': finalCategory,
                      'currentStock': newStock,
                      'unit': unitCtrl.text.trim(),
                      'minThreshold': 200,
                      'purchasePrice': pPrice,
                      'packSize': pSize,
                      'costPerUnit': costPerUnit,
                    };

                    if (isEditing) {
                      await FirebaseFirestore.instance.collection('ingredients').doc(id).update(ingredientData);
                      if (newStock != oldStock) _logStockChange(nameCtrl.text, newStock - oldStock, newStock, "แก้ไขสต๊อก");
                    } else {
                      await FirebaseFirestore.instance.collection('ingredients').add(ingredientData);
                      _logStockChange(nameCtrl.text, newStock, newStock, "เพิ่มสินค้าใหม่");
                    }
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: Text(isEditing ? "บันทึก" : "เพิ่ม"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _updateStock(String id, String name, double current, double change) {
    double newStock = current + change;
    FirebaseFirestore.instance.collection('ingredients').doc(id).update({
      'currentStock': newStock,
    });
    _logStockChange(name, change, newStock, "ปรับด่วน (Quick Update)");
  }

  void _showQuickAddDialog(BuildContext context, String id, String name, double currentStock, String unit) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("ปรับสต๊อก: $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text("คงเหลือปัจจุบัน: $currentStock $unit", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
             const SizedBox(height: 15),
             TextField(
               controller: amountCtrl,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               autofocus: true,
               decoration: const InputDecoration(
                 labelText: "จำนวนที่ต้องการเพิ่ม (+)",
                 hintText: "เช่น 100",
                 helperText: "ใส่เครื่องหมายลบ (-) หากต้องการลด เช่น -50",
               ),
             ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(onPressed: () { double val = double.tryParse(amountCtrl.text) ?? 0; if (val != 0) { _updateStock(id, name, currentStock, val); Navigator.pop(ctx); } }, child: const Text("ยืนยัน"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("จัดการวัตถุดิบ (Stock)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StockHistoryScreen())),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ingredients').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          // 1. สกัดหมวดหมู่
          Set<String> categorySet = {"ทั้งหมด"}; 
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['category'] != null && data['category'].toString().isNotEmpty) {
              categorySet.add(data['category']);
            }
          }
          List<String> dynamicCategories = categorySet.toList();

          // 2. กรองข้อมูล
          var filteredDocs = docs;
          if (_selectedFilter != "ทั้งหมด") {
            filteredDocs = docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return (data['category'] ?? 'อื่นๆ') == _selectedFilter;
            }).toList();
          }

          return Column(
            children: [
              // Filter Bar
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    String cat = dynamicCategories[index];
                    bool isSelected = _selectedFilter == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFA6C48A) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Stock List
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox, size: 60, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text("ไม่มีวัตถุดิบในหมวด '$_selectedFilter'", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var data = filteredDocs[index].data() as Map<String, dynamic>;
                          String id = filteredDocs[index].id;
                          String name = data['name'] ?? '-';
                          String category = data['category'] ?? 'อื่นๆ';
                          double stock = (data['currentStock'] ?? 0).toDouble();
                          String unit = data['unit'] ?? '';
                          double min = (data['minThreshold'] ?? 0).toDouble();
                          bool isLow = stock <= min;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              // กดเพื่อแก้ไขข้อมูลหลัก
                              onTap: () => _showManageIngredientDialog(context, id: id, data: data),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isLow ? Colors.red[50] : Colors.green[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isLow ? Icons.warning_amber : Icons.inventory_2, 
                                        color: isLow ? Colors.red : Colors.green
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Wrap(
  spacing: 0,
  runSpacing: 4,
  crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                                child: Text(category, style: TextStyle(fontSize: 10, color: Colors.grey[800])),
                                              ),
                                              const SizedBox(width: 8),
                                              Text("$stock $unit", style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? Colors.red : Colors.black87)),
                                              if (isLow) const Padding(padding: EdgeInsets.only(left: 5), child: Text("(ใกล้หมด!)", style: TextStyle(color: Colors.red, fontSize: 12))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // --- 🔥 ปุ่มจัดการสต๊อก (+/- และ กรอกเอง) ---
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _updateStock(id, name, stock, -1)),
                                        // 🔥 ปุ่มกรอกจำนวน (Quick Add)
                                        IconButton(
                                          icon: const Icon(Icons.edit_square, color: Colors.blue),
                                          tooltip: "กรอกจำนวน",
                                          onPressed: () => _showQuickAddDialog(context, id, name, stock, unit),
                                        ),
                                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => _updateStock(id, name, stock, 1)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFA6C48A),
        foregroundColor: Colors.white,
        onPressed: () => _showManageIngredientDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มวัตถุดิบ"),
      ),
    );
  }
}