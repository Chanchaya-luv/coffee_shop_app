import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  
  // --- 🔥 ตัวแปรเก็บชื่อผู้ใช้ปัจจุบัน ---
  String _currentUserName = "กำลังโหลด...";

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _loadCurrentUser(); // ดึงชื่อทันทีที่เปิดหน้านี้
  }

  // --- 🔥 ฟังก์ชันดึงชื่อผู้ใช้ ---
  Future<void> _loadCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          if (mounted) {
            setState(() {
              _currentUserName = doc.data()?['name'] ?? 'พนักงาน';
            });
          }
        } else {
          // ถ้าไม่มีเอกสารใน database ให้ใช้ชื่อจาก Auth หรือ Admin
          if (mounted) {
            setState(() {
              _currentUserName = user.displayName ?? 'Admin';
            });
          }
        }
      } catch (e) {
        print("Error fetching user: $e");
        if (mounted) setState(() => _currentUserName = "Admin");
      }
    } else {
      if (mounted) setState(() => _currentUserName = "Unknown");
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6F4E37)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addExpense() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("บันทึกรายจ่ายใหม่"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 🔥 แสดงชื่อผู้บันทึกให้เห็นชัดๆ ---
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text("ผู้บันทึก: $_currentUserName", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "รายการ (เช่น ซื้อน้ำแข็ง)")),
            TextField(controller: _amountCtrl, decoration: const InputDecoration(labelText: "จำนวนเงิน (บาท)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
            onPressed: () async {
              if (_titleCtrl.text.isNotEmpty && _amountCtrl.text.isNotEmpty) {
                // บันทึกชื่อ _currentUserName ลงไปด้วย
                await FirebaseFirestore.instance.collection('expenses').add({
                  'title': _titleCtrl.text.trim(),
                  'amount': double.parse(_amountCtrl.text.trim()),
                  'date': FieldValue.serverTimestamp(),
                  'recorder': _currentUserName, // ✅ ใช้ชื่อที่ดึงมาได้
                });
                _titleCtrl.clear();
                _amountCtrl.clear();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("บันทึก"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    String dateLabel = DateFormat('d MMMM yyyy', 'th').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("บันทึกรายจ่าย", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ส่วนเลือกวันที่
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ดูรายจ่ายวันที่:", style: TextStyle(color: Colors.grey)),
                    Text(dateLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6F4E37))),
                  ],
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, color: Color(0xFF6F4E37), size: 28),
                )
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('expenses').orderBy('date', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                // กรองข้อมูลเฉพาะวันที่เลือก
                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['date'] == null) return false;
                  DateTime ts = (data['date'] as Timestamp).toDate();
                  return ts.isAfter(startOfDay) && ts.isBefore(endOfDay);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("ไม่มีรายจ่ายในวันที่ $dateLabel", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                double totalAmount = docs.fold(0, (sum, doc) => sum + (doc['amount'] ?? 0));

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String title = data['title'] ?? '';
                          double amount = (data['amount'] ?? 0).toDouble();
                          Timestamp? ts = data['date'];
                          String timeStr = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '-';
                          // ดึงชื่อมาแสดง
                          String recorderName = data['recorder'] ?? 'Admin'; 

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[50],
                                child: const Icon(Icons.remove, color: Colors.red),
                              ),
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Row(
                                children: [
                                  Text("เวลา: $timeStr"),
                                  const SizedBox(width: 10),
                                  // --- 🔥 แสดงชื่อคนบันทึกตรงนี้ ---
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: Text(recorderName, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  )
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("-฿${amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("ลบรายการ"),
                                          content: const Text("ต้องการลบรายการนี้ใช่หรือไม่?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
                                            TextButton(onPressed: () {
                                              FirebaseFirestore.instance.collection('expenses').doc(docs[index].id).delete();
                                              Navigator.pop(ctx);
                                            }, child: const Text("ลบ", style: TextStyle(color: Colors.red))),
                                          ],
                                        )
                                      );
                                    },
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // สรุปยอดรวมด้านล่าง
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("รวมรายจ่ายวันนี้", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("฿${NumberFormat('#,##0.00').format(totalAmount)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text("เพิ่มรายจ่าย"),
      ),
    );
  }
}