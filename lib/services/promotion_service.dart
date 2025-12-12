import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_promotion.dart';
import '../providers/cart_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';


class PromotionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ดึงโปรโมชั่นที่เปิดใช้งานอยู่
  Stream<List<Promotion>> getActivePromotions() {
    return _db.collection('promotions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Promotion.fromFirestore(doc)).toList());
  }

  // คำนวณส่วนลด
  double calculateDiscount(Promotion promo, List<CartItem> items, double totalAmount) {
    double discount = 0.0;

    if (promo.type == 'flat_percent') {
      // ลด % ทั้งบิล
      int percent = promo.conditions['percent'] ?? 0;
      discount = totalAmount * (percent / 100);
    } 
    else if (promo.type == 'time_based') {
      // ลด % เฉพาะช่วงเวลา
      String startStr = promo.conditions['start'] ?? '00:00';
      String endStr = promo.conditions['end'] ?? '23:59';
      int percent = promo.conditions['percent'] ?? 0;

      DateTime now = DateTime.now();
      TimeOfDay current = TimeOfDay.fromDateTime(now);
      
      TimeOfDay start = _parseTime(startStr);
      TimeOfDay end = _parseTime(endStr);

      if (_isTimeBetween(current, start, end)) {
        discount = totalAmount * (percent / 100);
      }
    } 
    else if (promo.type == 'buy_x_get_y') {
      // ซื้อ X แถม Y (นับจำนวนแก้วรวม)
      // *Logic อย่างง่าย: ลดราคาของแก้วที่ถูกที่สุด หรือเฉลี่ยราคา
      // ในที่นี้ขอใช้ Logic: ลดราคาเฉลี่ยต่อแก้ว ตามจำนวนสิทธิ์ที่ได้
      int buy = promo.conditions['buy'] ?? 2;
      int get = promo.conditions['get'] ?? 1;
      int setSize = buy + get;

      int totalItems = 0;
      for (var item in items) totalItems += item.quantity;

      if (totalItems >= setSize) {
        int freeItems = (totalItems / setSize).floor() * get;
        // สมมติลดราคาเฉลี่ย (เพื่อให้ง่ายต่อการคำนวณแบบคละเมนู)
        if (totalItems > 0) {
           double avgPrice = totalAmount / totalItems;
           discount = avgPrice * freeItems;
        }
      }
    }

    return discount;
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool _isTimeBetween(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    double nowD = now.hour + now.minute / 60.0;
    double startD = start.hour + start.minute / 60.0;
    double endD = end.hour + end.minute / 60.0;
    return nowD >= startD && nowD <= endD;
  }
}