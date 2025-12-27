import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import '../home/home_screen.dart';
import 'customer_tracking_screen.dart';
import 'queue_display_screen.dart'; 

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final bool isCustomer; // รับค่าว่าใครเป็นคนสั่ง

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.isCustomer,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // --- 🔮 ข้อมูลคำทำนาย (สายมู) ---
  final List<Map<String, String>> _fortunes = [
    {'text': 'วันนี้พลังงานล้นเหลือ กาแฟแก้วนี้จะพาคุณไปแตะขอบฟ้า!', 'color': 'สีส้ม', 'lucky': '9'},
    {'text': 'พักบ้างนะคนเก่ง ดื่มแก้วนี้แล้วงานจะลื่นไหลเหมือนสายน้ำ', 'color': 'สีฟ้า', 'lucky': '5'},
    {'text': 'จะมีโชคลาภลอยมาแบบงงๆ อาจจะมาจากคนข้างๆ', 'color': 'สีแดง', 'lucky': '8'},
    {'text': 'ความรักหวานเจี๊ยบ เหมือนความหวานที่คุณสั่งวันนี้เลย', 'color': 'สีชมพู', 'lucky': '2'},
    {'text': 'อุปสรรคมีไว้ให้ข้าม กาแฟมีไว้ให้ดื่ม สู้ต่อไป!', 'color': 'สีเขียว', 'lucky': '1'},
    {'text': 'วันนี้เป็นวันของคุณ! ทำอะไรก็สำเร็จ (ถ้าตื่นทัน)', 'color': 'สีทอง', 'lucky': '7'},
    {'text': 'ระวังหมาเห่า... แต่ไม่ต้องกลัว เพราะคุณเท่', 'color': 'สีม่วง', 'lucky': '3'},
    {'text': 'ยิ้มเข้าไว้ โลกจะเหวี่ยงสิ่งดีๆ มาหาคุณหลังดื่มแก้วนี้หมด', 'color': 'สีเหลือง', 'lucky': '6'},
  ];

  @override
  void initState() {
    super.initState();
    // Animation สำหรับไอคอน Success
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..forward();

    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- 🔥 ฟังก์ชันสุ่มคำทำนาย ---
  void _showFortuneDialog() {
    var random = Random();
    var fortune = _fortunes[random.nextInt(_fortunes.length)];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple, size: 50),
            const SizedBox(height: 10),
            const Text("ดวงชะตาจากก้นแก้ว ☕️", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple)),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              '"${fortune['text']}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text("สีมงคล", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(fortune['color']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text("เลขนำโชค", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(fortune['lucky']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF6F4E37))),
                  ],
                ),
              ],
            )
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[50], foregroundColor: Colors.purple),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("รับพลังบวก! ✨"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6F4E37), width: 4),
                    ),
                    child: const Icon(Icons.check_rounded, size: 80, color: Colors.green),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                const Text("ยืนยันคำสั่งซื้อสำเร็จ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                const SizedBox(height: 10),
                Text("Order #${widget.orderId}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFA6C48A))),
                
                const SizedBox(height: 40),

                // --- 🔥 ปุ่มเปิดคำทำนาย (Highlight) ---
                if (widget.isCustomer)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _showFortuneDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: Colors.deepPurple.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("เปิดคำทำนายวันนี้ 🔮", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                // ปุ่มติดตามสถานะ (ของเดิม)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA6C48A), // สีเขียวธีม
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => CustomerTrackingScreen(orderId: widget.orderId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.access_time_filled),
                    label: const Text("ติดตามสถานะออเดอร์", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 15),
              ]
                

              
            ),
          ),
        ),
      ),
    );
  }
}