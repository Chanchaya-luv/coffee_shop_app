import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_screen.dart'; 

class ScanTableScreen extends StatelessWidget {
  const ScanTableScreen({super.key});

  // ฟังก์ชันเลือกโต๊ะ (มีการเช็คสถานะ)
  void _selectTable(BuildContext context, String tableNo, bool isOccupied) {
    if (isOccupied) {
      // ถ้าไม่ว่าง ให้แจ้งเตือนและห้ามไปต่อ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⛔️ โต๊ะ $tableNo มีลูกค้าใช้งานอยู่ กรุณาติดต่อพนักงาน"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // ถ้าว่าง ให้ไปหน้าเมนู
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF6F4E37))),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (context.mounted) {
        Navigator.pop(context); 
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MenuScreen(tableNumber: tableNo),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("สแกน QR-Code (ลูกค้า)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      // ใช้ StreamBuilder ดึงสถานะโต๊ะแบบ Real-time
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tables').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          
          // แปลงข้อมูลเป็น Map เพื่อให้ดึงใช้ง่ายๆ { '1': 'occupied', '2': 'available' }
          Map<String, String> tableStatusMap = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              tableStatusMap[doc.id] = data['status'] ?? 'available';
            }
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF6F4E37)),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text(
                    "จำลองสแกน QR-Code",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                  ),
                  const Text(
                    "สำหรับทดสอบระบบ",
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                  
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 14, color: Color(0xFFA6C48A)),
                      SizedBox(width: 5),
                      Text("ว่าง", style: TextStyle(color: Colors.grey)),
                      SizedBox(width: 20),
                      Icon(Icons.circle, size: 14, color: Colors.red),
                      SizedBox(width: 5),
                      Text("ไม่ว่าง", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  // --- Grid ปุ่มเลือกโต๊ะ (1-8) ---
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: List.generate(8, (index) {
                      String tableNum = "${index + 1}";
                      
                      // เช็คสถานะจาก Map
                      String status = tableStatusMap[tableNum] ?? 'available';
                      bool isOccupied = status == 'occupied';

                      return SizedBox(
                        width: 80,
                        height: 80,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            // ถ้าไม่ว่าง -> สีแดงอ่อน, ตัวหนังสือแดง
                            // ถ้าว่าง -> สีเขียวธีม, ตัวหนังสือขาว
                            backgroundColor: isOccupied ? Colors.red[50] : const Color(0xFFA6C48A), 
                            foregroundColor: isOccupied ? Colors.red : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isOccupied ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
                            ),
                            padding: EdgeInsets.zero,
                            elevation: isOccupied ? 0 : 3,
                          ),
                          onPressed: () => _selectTable(context, tableNum, isOccupied),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOccupied ? Icons.no_meals : Icons.table_restaurant, 
                                size: 28,
                                color: isOccupied ? Colors.red : Colors.white
                              ),
                              const SizedBox(height: 4),
                              Text("โต๊ะ $tableNum", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // --- ปุ่มสั่งกลับบ้าน (เสมอต้นเสมอปลาย) ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTable(context, "TA-001", false),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text("สั่งกลับบ้าน (Take Away)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5D4037),
                        side: const BorderSide(color: Color(0xFF5D4037), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}