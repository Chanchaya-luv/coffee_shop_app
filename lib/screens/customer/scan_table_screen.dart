import 'package:flutter/material.dart';
import 'menu_screen.dart'; // ตรวจสอบว่ามีไฟล์นี้จริง

class ScanTableScreen extends StatefulWidget {
  const ScanTableScreen({super.key});

  @override
  State<ScanTableScreen> createState() => _ScanTableScreenState();
}

class _ScanTableScreenState extends State<ScanTableScreen> {
  // ไม่ต้องใช้ MobileScannerController แล้ว

  void _navigateToMenu(String tableNo) {
    // จำลองการโหลดนิดนึงให้ดูสมจริง
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // ปิด Loading
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MenuScreen(tableNumber: tableNo),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("สแกน QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFF6F4E37)),
              const SizedBox(height: 20),
              const Text(
                "จำลองการสแกน QR Code",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
              ),
              const Text(
                "(สำหรับทดสอบระบบ)",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // ปุ่มเลือกโต๊ะจำลอง
              const Text("เลือกโต๊ะที่ต้องการสั่ง:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: List.generate(8, (index) {
                  int tableNum = index + 1;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA6C48A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onPressed: () => _navigateToMenu("$tableNum"),
                    child: Text("โต๊ะ $tableNum", style: const TextStyle(fontSize: 16)),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => _navigateToMenu("TA-001"),
                child: const Text("สั่งกลับบ้าน (Take Away)"),
              )
            ],
          ),
        ),
      ),
    );
  }
}