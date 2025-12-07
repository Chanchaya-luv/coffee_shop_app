import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GPCalculatorScreen extends StatefulWidget {
  const GPCalculatorScreen({super.key});

  @override
  State<GPCalculatorScreen> createState() => _GPCalculatorScreenState();
}

class _GPCalculatorScreenState extends State<GPCalculatorScreen> {
  // Controller สำหรับรับค่าจากฟอร์ม
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  // ตัวแปรเก็บผลลัพธ์
  double? _grossProfit;
  double? _profitMargin;
  bool _isCalculated = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ฟังก์ชันคำนวณ GP
  void _calculateGP() {
    // ป้องกันการกดคำนวณโดยไม่กรอกตัวเลข
    if (_priceCtrl.text.isEmpty || _costCtrl.text.isEmpty) return;

    double price = double.tryParse(_priceCtrl.text) ?? 0;
    double totalCost = double.tryParse(_costCtrl.text) ?? 0;
    double qty = double.tryParse(_qtyCtrl.text) ?? 1; // ถ้าไม่กรอก ให้หาร 1 (ต่อแก้ว)

    if (qty == 0) qty = 1; // กัน error หารด้วย 0

    double costPerCup = totalCost / qty;
    double profit = price - costPerCup;
    double margin = (price > 0) ? (profit / price) * 100 : 0;

    setState(() {
      _grossProfit = profit;
      _profitMargin = margin;
      _isCalculated = true;
    });

    // ซ่อนคีย์บอร์ดหลังคำนวณเสร็จ
    FocusScope.of(context).unfocus();
  }

  // ฟังก์ชันบันทึกลง Firebase
  Future<void> _saveResult() async {
    if (!_isCalculated || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกชื่อเมนูก่อนบันทึก")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('gp_records').add({
        'name': _nameCtrl.text,
        'sellingPrice': double.parse(_priceCtrl.text),
        'totalCost': double.parse(_costCtrl.text),
        'quantity': double.parse(_qtyCtrl.text.isEmpty ? "1" : _qtyCtrl.text),
        'grossProfit': _grossProfit,
        'profitMargin': _profitMargin,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("บันทึกเมนูสำเร็จ!"), backgroundColor: Colors.green),
      );
      
      _clearForm(); // ล้างฟอร์มเตรียมกรอกใหม่

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _clearForm() {
    setState(() {
      _nameCtrl.clear();
      _priceCtrl.clear();
      _costCtrl.clear();
      _qtyCtrl.clear();
      _isCalculated = false;
      _grossProfit = null;
      _profitMargin = null;
    });
  }

  // --- UI ส่วน Input Form (TextField) ---
  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("คำนวณ GP"),
          backgroundColor: const Color(0xFF6F4E37),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Color(0xFFA6C48A),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: "เครื่องคิดเลข"),
              Tab(text: "เมนูที่บันทึกไว้"),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF9F9F9),
        body: TabBarView(
          children: [
            // --- Tab 1: หน้าคำนวณ ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        _buildTextField("ชื่อเมนู (เช่น ลาเต้เย็น)", _nameCtrl),
                        _buildTextField("ราคาขายต่อแก้ว (บาท)", _priceCtrl, isNumber: true),
                        _buildTextField("ต้นทุนวัตถุดิบรวม (บาท)", _costCtrl, isNumber: true),
                        _buildTextField("จำนวนแก้วที่ขายได้ (ถ้ามี)", _qtyCtrl, isNumber: true),

                        const SizedBox(height: 10),

                        // ปุ่มคำนวณ
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA6C48A), // สีเขียว
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _calculateGP,
                            child: const Text("คำนวณ GP", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // แสดงผลลัพธ์ (โชว์เมื่อกดคำนวณแล้ว)
                  if (_isCalculated) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA6C48A), width: 1), // ขอบเขียว
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFFA6C48A), size: 50),
                          const SizedBox(height: 10),
                          Text("กำไรขั้นต้น: ${_grossProfit?.toStringAsFixed(2)} บาท", 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                          Text("อัตรากำไร (Margin): ${_profitMargin?.toStringAsFixed(1)}%", 
                              style: const TextStyle(fontSize: 16, color: Colors.grey)),
                          
                          const SizedBox(height: 15),
                          
                          // ปุ่มบันทึก
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _saveResult,
                              child: const Text("บันทึกเมนู", style: TextStyle(color: Color(0xFF5D4037))),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --- Tab 2: รายการที่บันทึกไว้ ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('gp_records').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                
                if (docs.isEmpty) return const Center(child: Text("ยังไม่มีเมนูที่บันทึกไว้"));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index];
                    double margin = (data['profitMargin'] as num).toDouble();
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(data['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                      onPressed: () {
                                        // ลบรายการ
                                        FirebaseFirestore.instance.collection('gp_records').doc(data.id).delete();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  ],
                                )
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("ราคาขาย: ${data['sellingPrice']} บาท"),
                                    Text("ต้นทุนรวม: ${data['totalCost']} บาท"),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("กำไร (GP)", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                                    Text("${margin.toStringAsFixed(1)}%", style: TextStyle(color: Colors.green[700], fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              ],
                            )
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
      ),
    );
  }
}