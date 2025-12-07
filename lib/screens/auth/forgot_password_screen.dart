import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  void _sendResetLink() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณากรอกอีเมล")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().resetPassword(_emailCtrl.text.trim());
      
      if (!mounted) return;
      
      // แสดงข้อความแจ้งเตือน
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("เช็คอีเมลของคุณ"),
          content: Text("เราได้ส่งลิงก์สำหรับเปลี่ยนรหัสผ่านไปที่ ${_emailCtrl.text} แล้ว กรุณาตรวจสอบในกล่องจดหมาย (หรือ Junk Mail)"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // ปิด Dialog
                Navigator.pop(context); // กลับไปหน้า Login
              },
              child: const Text("ตกลง"),
            )
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ลืมรหัสผ่าน"),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF5D4037),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "กรอกอีเมลที่คุณใช้สมัครสมาชิก \nเราจะส่งลิงก์เพื่อตั้งรหัสผ่านใหม่ไปให้",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF5D4037)),
                hintText: "อีเมล",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA6C48A), // สีเขียว
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isLoading ? null : _sendResetLink,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ส่งลิงก์เปลี่ยนรหัสผ่าน", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}