import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String name;
  final String type; // 'buy_x_get_y', 'time_based', 'flat_percent'
  final bool isActive;
  final Map<String, dynamic> conditions; 
  // ตัวอย่าง conditions:
  // buy_x_get_y -> { 'buy': 2, 'get': 1 }
  // time_based -> { 'start': '14:00', 'end': '16:00', 'percent': 50 }
  // flat_percent -> { 'percent': 10 }

  Promotion({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
    required this.conditions,
  });

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'flat_percent',
      isActive: data['isActive'] ?? true,
      conditions: data['conditions'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'isActive': isActive,
      'conditions': conditions,
    };
  }
}