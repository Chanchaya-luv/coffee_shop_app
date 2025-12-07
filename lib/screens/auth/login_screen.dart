import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart'; 
import '../customer/scan_table_screen.dart'; 
import 'forgot_password_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เข้าสู่ระบบไม่สำเร็จ: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- 🔥 เปลี่ยน Logo ตรงนี้ ---
              const CircleAvatar(
                radius: 60, // ปรับขนาดความใหญ่ของรูป
                backgroundColor: Colors.transparent, // พื้นหลังใส
                backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'),
              ),
              
              const SizedBox(height: 20),
              const Text("Caffy", style: TextStyle(fontFamily: 'Serif', fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              const Text("ระบบจัดการร้านกาแฟ", style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),

              // --- Form Login ---
              _buildTextField("อีเมล", _emailCtrl, icon: Icons.email_outlined),
              const SizedBox(height: 15),
              _buildTextField("รหัสผ่าน", _passCtrl, isPassword: true, icon: Icons.lock_outline),
              
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                  }, 
                  child: const Text("ลืมรหัสผ่าน?", style: TextStyle(color: Colors.grey)),
                ),
              ),

              const SizedBox(height: 20),

              // ปุ่มเข้าสู่ระบบ
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("เข้าสู่ระบบ (Admin)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),
              
              // ปุ่มสมัครสมาชิก
              Row(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  const Text("ยังไม่มีบัญชีผู้ใช้? "), 
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), 
                    child: const Text("สมัครสมาชิก", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))
                  )
                ]
              ),

              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),

              // --- ปุ่มสำหรับลูกค้า ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA6C48A), width: 2), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScanTableScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFA6C48A)),
                  label: const Text("สแกนเพื่อสั่งอาหาร (ลูกค้า)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFA6C48A))),
                ),
              ),
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
        prefixIcon: Icon(icon, color: const Color(0xFF5D4037)),
        hintText: hint,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }
}