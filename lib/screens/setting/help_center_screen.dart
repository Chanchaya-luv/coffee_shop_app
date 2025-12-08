import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ศูนย์ช่วยเหลือ", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("คำถามที่พบบ่อย (FAQ)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            const SizedBox(height: 15),

            // --- ส่วน FAQ (Expandable) ---
            _buildFAQItem(
              "จะเริ่มขายสินค้าต้องทำอย่างไร?",
              "1. ไปที่หน้าแรก (Home)\n2. เลือกเมนู 'Quick Menu' (สำหรับแอดมิน)\n3. เลือกรายการสินค้าใส่ตะกร้า\n4. กดปุ่ม Checkout ด้านล่างเพื่อชำระเงิน"
            ),
            _buildFAQItem(
              "วิธีเพิ่มเมนูสินค้าใหม่?",
              "1. ไปที่หน้า 'ตั้งค่า' -> 'จัดการเมนู'\n2. กดปุ่ม '+' ด้านล่างขวา\n3. กรอกชื่อ ราคา และใส่รูปภาพ\n4. กดบันทึก"
            ),
            _buildFAQItem(
              "วิธีเพิ่มสต๊อกวัตถุดิบ?",
              "1. ไปที่หน้า 'ตั้งค่า' -> 'การจัดการวัตถุดิบ'\n2. กดปุ่ม '+' เพื่อเพิ่มวัตถุดิบใหม่\n3. หรือกดปุ่ม + สีเขียวหลังรายการเดิมเพื่อเพิ่มจำนวน"
            ),
            _buildFAQItem(
              "ทำไมออเดอร์ถึงไม่ตัดสต๊อก?",
              "ต้องทำการ 'ผูกสูตร' (Recipe) ให้เมนูก่อนครับ โดยเข้าไปแก้ไขเมนูนั้น แล้วเพิ่มรายการวัตถุดิบที่ใช้ลงไป"
            ),
             _buildFAQItem(
              "ลืมรหัสผ่านต้องทำอย่างไร?",
              "ในหน้า Login ให้กดปุ่ม 'ลืมรหัสผ่าน?' แล้วกรอกอีเมล ระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้ทางอีเมล"
            ),

            

            
            
            
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0, // แบบแบนเรียบ
      color: Colors.white,
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        textColor: const Color(0xFF6F4E37),
        iconColor: const Color(0xFF6F4E37),
        children: [
          Text(answer, style: const TextStyle(color: Colors.black87, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildManualCard(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF6F4E37).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF6F4E37)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // เปิดไฟล์ หรือ ลิงก์
        },
      ),
    );
  }
}