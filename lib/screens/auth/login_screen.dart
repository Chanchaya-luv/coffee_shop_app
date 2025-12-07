import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // --- 🔥 ตัวแปรเก็บรายการอีเมลที่เคยล็อกอิน ---
  List<String> _savedEmails = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEmails(); // โหลดประวัติ
  }

  // โหลดรายการอีเมลจากเครื่อง
  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmails = prefs.getStringList('login_history') ?? [];
      // ถ้ามีประวัติ ให้เติมค่าล่าสุดลงในช่องเลย
      if (_savedEmails.isNotEmpty) {
        _emailCtrl.text = _savedEmails.first;
      }
    });
  }

  // บันทึกอีเมลใหม่ลงในประวัติ
  Future<void> _saveEmailToHistory(String email) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('login_history') ?? [];
    
    // ลบตัวเดิมออกก่อน (ถ้ามี) แล้วแทรกตัวใหม่ไปไว้หน้าสุด
    history.remove(email);
    history.insert(0, email);

    // เก็บแค่ 5 รายการล่าสุดพอ (กันเยอะเกิน)
    if (history.length > 5) {
      history = history.sublist(0, 5);
    }

    await prefs.setStringList('login_history', history);
  }

  void _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      String email = _emailCtrl.text.trim();
      await AuthService().signIn(email, _passCtrl.text.trim());
      
      // ✅ บันทึกลงประวัติเมื่อล็อกอินสำเร็จ
      await _saveEmailToHistory(email);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เข้าสู่ระบบไม่สำเร็จ: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
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
              // Logo
              const CircleAvatar(
                radius: 60, 
                backgroundColor: Colors.transparent, 
                backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'),
              ),
              
              const SizedBox(height: 20),
              const Text("Caffy", style: TextStyle(fontFamily: 'Serif', fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              const Text("ระบบจัดการร้านกาแฟ", style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),

              // --- 🔥 ช่องอีเมลแบบ Autocomplete (Dropdown) ---
              LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<String>(
                    initialValue: TextEditingValue(text: _emailCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return _savedEmails.where((String option) {
                        return option.contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      _emailCtrl.text = selection;
                    },
                    // ปรับแต่งหน้าตาช่องกรอก
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      // เชื่อม controller ภายในกับ _emailCtrl ของเรา
                      if (controller.text != _emailCtrl.text) {
                        controller.text = _emailCtrl.text;
                      }
                      // ฟังการเปลี่ยนแปลงกลับ
                      controller.addListener(() {
                        _emailCtrl.text = controller.text;
                      });

                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF5D4037)),
                          hintText: "อีเมล",
                          filled: true, 
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          // ปุ่มกดเพื่อโชว์ประวัติทั้งหมด
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            onSelected: (String value) {
                              controller.text = value;
                              _emailCtrl.text = value;
                            },
                            itemBuilder: (BuildContext context) {
                              return _savedEmails.map((String value) {
                                return PopupMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      );
                    },
                    // ปรับแต่งหน้าตา Dropdown ที่เด้งขึ้นมา
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            width: constraints.maxWidth, // ความกว้างเท่าช่องกรอก
                            color: Colors.white,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              ),

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