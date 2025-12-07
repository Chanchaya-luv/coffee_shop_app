import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ฟังก์ชันล็อกอิน
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      rethrow; 
    }
  }

  // ฟังก์ชันสมัครสมาชิก
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // --- 🔥 เพิ่มฟังก์ชันนี้: รีเซ็ตรหัสผ่าน ---
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // ฟังก์ชันออกจากระบบ
  Future<void> signOut() async {
    await _auth.signOut();
  }
}