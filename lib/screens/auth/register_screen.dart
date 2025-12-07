import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController(); // ชื่อ
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _imageCtrl = TextEditingController(); // ลิงก์รูป
  
  bool _isLoading = false;

  void _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณากรอกข้อมูลจำเป็นให้ครบ"), backgroundColor: Colors.red));
      return;
    }
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("รหัสผ่านไม่ตรงกัน"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // เรียกใช้ฟังก์ชัน register แบบใหม่ที่ส่งชื่อและรูปไปด้วย
      await AuthService().register(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _imageCtrl.text.trim()
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกสำเร็จ!"), backgroundColor: Colors.green));
        Navigator.pop(context); // กลับไปหน้า Login
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("สมัครสมาชิกไม่สำเร็จ: ${e.toString()}"), backgroundColor: Colors.red),
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
        title: const Text("สมัครสมาชิกพนักงาน", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF5D4037),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Create Account", style: TextStyle(fontFamily: 'Serif', fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              const SizedBox(height: 30),

              // --- ช่องกรอกข้อมูล ---
              _buildTextField("ชื่อพนักงาน / ชื่อร้าน", _nameCtrl, icon: Icons.person),
              const SizedBox(height: 15),
              _buildTextField("อีเมล", _emailCtrl, icon: Icons.email_outlined),
              const SizedBox(height: 15),
              _buildTextField("รหัสผ่าน", _passCtrl, isPassword: true, icon: Icons.lock_outline),
              const SizedBox(height: 15),
              _buildTextField("ยืนยันรหัสผ่าน", _confirmPassCtrl, isPassword: true, icon: Icons.lock_outline),
              
              const SizedBox(height: 15),
              _buildTextField("ลิงก์รูปโปรไฟล์ (URL) *ไม่บังคับ", _imageCtrl, icon: Icons.image),
              
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ลงทะเบียน", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("มีบัญชีอยู่แล้ว? "), GestureDetector(onTap: () => Navigator.pop(context), child: const Text("เข้าสู่ระบบ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6F4E37))))]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl, {bool isPassword = false, IconData? icon}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF6F4E37)),
        hintText: hint,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }
}