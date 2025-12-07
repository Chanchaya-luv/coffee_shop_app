import 'package:flutter/material.dart';
// Import หน้าติดตามสถานะ
import 'customer_tracking_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId, required bool isCustomer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6F4E37), width: 4),
                ),
                child: const Icon(Icons.check, size: 80, color: Color(0xFF6F4E37)),
              ),
              const SizedBox(height: 30),
              const Text("ยืนยันคำสั่งซื้อสำเร็จ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              Text("Order #$orderId", style: const TextStyle(fontSize: 20, color: Colors.grey)),
              
              const SizedBox(height: 50),

              // --- ปุ่มติดตามสถานะ ---
              SizedBox(
                width: 250,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA6C48A), // สีเขียว
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    // ไปหน้าติดตามสถานะ (Customer Tracking)
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => CustomerTrackingScreen(orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.access_time_filled, color: Colors.white),
                  label: const Text("ติดตามสถานะออเดอร์", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}