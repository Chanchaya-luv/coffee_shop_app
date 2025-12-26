import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GPCalculatorScreen extends StatefulWidget {
  const GPCalculatorScreen({super.key});

  @override
  State<GPCalculatorScreen> createState() => _GPCalculatorScreenState();
}

class _GPCalculatorScreenState extends State<GPCalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: "1"); 

  // ตัวแปรเก็บรายการต้นทุนย่อย
  List<Map<String, dynamic>> _costItems = [];
  
  double _totalCost = 0.0;
  double? _grossProfit;
  double? _profitMargin;
  bool _isCalculated = false;
  String? _editingId; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _recalculateTotalCost() {
    double sum = 0.0;
    for (var item in _costItems) {
      sum += (item['cost'] as double);
    }
    setState(() {
      _totalCost = sum;
      if (_isCalculated) _calculateGP();
    });
  }

  // --- 🔥 ฟังก์ชันเพิ่มวัตถุดิบ (แบบมีหมวดหมู่) ---
  void _addIngredientCost() {
    // ตัวแปรเก็บหมวดหมู่ที่เลือกใน Dialog (เริ่มต้น "ทั้งหมด")
    String selectedCategory = "ทั้งหมด";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("เลือกวัตถุดิบ / บรรจุภัณฑ์"),
            content: SizedBox(
              width: double.maxFinite,
              height: 450, // เพิ่มความสูงให้พอดีกับ List และ Filter
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('ingredients').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;

                  // 1. สกัดหมวดหมู่ที่มีอยู่จริงใน DB
                  Set<String> categorySet = {"ทั้งหมด"};
                  for (var doc in docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['category'] != null && data['category'].toString().isNotEmpty) {
                      categorySet.add(data['category']);
                    }
                  }
                  List<String> dynamicCategories = categorySet.toList();
                  // เรียงลำดับ (เอา "ทั้งหมด" ไว้หน้าสุด)
                  dynamicCategories.sort((a, b) {
                    if (a == "ทั้งหมด") return -1;
                    if (b == "ทั้งหมด") return 1;
                    return a.compareTo(b);
                  });

                  // 2. กรองข้อมูลตามหมวดที่เลือก
                  var filteredDocs = docs;
                  if (selectedCategory != "ทั้งหมด") {
                    filteredDocs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return (data['category'] ?? 'อื่นๆ') == selectedCategory;
                    }).toList();
                  }
                  
                  return Column(
                    children: [
                      // --- แถบเลือกหมวดหมู่ ---
                      Container(
                        height: 50,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: dynamicCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            String cat = dynamicCategories[index];
                            bool isSelected = selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                if (selected) {
                                  setState(() {
                                    selectedCategory = cat;
                                  });
                                }
                              },
                              selectedColor: const Color(0xFFA6C48A),
                              backgroundColor: Colors.grey[200],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                              ),
                              showCheckmark: false,
                            );
                          },
                        ),
                      ),

                      // --- รายการวัตถุดิบ ---
                      Expanded(
                        child: filteredDocs.isEmpty 
                        ? Center(child: Text("ไม่มีรายการในหมวด '$selectedCategory'", style: const TextStyle(color: Colors.grey)))
                        : ListView.separated(
                          separatorBuilder: (_,__) => const Divider(height: 1),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            var data = filteredDocs[index].data() as Map<String, dynamic>;
                            String name = data['name'] ?? '-';
                            String unit = data['unit'] ?? '';
                            double costPerUnit = (data['costPerUnit'] ?? 0).toDouble();
                            
                            // กรณีไม่มี costPerUnit ให้ลองคำนวณจากราคาซื้อ/แพ็ค
                            if (costPerUnit == 0) {
                               double pPrice = (data['purchasePrice'] ?? 0).toDouble();
                               double pSize = (data['packSize'] ?? 0).toDouble();
                               if (pSize > 0) costPerUnit = pPrice / pSize;
                            }

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("ต้นทุน: ฿${costPerUnit.toStringAsFixed(4)} / $unit"),
                              trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF6F4E37)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showQuantityDialog(name, costPerUnit, unit);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ],
          );
        }
      ),
    );
  }

  // Dialog กรอกปริมาณที่ใช้ (รองรับการแก้ไข)
  void _showQuantityDialog(String name, double costPerUnit, String unit, {int? index, double? initialQty}) {
    final qtyInput = TextEditingController(text: initialQty?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? "ระบุปริมาณที่ใช้ ($name)" : "แก้ไขปริมาณ ($name)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
               controller: qtyInput,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               autofocus: true,
               decoration: InputDecoration(
                 labelText: "ปริมาณ ($unit)", 
                 hintText: "เช่น 20, 1",
                 border: const OutlineInputBorder()
               ),
             ),
             const SizedBox(height: 10),
             Text("ต้นทุนต่อหน่วย: ฿${costPerUnit.toStringAsFixed(4)}", style: const TextStyle(color: Colors.grey))
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () {
               double usedQty = double.tryParse(qtyInput.text) ?? 0;
               if (usedQty > 0) {
                 double calculatedCost = costPerUnit * usedQty;
                 
                 setState(() {
                   final newItem = {
                     'name': name,
                     'qty': usedQty,
                     'unit': unit,
                     'cost': calculatedCost
                   };
                   
                   if (index != null) {
                     _costItems[index] = newItem;
                   } else {
                     _costItems.add(newItem);
                   }
                 });
                 _recalculateTotalCost();
                 Navigator.pop(ctx);
               }
            }, 
            child: Text(index == null ? "เพิ่ม" : "บันทึก")
          )
        ],
      )
    );
  }

  // ดึงสูตรจากเมนูที่มีอยู่ (Auto Import)
  Future<void> _calculateCostFromMenu() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("เลือกเมนูเพื่อดึงสูตร"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('menu_items').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['name']),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _processMenuCost(data);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _processMenuCost(Map<String, dynamic> menuData) async {
    setState(() {
      _nameCtrl.text = menuData['name'];
      _priceCtrl.text = menuData['price'].toString();
      _costItems.clear(); 
    });

    List<dynamic> recipe = menuData['recipe'] ?? [];
    if (recipe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เมนูนี้ไม่มีสูตร")));
      return;
    }

    for (var item in recipe) {
      String ingId = item['ingredientId'];
      double qtyUsed = (item['quantityUsed'] ?? 0).toDouble();

      var ingDoc = await FirebaseFirestore.instance.collection('ingredients').doc(ingId).get();
      if (ingDoc.exists) {
        var ingData = ingDoc.data() as Map<String, dynamic>;
        String name = ingData['name'] ?? '-';
        String unit = ingData['unit'] ?? '';
        double costPerUnit = (ingData['costPerUnit'] ?? 0).toDouble();
        
        if (costPerUnit == 0) {
           double pPrice = (ingData['purchasePrice'] ?? 0).toDouble();
           double pSize = (ingData['packSize'] ?? 0).toDouble();
           if (pSize > 0) costPerUnit = pPrice / pSize;
        }

        setState(() {
          _costItems.add({
            'name': name,
            'qty': qtyUsed,
            'unit': unit,
            'cost': costPerUnit * qtyUsed
          });
        });
      }
    }
    _recalculateTotalCost();
  }

  void _calculateGP() {
    if (_priceCtrl.text.isEmpty) return;
    double price = double.tryParse(_priceCtrl.text) ?? 0;
    double totalCost = _totalCost; 
    
    double profit = price - totalCost;
    double margin = (price > 0) ? (profit / price) * 100 : 0;

    setState(() {
      _grossProfit = profit;
      _profitMargin = margin;
      _isCalculated = true;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _saveResult() async {
     try {
      final data = {
        'name': _nameCtrl.text,
        'sellingPrice': double.parse(_priceCtrl.text),
        'totalCost': _totalCost,
        'grossProfit': _grossProfit,
        'profitMargin': _profitMargin,
        'timestamp': FieldValue.serverTimestamp(),
        'costDetails': _costItems, 
      };

      if (_editingId != null) {
        await FirebaseFirestore.instance.collection('gp_records').doc(_editingId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('gp_records').add(data);
      }
      
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกสำเร็จ!"), backgroundColor: Colors.green));
      _tabController.animateTo(1); 

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _editRecord(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingId = doc.id;
      _nameCtrl.text = data['name'] ?? '';
      _priceCtrl.text = (data['sellingPrice'] ?? 0).toString();
      _totalCost = (data['totalCost'] ?? 0).toDouble();
      
      if (data['costDetails'] != null) {
         _costItems = List<Map<String, dynamic>>.from(data['costDetails']);
      } else {
         _costItems = []; 
      }
      
      _grossProfit = (data['grossProfit'] ?? 0).toDouble();
      _profitMargin = (data['profitMargin'] ?? 0).toDouble();
      _isCalculated = true;
    });
    _tabController.animateTo(0);
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear(); _priceCtrl.clear(); _qtyCtrl.clear(); 
      _costItems.clear(); _totalCost = 0;
      _isCalculated = false; _grossProfit = null; _profitMargin = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("คำนวณต้นทุน & GP", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFA6C48A), indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: "เครื่องคิดเลข"), Tab(text: "รายการที่บันทึก")],
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Calculator
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_editingId != null)
                  Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.edit, size: 16, color: Colors.orange), const SizedBox(width: 5), Text("กำลังแก้ไข: ${_nameCtrl.text}", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)), const SizedBox(width: 10), InkWell(onTap: _clearForm, child: const Text("ยกเลิก", style: TextStyle(decoration: TextDecoration.underline)))])),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ส่วนหัว ---
                      _buildTextField("ชื่อเมนู (เช่น ชาไทยเย็น)", _nameCtrl),
                      const SizedBox(height: 10),
                      _buildTextField("ราคาขาย (บาท)", _priceCtrl, isNumber: true),
                      
                      const Divider(height: 30),
                      
                      // --- 🔥 ส่วนรายการต้นทุน (Cost Breakdown) ---
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "รายการต้นทุน (วัตถุดิบ/บรรจุภัณฑ์)",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addIngredientCost,
                            icon: Icon(Icons.add_circle, color: Color(0xFFA6C48A)),
                            label: Text("เพิ่มวัตถุดิบ", style: TextStyle(color: Color(0xFFA6C48A), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      
                      // ปุ่มดึงสูตร Auto
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _calculateCostFromMenu,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text("ดึงจากสูตรเมนูที่มีอยู่"),
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      // แสดงรายการ
                      if (_costItems.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ยังไม่มีรายการต้นทุน", style: TextStyle(color: Colors.grey))))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _costItems.length,
                          itemBuilder: (ctx, i) {
                            var item = _costItems[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(item['name']),
                              subtitle: Text("${item['qty']} ${item['unit']}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("฿${(item['cost'] as double).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  // --- 🔥 ปุ่มแก้ไข ---
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () {
                                       // คำนวณ costPerUnit กลับมาเพื่อส่งให้ Dialog
                                       double qty = (item['qty'] as num).toDouble();
                                       double cost = (item['cost'] as num).toDouble();
                                       double costPerUnit = (qty > 0) ? cost / qty : 0;
                                       
                                       _showQuantityDialog(item['name'], costPerUnit, item['unit'], index: i, initialQty: qty);
                                    },
                                  ),
                                  // --- 🔥 ปุ่มลบ ---
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _costItems.removeAt(i);
                                        _recalculateTotalCost();
                                      });
                                    },
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      
                      const Divider(),
                      
                      // ยอดรวมต้นทุน
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("รวมต้นทุนทั้งหมด", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("฿${_totalCost.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),

                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _calculateGP, child: const Text("คำนวณกำไร (GP)", style: TextStyle(fontSize: 18, color: Colors.white)))),
                    ],
                  ),
                ),

                if (_isCalculated) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA6C48A), width: 1)),
                    child: Column(
                      children: [
                        Text("กำไรขั้นต้น: ${_grossProfit?.toStringAsFixed(2)} บาท", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                        Text("อัตรากำไร (GP%): ${_profitMargin?.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 15),
                        SizedBox(width: double.infinity, height: 45, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _saveResult, child: Text(_editingId != null ? "บันทึกการแก้ไข" : "บันทึกผลลัพธ์", style: const TextStyle(color: Color(0xFF5D4037))))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tab 2: Saved Records
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gp_records').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
               if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
               if (snapshot.data!.docs.isEmpty) return const Center(child: Text("ไม่มีข้อมูล"));
               return ListView.builder(
                 padding: const EdgeInsets.all(16),
                 itemCount: snapshot.data!.docs.length,
                 itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      child: ListTile(
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("ต้นทุน: ${data['totalCost']} | กำไร: ${data['grossProfit']} (${data['profitMargin']}%)"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editRecord(doc)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('gp_records').doc(doc.id).delete()),
                          ],
                        ),
                      ),
                    );
                 },
               );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: ctrl, keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[50], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
  }
}