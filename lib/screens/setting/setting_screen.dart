import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/gp_calculator_screen.dart';
import '../stock/stock_screen.dart'; 
import '../customer/quick_menu_screen.dart'; 
import '../../services/auth_service.dart';
import '../order/order_history_screen.dart';
import '../admin/manage_menu_screen.dart';
import 'payment_settings_screen.dart';
import 'notification_screen.dart';
import '../admin/branch_management_screen.dart'; 

import 'manage_accounts_screen.dart';
import 'edit_profile_screen.dart';
import 'store_profile_screen.dart';
import 'generic_settings_screen.dart';
import 'help_center_screen.dart';
import '../admin/promotion_management_screen.dart';
import '../admin/expense_screen.dart';
import 'login_history_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String _currentUserRole = 'staff'; 
  
  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentUserRole = doc.data()?['role'] ?? 'staff';
          });
        }
      } catch (e) {
        print("Error fetching role: $e");
      }
    }
  }

  // เช็คว่ามีสิทธิ์แก้ไขหรือไม่ (Manager/Owner แก้ได้, Staff แก้ไม่ได้)
  bool get _canEdit {
    return _currentUserRole == 'manager' || _currentUserRole == 'owner';
  }

  bool get _canViewLogs {
    return _currentUserRole == 'manager' || _currentUserRole == 'owner' || _currentUserRole == 'admin';
  }

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

  // ไม่ต้องใช้ _navigateRestricted แล้ว เพราะเราจะให้เข้าได้ทุกคน แต่ส่ง isReadOnly ไปแทน

  @override
  Widget build(BuildContext context) {
    double paddingTop = MediaQuery.of(context).padding.top;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: paddingTop + 20, left: 20, right: 20, bottom: 20),
              decoration: const BoxDecoration(color: Color(0xFF6F4E37)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    CircleAvatar(radius: 24, backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'), backgroundColor: Colors.transparent),
                    SizedBox(width: 10),
                    Text("Caffy", style: TextStyle(fontFamily: 'Serif', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
                    builder: (context, snapshot) {
                      String name = "ผู้ใช้งาน"; String role = "staff"; String photoUrl = "";
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var data = snapshot.data!.data() as Map<String, dynamic>;
                        name = data['name'] ?? name; role = data['role'] ?? role; photoUrl = data['photoUrl'] ?? "";
                      }
                      String roleDisplay = "พนักงานทั่วไป";
                      if (role == 'manager') roleDisplay = "ผู้จัดการ";
                      if (role == 'owner') roleDisplay = "เจ้าของร้าน";
                      if (role == 'admin') roleDisplay = "ผู้ดูแลระบบ";

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2, margin: const EdgeInsets.only(bottom: 20),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(radius: 30, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? const Icon(Icons.person, size: 30) : null),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text("ตำแหน่ง: $roleDisplay", style: const TextStyle(color: Colors.grey)),
                          trailing: const Icon(Icons.edit, color: Color(0xFF6F4E37)),
                          onTap: () => _navigate(context, const EditProfileScreen()),
                        ),
                      );
                    }
                  ),

                  // Group 1: การตั้งค่าทั่วไป
                  _buildSettingsGroup(
                    title: "การตั้งค่าทั่วไป",
                    children: [
                      // --- 🔥 ส่งค่า isReadOnly: !_canEdit ไปบอกหน้าลูก ---
                      _buildSettingItem(
                        Icons.store, "ข้อมูลร้านค้า", 
                        onTap: () => _navigate(context, StoreProfileScreen(isReadOnly: !_canEdit))
                      ),
                      
                      _buildSettingItem(
                        Icons.store_mall_directory, "จัดการสาขา", 
                        onTap: () => _navigate(context, BranchManagementScreen(isReadOnly: !_canEdit))
                      ),
                      
                      _buildSettingItem(Icons.history, "ประวัติออเดอร์", onTap: () => _navigate(context, const OrderHistoryScreen())),

                      _buildSettingItem(
                        Icons.monetization_on_outlined, 
                        "บันทึกรายจ่าย", 
                        onTap: () => _navigate(context, const ExpenseScreen())),
                      
                      _buildSettingItem(Icons.payment, "การตั้งค่าการชำระเงิน", onTap: () => _navigate(context, PaymentSettingsScreen(isReadOnly: !_canEdit))),
                      
                      _buildSettingItem(Icons.notifications_active_outlined, "การแจ้งเตือน", onTap: () => _navigate(context, const NotificationScreen())),
                      _buildSettingItem(Icons.help_outline, "ศูนย์ช่วยเหลือ", showDivider: false, onTap: () => _navigate(context, const HelpCenterScreen())),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Group 2: สต็อก & เมนู
                  _buildSettingsGroup(
                    title: "สต็อก & เมนู",
                    children: [
                      _buildSettingItem(Icons.inventory_2_outlined, "การจัดการวัตถุดิบ", onTap: () => _navigate(context, const StockScreen())),
                      _buildSettingItem(Icons.restaurant_menu, "การจัดการเมนู", onTap: () => _navigate(context, const ManageMenuScreen())),
                      _buildSettingItem(Icons.local_offer, "จัดการโปรโมชั่น", onTap: () => _navigate(context, const PromotionManagementScreen())),
                      _buildSettingItem(Icons.bar_chart, "การคำนวณ GP", showDivider: false, onTap: () => _navigate(context, const GPCalculatorScreen())),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Group 3: บัญชีและความปลอดภัย
                  _buildSettingsGroup(
                    title: "บัญชีและความปลอดภัย",
                    children: [
                      // อันนี้ยังคงล็อกไว้เหมือนเดิม เพราะ Staff ไม่ควรเห็นรายชื่อคนอื่น
                      _buildSettingItem(
                        Icons.manage_accounts, "จัดการบัญชีและพนักงาน", 
                        isRestricted: !_canEdit, // ยังคงล็อกห้ามเข้าสำหรับ Staff
                        onTap: () {
                          if (_canEdit) _navigate(context, const ManageAccountsScreen());
                          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔️ ไม่มีสิทธิ์เข้าถึง"), backgroundColor: Colors.red));
                        }
                      ),
                      _buildSettingItem(
                        Icons.security, "ประวัติการเข้าใช้งาน", 
                        isRestricted: !_canViewLogs, // ล็อกถ้าไม่ใช่ Manager/Owner/Admin
                        onTap: () { 
                          if (_canViewLogs) _navigate(context, const LoginHistoryScreen()); 
                          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔️ ไม่มีสิทธิ์เข้าถึง"), backgroundColor: Colors.red)); 
                        }
                      ),
                      _buildSettingItem(Icons.vpn_key_outlined, "เปลี่ยนรหัสผ่าน / แก้ไขข้อมูล", showDivider: false, onTap: () => _navigate(context, const EditProfileScreen())),
                    ],
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity, height: 50,
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

  Widget _buildSettingsGroup({required String title, required List<Widget> children}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 10, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))), Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]), child: Column(children: children))]); }
  
  // ปรับ Widget ให้แสดงไอคอนปกติ แต่ถ้าไม่มีสิทธิ์อาจจะเปลี่ยนสีเล็กน้อย (แต่ในที่นี้เราให้เข้าได้ เลยใช้สีปกติ)
  Widget _buildSettingItem(IconData icon, String title, {bool showDivider = true, required VoidCallback onTap, bool isRestricted = false}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: isRestricted ? Colors.grey : const Color(0xFF5D4037)),
          title: Text(title, style: TextStyle(fontSize: 16, color: isRestricted ? Colors.grey : Colors.black87)),
          trailing: isRestricted 
              ? const Icon(Icons.lock, color: Colors.grey, size: 20) 
              : const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 50, endIndent: 20, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}