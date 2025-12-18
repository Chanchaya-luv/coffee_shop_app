import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';               
import 'providers/cart_provider.dart';        
// ลบ import language_provider ออก
import 'screens/home/home_screen.dart';       
import 'screens/auth/login_screen.dart'; 
import 'screens/splash/splash_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // ลบ LanguageProvider ออก
      ],
      child: MaterialApp(
        title: 'Caffy Shop',
        debugShowCheckedModeBanner: false,
        
        // ลบ locale ออก
        
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Kanit', 
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F4E37),
            primary: const Color(0xFF6F4E37),     
            secondary: const Color(0xFFA6C48A),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFA6C48A),
            foregroundColor: Colors.white,
          ),
        ),

        home: const SplashScreen(), 
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9F9F9),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF6F4E37))),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen(); 
        }
        return const LoginScreen(); 
      },
    );
  }
}