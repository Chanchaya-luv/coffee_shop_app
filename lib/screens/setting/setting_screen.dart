import 'package:flutter/material.dart';

// --- Import หน้าจอต่างๆ ---
import '../admin/gp_calculator_screen.dart';
import '../stock/stock_screen.dart'; 
import '../customer/quick_menu_screen.dart'; 
import '../../services/auth_service.dart';
import '../order/order_history_screen.dart';
import '../admin/manage_menu_screen.dart';
import 'payment_settings_screen.dart';
import 'notification_screen.dart';
// 🔥 เพิ่ม Import หน้าสาขา
import '../admin/branch_management_screen.dart'; 

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการออกจากระบบ"),
        content: const Text("คุณต้องการออกจากระบบใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
            },
            child: const Text("ออกจากระบบ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    double paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // --- Header ---
            Container(
              padding: EdgeInsets.only(top: paddingTop + 20, left: 20, right: 20, bottom: 20),
              decoration: const BoxDecoration(color: Color(0xFF6F4E37)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'),
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(width: 10),
                    const Text("Caffy", style: TextStyle(fontFamily: 'Serif', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                  
                  const CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'), backgroundColor: Colors.grey),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // --- 1. การตั้งค่าทั่วไป ---
                  _buildSettingsGroup(
                    title: "การตั้งค่าทั่วไป",
                    children: [
                      _buildSettingItem(Icons.store, "ข้อมูลร้านค้า", onTap: () => _navigate(context, const StoreProfileScreen())),
                      
                      // --- 🔥 เพิ่มเมนูจัดการสาขา ---
                      _buildSettingItem(
                        Icons.store_mall_directory, 
                        "จัดการสาขา", 
                        onTap: () => _navigate(context, const BranchManagementScreen())
                      ),

                      _buildSettingItem(Icons.history, "ประวัติออเดอร์", onTap: () => _navigate(context, const OrderHistoryScreen())),
                      _buildSettingItem(Icons.payment, "การตั้งค่าการชำระเงิน", onTap: () => _navigate(context, const PaymentSettingsScreen())),
                      _buildSettingItem(Icons.notifications_active_outlined, "การแจ้งเตือน", showDivider: false, onTap: () => _navigate(context, const NotificationScreen())),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 2. สต็อก & เมนู ---
                  _buildSettingsGroup(
                    title: "สต็อก & เมนู",
                    children: [
                      _buildSettingItem(Icons.inventory_2_outlined, "การจัดการวัตถุดิบ", onTap: () => _navigate(context, const StockScreen())),
                      _buildSettingItem(Icons.restaurant_menu, "การจัดการเมนู", onTap: () => _navigate(context, const ManageMenuScreen())),
                      _buildSettingItem(Icons.bar_chart, "การคำนวณ GP", showDivider: false, onTap: () => _navigate(context, const GPCalculatorScreen())),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 3. ความปลอดภัย ---
                  _buildSettingsGroup(
                    title: "ความปลอดภัย",
                    children: [
                      _buildSettingItem(Icons.vpn_key_outlined, "บัญชีและความปลอดภัย", showDivider: false, onTap: () => _navigate(context, const GenericSettingsScreen(title: "ความปลอดภัย"))),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ปุ่ม Logout
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _confirmSignOut(context),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text("ออกจากระบบ", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 10, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, {bool showDivider = true, required VoidCallback onTap}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF5D4037)),
          title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 50, endIndent: 20, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

// Mockup Screens (เหมือนเดิม)
class StoreProfileScreen extends StatelessWidget {
  const StoreProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ข้อมูลร้านค้า"), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'), backgroundColor: Colors.transparent),
            const SizedBox(height: 20),
            TextFormField(initialValue: "Caffy Coffee", decoration: const InputDecoration(labelText: "ชื่อร้าน", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(initialValue: "081-234-5678", decoration: const InputDecoration(labelText: "เบอร์โทรศัพท์", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(initialValue: "กรุงเทพมหานคร", decoration: const InputDecoration(labelText: "ที่อยู่", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("บันทึกการเปลี่ยนแปลง"))
          ],
        ),
      ),
    );
  }
}

class GenericSettingsScreen extends StatelessWidget {
  final String title;
  const GenericSettingsScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_applications, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text("$title \n(ฟีเจอร์นี้อยู่ระหว่างการพัฒนา)", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}