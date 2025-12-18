import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart'; // Import เพื่อเรียก AuthCheck

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. ตั้งค่า Animation (ให้โลโก้ขยายเข้า-ออก เหมือนหายใจ)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // เล่นวนไปมา

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 2. ตั้งเวลา 3 วินาที แล้วไปหน้าถัดไป
    Timer(const Duration(seconds: 3), () {
      // หยุด Animation
      _controller.dispose();
      
      // ไปหน้า AuthCheck (ตัวเช็คว่าต้องไป Login หรือ Home)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthCheck()),
      );
    });
  }

  // (กรณีปิดหน้าจอก่อนกำหนด ต้อง dispose controller ด้วย)
  // แต่เนื่องจากเรา dispose ใน Timer แล้ว อาจจะต้องระวัง error
  // วิธีที่ปลอดภัยคือเช็ค mounted ใน Timer หรือ dispose ใน dispose method ปกติ
  @override
  void dispose() {
    if (_controller.isAnimating) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // สีพื้นหลังเดียวกับแอป
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 🔥 โลโก้ขยับได้ ---
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6F4E37).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.transparent,
                  backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // ชื่อร้าน
            const Text(
              "Caffy Coffee",
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "ระบบจัดการร้านกาแฟ",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 50),
            // Loading เล็กๆ ด้านล่าง
            const CircularProgressIndicator(color: Color(0xFFA6C48A)),
          ],
        ),
      ),
    );
  }
}