import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // 1. ล็อกอิน
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // 2. สร้างพนักงาน (Create)
  Future<void> createEmployee(String email, String password, String name, String role, String photoUrl) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential result = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);
      
      if (result.user != null) {
        await _saveUserToFirestore(result.user!.uid, name, email, photoUrl, role);
      }
      
      await secondaryApp.delete();
    } catch (e) {
      await secondaryApp?.delete();
      rethrow;
    }
  }

  // --- 🔥 3. ฟังก์ชันแก้ไขข้อมูลพนักงาน (Update) ---
  Future<void> updateEmployeeData(String uid, String name, String role) async {
    await _db.collection('users').doc(uid).update({
      'name': name,
      'role': role,
    });
  }

  Future<void> _saveUserToFirestore(String uid, String name, String email, String photoUrl, String role) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl.isEmpty 
          ? 'https://cdn-icons-png.flaticon.com/512/149/149071.png' 
          : photoUrl,
      'role': role, 
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // สมัครสมาชิกเอง (Owner)
  Future<User?> register(String email, String password, String name, String photoUrl) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        await _saveUserToFirestore(user.uid, name, email, photoUrl, 'owner');
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  // แก้ไขโปรไฟล์ตัวเอง
  Future<void> updateProfile({String? name, String? photoUrl}) async {
    User? user = _auth.currentUser;
    if (user != null) {
      Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      await _db.collection('users').doc(user.uid).update(data);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}