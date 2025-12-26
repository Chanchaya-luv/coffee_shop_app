import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = [
      _buildHomeDashboard(), // หน้า 0
      const OrdersScreen(),  // หน้า 1
      const ReportScreen(isFullReport: false), // หน้า 2
      const SettingScreen(), // หน้า 3
    ];

    _listenToNewOrders();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _listenToNewOrders() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {

      // --- 🔥 1. อัปเดตตัวเลขแจ้งเตือนให้ตรงกับจำนวนจริงเสมอ ---
      if (mounted) {
        setState(() {
          _notificationCount = snapshot.docs.length;
        });
      }

      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final tableNo = data['tableNumber'] ?? '?';

          if (!mounted) return;

          final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
          if (!isCurrentRoute) return;

          // แสดง SnackBar แจ้งเตือนเมื่อมีออเดอร์ใหม่เข้ามา
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green[800],
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "🔔 มีออเดอร์ใหม่! โต๊ะ $tableNo",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'ดูรายการ',
                textColor: Colors.yellowAccent,
                onPressed: () {
                  setState(() => _selectedIndex = 1);
                },
              ),
            ),
          );
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
        // --- 🔥 2. เพิ่ม Badge บนไอคอน Orders ---
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _notificationCount > 0, // ซ่อนถ้าเป็น 0
              label: Text('$_notificationCount'), // ตัวเลข
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Report'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isTablet = constraints.maxWidth > 600;

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
                    const SizedBox(height: 10),
                    _buildRealTimeStats(isTablet), 
                    const SizedBox(height: 30),
                    _buildMenuGrid(context, isTablet),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFF6F4E37)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              String name = "ผู้ใช้งาน"; 
              String imageUrl = "https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png"; 
              
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? name;
                if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
                  imageUrl = data['photoUrl'];
                }
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(imageUrl),
                    backgroundColor: Colors.transparent,
                    onBackgroundImageError: (_,__) => const Icon(Icons.error), 
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("สวัสดี,", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Serif')),
                    ],
                  )
                ],
              );
            }
          ),

          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28), 
            
            onPressed: () {
              // ไม่ต้องรีเซ็ต _notificationCount เป็น 0 ที่นี่แล้ว เพราะมันจะ Stream มาจาก DB เอง
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            }
          ),
        ],
      ),
    );
  }

  // --- Widget Stats เปรียบเทียบเมื่อวาน ---
  Widget _buildRealTimeStats(bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, orderSnapshot) {
        double salesToday = 0;
        int ordersToday = 0;
        
        double salesYesterday = 0;
        int ordersYesterday = 0;
        
        if (orderSnapshot.hasData) {
          final now = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

          for (var doc in orderSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? ts = data['timestamp'];
            
            if (ts != null) {
              final date = ts.toDate();
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              
              if (data['status'] != 'cancelled') {
                double price = (data['totalPrice'] ?? 0).toDouble();
                if (dateStr == todayStr) {
                  salesToday += price;
                  ordersToday += 1;
                } else if (dateStr == yesterdayStr) {
                  salesYesterday += price;
                  ordersYesterday += 1;
                }
              }
            }
          }
        }

        String salesGrowthStr = _calculateGrowth(salesToday, salesYesterday);
        bool salesPositive = _isGrowthPositive(salesToday, salesYesterday);

        String ordersGrowthStr = _calculateGrowth(ordersToday.toDouble(), ordersYesterday.toDouble());
        bool ordersPositive = _isGrowthPositive(ordersToday.toDouble(), ordersYesterday.toDouble());

        double gpToday = salesToday * 0.4;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ingredients').snapshots(),
          builder: (context, ingSnapshot) {
            int lowStockCount = 0;
            if (ingSnapshot.hasData) {
              for (var doc in ingSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final double current = (data['currentStock'] ?? 0).toDouble();
                final double min = (data['minThreshold'] ?? 0).toDouble();
                if (current <= min) {
                  lowStockCount++;
                }
              }
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isTablet ? 4 : 2, 
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  "ยอดขายวันนี้", 
                  "${NumberFormat('#,##0').format(salesToday)} บาท", 
                  "$salesGrowthStr เทียบเมื่อวาน", 
                  isPositive: salesPositive
                ),
                _buildStatCard(
                  "จำนวนออเดอร์วันนี้", 
                  "$ordersToday ออเดอร์", 
                  "$ordersGrowthStr เทียบเมื่อวาน", 
                  isPositive: ordersPositive
                ),
                _buildStatCard(
                  "วัตถุดิบใกล้หมด", 
                  "$lowStockCount รายการ", 
                  "เติมด่วน", 
                  isAlert: lowStockCount > 0
                ),
                _buildStatCard(
                  "กำไรขั้นต้น (GP)", 
                  "${NumberFormat('#,##0').format(gpToday)} บาท", 
                  "~40% Est."
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _calculateGrowth(double current, double previous) {
    if (previous == 0) {
      return current > 0 ? "+100%" : "0%";
    }
    double growth = ((current - previous) / previous) * 100;
    return "${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%";
  }

  bool _isGrowthPositive(double current, double previous) {
    if (previous == 0) return current >= 0;
    return current >= previous;
  }

  Widget _buildStatCard(String title, String value, String subtitle, {bool isPositive = false, bool isAlert = false}) {
    Color subColor = Colors.grey;
    if (isAlert) {
      subColor = Colors.red;
    } else if (title.contains("GP")) {
      subColor = Colors.blue;
    } else {
      subColor = isPositive ? Colors.green : Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : const Color(0xFF5D4037)),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context, bool isTablet) {
    final menuItems = [
      {'icon': Icons.monetization_on, 'label': 'การเงิน', 'page': const FinanceScreen()},
      {'icon': Icons.inventory_2, 'label': 'จัดการสต๊อกวัตถุดิบ', 'page': const StockScreen()},
      {
        'icon': Icons.bar_chart, 
        'label': 'สรุปยอดขาย    (ภาพรวม)', 
        'page': const ReportScreen(isFullReport: true) 
      },
      {'icon': Icons.coffee, 'label': 'Quick Menu', 'page': const QuickMenuScreen()},
      {
        'icon': Icons.local_offer, 
        'label': 'จัดการโปรโมชั่น', 
        'page': const PromotionManagementScreen()
      },
      {'icon': Icons.percent, 'label': 'คำนวณ GP', 'page': const GPCalculatorScreen()},
      {
        'icon': Icons.restaurant_menu, 
        'label': 'จัดการเมนู', 
        'page': const ManageMenuScreen()
      },
      {
        'icon': Icons.tv, 
        'label': 'จอเรียกคิว (Queue)', 
        'page': const QueueDisplayScreen()
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 6 : 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.0,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return _buildMenuButton(
          context,
          menuItems[index]['icon'] as IconData,
          menuItems[index]['label'] as String,
          menuItems[index]['page'] as Widget?,
        );
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
          if (page != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => page));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ฟีเจอร์นี้กำลังพัฒนา...")));
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF5D4037), size: 28),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}