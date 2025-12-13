import 'package:cloud_firestore/cloud_firestore.dart';

class StockLog {
  final String id;
  final String ingredientName;
  final double changeAmount; // เช่น +100 หรือ -20
  final double remainingStock; // เหลือเท่าไหร่หลังแก้
  final String reason; // เช่น "เติมสต๊อก", "Order #001"
  final DateTime timestamp;

  StockLog({
    required this.id,
    required this.ingredientName,
    required this.changeAmount,
    required this.remainingStock,
    required this.reason,
    required this.timestamp,
  });

  factory StockLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StockLog(
      id: doc.id,
      ingredientName: data['ingredientName'] ?? 'Unknown',
      changeAmount: (data['changeAmount'] ?? 0).toDouble(),
      remainingStock: (data['remainingStock'] ?? 0).toDouble(),
      reason: data['reason'] ?? '-',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}