import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GPCalculatorScreen extends StatefulWidget {
  const GPCalculatorScreen({super.key});

  @override
  State<GPCalculatorScreen> createState() => _GPCalculatorScreenState();
}

class _GPCalculatorScreenState extends State<GPCalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController; // ใช้ TabController เพื่อสั่งเปลี่ยนหน้าได้

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  double? _grossProfit;
  double? _profitMargin;
  bool _isCalculated = false;
  String? _editingId; // ตัวแปรเก็บ ID เวลาแก้ไข

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
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันดึงต้นทุน (เหมือนเดิม) ---
  Future<void> _calculateCostFromMenu() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("เลือกเมนูเพื่อคำนวณต้นทุน"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('menu_items').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['name']),
                    subtitle: Text("${data['price']} บาท"),
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
    _nameCtrl.text = menuData['name'];
    _priceCtrl.text = menuData['price'].toString();
    _qtyCtrl.text = "1"; 

    double totalCost = 0.0;
    List<dynamic> recipe = menuData['recipe'] ?? [];

    if (recipe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เมนูนี้ยังไม่ได้ผูกสูตร (Recipe)")));
      return;
    }

    for (var item in recipe) {
      String ingId = item['ingredientId'];
      double qtyUsed = (item['quantityUsed'] ?? 0).toDouble();

      var ingDoc = await FirebaseFirestore.instance.collection('ingredients').doc(ingId).get();
      if (ingDoc.exists) {
        var ingData = ingDoc.data() as Map<String, dynamic>;
        double costPerUnit = (ingData['costPerUnit'] ?? 0).toDouble();
        
        if (costPerUnit == 0) {
           double pPrice = (ingData['purchasePrice'] ?? 0).toDouble();
           double pSize = (ingData['packSize'] ?? 0).toDouble();
           if (pSize > 0) costPerUnit = pPrice / pSize;
        }
        totalCost += (costPerUnit * qtyUsed);
      }
    }

    setState(() {
      _costCtrl.text = totalCost.toStringAsFixed(2);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ดึงต้นทุนเรียบร้อย: ฿${totalCost.toStringAsFixed(2)}")));
  }

  void _calculateGP() {
    if (_priceCtrl.text.isEmpty || _costCtrl.text.isEmpty) return;
    double price = double.tryParse(_priceCtrl.text) ?? 0;
    double totalCost = double.tryParse(_costCtrl.text) ?? 0;
    double qty = double.tryParse(_qtyCtrl.text) ?? 1;
    if (qty == 0) qty = 1;

    double costPerCup = totalCost / qty;
    double profit = price - costPerCup;
    double margin = (price > 0) ? (profit / price) * 100 : 0;

    setState(() {
      _grossProfit = profit;
      _profitMargin = margin;
      _isCalculated = true;
    });
    FocusScope.of(context).unfocus();
  }

  // --- 🔥 ฟังก์ชันบันทึก (รองรับการแก้ไข) ---
  Future<void> _saveResult() async {
     try {
      final data = {
        'name': _nameCtrl.text,
        'sellingPrice': double.parse(_priceCtrl.text),
        'totalCost': double.parse(_costCtrl.text),
        'quantity': double.parse(_qtyCtrl.text.isEmpty ? "1" : _qtyCtrl.text),
        'grossProfit': _grossProfit,
        'profitMargin': _profitMargin,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_editingId != null) {
        // กรณีแก้ไข: อัปเดตเอกสารเดิม
        await FirebaseFirestore.instance.collection('gp_records').doc(_editingId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("แก้ไขข้อมูลเรียบร้อย!"), backgroundColor: Colors.green));
      } else {
        // กรณีเพิ่มใหม่
        await FirebaseFirestore.instance.collection('gp_records').add(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกเมนูสำเร็จ!"), backgroundColor: Colors.green));
      }
      
      _clearForm();
      // ย้ายไปดูรายการที่บันทึก
      _tabController.animateTo(1); 

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- 🔥 ฟังก์ชันโหลดข้อมูลมาแก้ไข ---
  void _editRecord(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingId = doc.id; // จำ ID ไว้
      _nameCtrl.text = data['name'] ?? '';
      _priceCtrl.text = (data['sellingPrice'] ?? 0).toString();
      _costCtrl.text = (data['totalCost'] ?? 0).toString();
      _qtyCtrl.text = (data['quantity'] ?? 1).toString();
      
      // คำนวณค่าเดิมโชว์ไว้ก่อน
      _grossProfit = (data['grossProfit'] ?? 0).toDouble();
      _profitMargin = (data['profitMargin'] ?? 0).toDouble();
      _isCalculated = true;
    });
    
    // สลับไปหน้าเครื่องคิดเลข
    _tabController.animateTo(0);
  }

  void _clearForm() {
    setState(() {
      _editingId = null; // ล้างสถานะแก้ไข
      _nameCtrl.clear(); _priceCtrl.clear(); _costCtrl.clear(); _qtyCtrl.clear(); 
      _isCalculated = false; _grossProfit = null; _profitMargin = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("คำนวณ GP"),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFA6C48A), indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: "เครื่องคิดเลข"), Tab(text: "เมนูที่บันทึกไว้")],
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, size: 16, color: Colors.orange),
                        const SizedBox(width: 5),
                        Text("กำลังแก้ไขเมนู: ${_nameCtrl.text}", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        InkWell(onTap: _clearForm, child: const Text("ยกเลิก", style: TextStyle(decoration: TextDecoration.underline)))
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _calculateCostFromMenu,
                          icon: const Icon(Icons.download, color: Color(0xFF6F4E37)),
                          label: const Text("ดึงต้นทุนจากเมนูที่มีอยู่ (Auto)", style: TextStyle(color: Color(0xFF6F4E37), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6F4E37)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      _buildTextField("ชื่อเมนู", _nameCtrl),
                      _buildTextField("ราคาขายต่อแก้ว (บาท)", _priceCtrl, isNumber: true),
                      _buildTextField("ต้นทุนวัตถุดิบรวม (บาท)", _costCtrl, isNumber: true),
                      _buildTextField("จำนวนแก้ว (Default: 1)", _qtyCtrl, isNumber: true),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _calculateGP, child: const Text("คำนวณ GP", style: TextStyle(fontSize: 18, color: Colors.white)))),
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
                        const Icon(Icons.check_circle, color: Color(0xFFA6C48A), size: 50),
                        const SizedBox(height: 10),
                        Text("กำไรขั้นต้น: ${_grossProfit?.toStringAsFixed(2)} บาท", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                        Text("อัตรากำไร (Margin): ${_profitMargin?.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 15),
                        SizedBox(width: double.infinity, height: 45, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _saveResult, child: Text(_editingId != null ? "บันทึกการแก้ไข" : "บันทึกเมนู", style: const TextStyle(color: Color(0xFF5D4037))))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tab 2: Saved Menus
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
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("กำไร: ${data['grossProfit']} (${data['profitMargin']}%)"),
                        // --- 🔥 ปุ่มแก้ไขและลบ ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editRecord(doc), // เรียกฟังก์ชันแก้ไข
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => FirebaseFirestore.instance.collection('gp_records').doc(doc.id).delete(),
                            ),
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
    return Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: ctrl, keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
  }
}