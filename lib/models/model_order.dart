import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;          // ID ของเอกสาร (Document ID)
  final String orderId;     // เลขที่ออเดอร์ที่รันเอง (เช่น 0001)
  final String tableNumber; // เลขโต๊ะ
  final List<String> items; // รายการอาหาร (เก็บเป็นชื่อ)
  final double totalPrice;  // ราคารวม
  final String status;      // สถานะ (pending, cooking, served, completed, cancelled)
  final DateTime? timestamp;// เวลาที่สั่ง

  OrderModel({
    required this.id,
    required this.orderId,
    required this.tableNumber,
    required this.items,
    required this.totalPrice,
    required this.status,
    this.timestamp,
  });

  // Factory สำหรับสร้าง Object จากข้อมูลใน Firestore
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return OrderModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      tableNumber: data['tableNumber'] ?? '',
      // แปลงข้อมูล List<dynamic> เป็น List<String>
      items: List<String>.from(data['items'] ?? []),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      // แปลง Timestamp เป็น DateTime
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : null,
    );
  }

  // แปลง Object กลับเป็น Map (เผื่อต้องใช้ตอนอัปเดต)
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'tableNumber': tableNumber,
      'items': items,
      'totalPrice': totalPrice,
      'status': status,
      'timestamp': timestamp,
    };
  }
}