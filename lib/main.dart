import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import สำหรับตรวจสอบ User

// --- Import ไฟล์ตามโครงสร้างของคุณ ---
import 'firebase_options.dart';               
import 'providers/cart_provider.dart';        
import 'screens/home/home_screen.dart';       
import 'screens/auth/login_screen.dart'; // Import หน้า Login

void main() async {
  // 1. เตรียมระบบให้พร้อมก่อนเริ่มแอป
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. เริ่มต้น Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. รันแอป
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 4. หุ้มแอปด้วย MultiProvider เพื่อให้ระบบตะกร้า (Cart) ใช้ได้ทุกหน้า
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Caffy Shop',
        debugShowCheckedModeBanner: false, // ปิดป้าย Debug มุมขวาบน

        // --- 5. ตั้งค่า Theme สี Earth Tone (น้ำตาล-เขียว) ---
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Kanit', 
          
          // ชุดสีหลักของแอป
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F4E37),   // น้ำตาลเข้ม
            primary: const Color(0xFF6F4E37),     
            secondary: const Color(0xFFA6C48A),   // สีเขียว
            surface: const Color(0xFFF9F9F9),     
            background: const Color(0xFFF9F9F9),  
          ),

          scaffoldBackgroundColor: const Color(0xFFF9F9F9),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6F4E37),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA6C48A),
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFA6C48A),
            foregroundColor: Colors.white,
          ),
        ),

        // --- 6. จุดเปลี่ยนสำคัญ: เช็คสถานะล็อกอินก่อนเข้าแอป ---
        home: StreamBuilder<User?>(
          // ดักฟังว่าล็อกอินอยู่ไหม (authStateChanges)
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // กรณี 1: กำลังโหลดข้อมูล (เช่น เน็ตช้า) ให้หมุนรอ
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // กรณี 2: มีข้อมูล User แล้ว (ล็อกอินค้างไว้) -> ไปหน้า Home เลย
            if (snapshot.hasData) {
              return const HomeScreen();
            }

            // กรณี 3: ยังไม่มี User (ยังไม่ล็อกอิน/กด Logout) -> ไปหน้า Login
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}