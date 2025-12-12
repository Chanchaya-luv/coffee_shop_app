import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import หน้าจอต่างๆ
import '../customer/quick_menu_screen.dart';
import '../order/orders_screen.dart';
import '../admin/gp_calculator_screen.dart';
import '../setting/setting_screen.dart';
import '../admin/report_screen.dart'; 
import '../admin/finance_screen.dart'; 
import '../admin/manage_menu_screen.dart';
import '../setting/notification_screen.dart';
import '../stock/stock_screen.dart';
import '../admin/promotion_management_screen.dart';

// --- 🔥 เพิ่ม Import หน้าจอคิว ---
import '../customer/queue_display_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  
  StreamSubscription? _orderSubscription;
  bool _isFirstLoad = true; 
  int _notificationCount = 0;
  
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = [
      _buildHomeDashboard(),
      const OrdersScreen(),
      const ReportScreen(isFullReport: false),
      const SettingScreen(),
    ];
    _listenToNewOrders();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _listenToNewOrders() {
    _orderSubscription = FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
      if (_isFirstLoad) {
        if (mounted) setState(() { _notificationCount = snapshot.docs.length; _isFirstLoad = false; });
        return;
      }
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          String tableNo = data['tableNumber'] ?? '?';
          if (mounted) {
            setState(() => _notificationCount++);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.green[800], margin: const EdgeInsets.all(10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), content: Row(children: [const Icon(Icons.notifications_active, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text("🔔 มีออเดอร์ใหม่! โต๊ะ $tableNo", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'ดูรายการ', textColor: Colors.yellowAccent, onPressed: () { setState(() => _selectedIndex = 1); })));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFA6C48A),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Home", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                const SizedBox(height: 20),
                _buildRealTimeStats(), 
                const SizedBox(height: 30),
                _buildMenuGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFF6F4E37)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
            builder: (context, snapshot) {
              String name = "Caffy";
              String imageUrl = "https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png";
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? name;
                if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) imageUrl = data['photoUrl'];
              }
              return Row(children: [CircleAvatar(radius: 24, backgroundImage: NetworkImage(imageUrl), backgroundColor: Colors.transparent), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("สวัสดี,", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Serif'))])]);
            }
          ),
          Row(children: [Stack(clipBehavior: Clip.none, children: [IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28), onPressed: () { setState(() => _notificationCount = 0); Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())); }), if (_notificationCount > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Center(child: Text('$_notificationCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))))]), const SizedBox(width: 5)])
        ],
      ),
    );
  }

  Widget _buildRealTimeStats() { return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('orders').snapshots(), builder: (context, orderSnapshot) { double salesToday = 0; int ordersToday = 0; if (orderSnapshot.hasData) { final now = DateTime.now(); final todayStr = DateFormat('yyyy-MM-dd').format(now); for (var doc in orderSnapshot.data!.docs) { final data = doc.data() as Map<String, dynamic>; final Timestamp? ts = data['timestamp']; if (ts != null) { final date = ts.toDate(); final dateStr = DateFormat('yyyy-MM-dd').format(date); if (dateStr == todayStr && data['status'] != 'cancelled') { salesToday += (data['totalPrice'] ?? 0).toDouble(); ordersToday += 1; } } } } double gpToday = salesToday * 0.4; return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('ingredients').snapshots(), builder: (context, ingSnapshot) { int lowStockCount = 0; if (ingSnapshot.hasData) { for (var doc in ingSnapshot.data!.docs) { final data = doc.data() as Map<String, dynamic>; if (((data['currentStock'] ?? 0).toDouble()) <= ((data['minThreshold'] ?? 0).toDouble())) lowStockCount++; } } return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4, children: [_buildStatCard("ยอดขายวันนี้", "${NumberFormat('#,##0').format(salesToday)} บาท", "Real-time", isPositive: true), _buildStatCard("จำนวนออเดอร์วันนี้", "$ordersToday ออเดอร์", "รายการ", isPositive: true), _buildStatCard("วัตถุดิบใกล้หมด", "$lowStockCount รายการ", "เติมด่วน", isAlert: lowStockCount > 0), _buildStatCard("กำไรขั้นต้น (GP)", "${NumberFormat('#,##0').format(gpToday)} บาท", "~40% Est.")]); }); }); }
  Widget _buildStatCard(String title, String value, String subtitle, {bool isPositive = false, bool isAlert = false}) { return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)), const SizedBox(height: 5), Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : const Color(0xFF5D4037))), if (subtitle.isNotEmpty) ...[const SizedBox(height: 5), Text(subtitle, style: TextStyle(fontSize: 10, color: isAlert ? Colors.red : (isPositive ? Colors.green : Colors.grey)))]])); }

  Widget _buildMenuGrid(BuildContext context) {
    final menuItems = [
      {'icon': Icons.monetization_on, 'label': 'การเงิน', 'page': const FinanceScreen()},
      {'icon': Icons.inventory_2, 'label': 'จัดการสต๊อกวัตถุดิบ', 'page': const StockScreen()},
      {'icon': Icons.bar_chart, 'label': 'สรุปยอดขาย      (ภาพรวม)', 'page': const ReportScreen(isFullReport: true)},
      {'icon': Icons.coffee, 'label': 'Quick Menu', 'page': const QuickMenuScreen()},
      {'icon': Icons.local_offer, 'label': 'จัดการโปรโมชั่น', 'page': const PromotionManagementScreen()},
      {'icon': Icons.percent, 'label': 'คำนวณ GP', 'page': const GPCalculatorScreen()},
      {'icon': Icons.restaurant_menu, 'label': 'จัดการเมนู', 'page': const ManageMenuScreen()},
      
      // --- 🔥 เพิ่มปุ่มจอคิว ---
      {
        'icon': Icons.tv, 
        'label': 'จอเรียกคิว         (Queue)', 
        'page': const QueueDisplayScreen()
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.0),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return _buildMenuButton(context, menuItems[index]['icon'] as IconData, menuItems[index]['label'] as String, menuItems[index]['page'] as Widget?);
      },
    );
  }

  Widget _buildMenuButton(BuildContext context, IconData icon, String label, Widget? page) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          if (page != null) Navigator.push(context, MaterialPageRoute(builder: (context) => page));
          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ฟีเจอร์นี้กำลังพัฒนา...")));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF5D4037), size: 28)),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}