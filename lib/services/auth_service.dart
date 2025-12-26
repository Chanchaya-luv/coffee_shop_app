import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await _recordLoginLog(user);
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _recordLoginLog(User user) async {
    try {
      var doc = await _db.collection('users').doc(user.uid).get();
      String name = 'Unknown';
      String role = 'staff';

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        name = data['name'] ?? name;
        role = data['role'] ?? role;
      }

      await _db.collection('login_logs').add({
        'uid': user.uid,
        'name': name,
        'email': user.email,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'login',
      });
    } catch (e) {
      print("Error recording login log: $e");
    }
  }

  // ฟังก์ชันสำหรับ Manager/Owner สร้างบัญชีให้พนักงาน (เลือกยศได้)
  Future<void> createEmployee(String email, String password, String name, String role, String photoUrl) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
      UserCredential result = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        await _saveUserToFirestore(result.user!.uid, name, email, photoUrl, role);
      }
      await secondaryApp.delete();
    } catch (e) {
      await secondaryApp?.delete();
      rethrow;
    }
  }

  Future<void> updateEmployeeData(String uid, String name, String role) async {
    await _db.collection('users').doc(uid).update({'name': name, 'role': role});
  }

  Future<void> _saveUserToFirestore(String uid, String name, String email, String photoUrl, String role) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid, 
      'name': name, 
      'email': email, 
      'photoUrl': photoUrl.isEmpty ? 'https://cdn-icons-png.flaticon.com/512/149/149071.png' : photoUrl, 
      'role': role, 
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // --- 🔥 ฟังก์ชันสมัครสมาชิกเอง (Register Screen) ---
  Future<User?> register(String email, String password, String name, String photoUrl) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        // ✅ บังคับให้เป็น 'staff' เสมอ สำหรับการสมัครเอง
        await _saveUserToFirestore(user.uid, name, email, photoUrl, 'staff');
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

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