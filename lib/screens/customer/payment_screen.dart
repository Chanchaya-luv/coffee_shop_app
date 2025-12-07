import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../models/model_menu.dart';
import 'order_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String paymentMethod;
  final String tableNumber;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.tableNumber,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  final GlobalKey _qrKey = GlobalKey();
  
  // --- 🔥 ตัวแปรสำหรับคำนวณเงินทอน ---
  final TextEditingController _cashCtrl = TextEditingController();
  double _change = 0.0; // เงินทอน

  @override
  void initState() {
    super.initState();
    // ดักฟังการพิมพ์เพื่อคำนวณเงินทอนทันที
    _cashCtrl.addListener(() {
      double cash = double.tryParse(_cashCtrl.text) ?? 0.0;
      setState(() {
        _change = cash - widget.amount;
      });
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _adminConfirmPayment() async {
    // เช็คว่าจ่ายครบหรือยัง (เฉพาะเงินสด)
    if (widget.paymentMethod == 'Cash') {
      double cash = double.tryParse(_cashCtrl.text) ?? 0.0;
      if (cash < widget.amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("รับเงินมาไม่ครบตามจำนวน"), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    try {
      List<MenuItem> orderItems = [];
      cart.items.forEach((key, value) {
        for (int i = 0; i < value.quantity; i++) {
          orderItems.add(value.menu);
        }
      });

      String newOrderId = await OrderService().placeOrder(
  orderItems,
  widget.tableNumber,
  widget.paymentMethod,
  widget.amount.toString(),   // ← แปลงเป็น String
);


      cart.clearCart();
      cart.setActiveOrder(newOrderId);

      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => OrderSuccessScreen(
      orderId: newOrderId,
      isCustomer: false, // 👈 เพิ่มตรงนี้ (หรือ true แล้วแต่การใช้งาน)
    ),
  ),
);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveQrImage() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "caffy_payment_qr_${DateTime.now().millisecondsSinceEpoch}"
      );

      if (!mounted) return;
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("บันทึก QR Code ลงอัลบั้มแล้ว ✅"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกไม่สำเร็จ"), backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่สามารถบันทึกได้ (ตรวจสอบสิทธิ์การเข้าถึงรูปภาพ)"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isQR = widget.paymentMethod == 'QR';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ชำระเงิน", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView( // ใช้ ScrollView เผื่อคีย์บอร์ดบัง
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              isQR ? "สแกน QR เพื่อจ่าย" : "ชำระด้วยเงินสด",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  if (isQR) ...[
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('metadata').doc('shop_settings').snapshots(),
                          builder: (context, snapshot) {
                            String bankName = "พร้อมเพย์ (PromptPay)";
                            String accNo = "081-234-5678";
                            String accName = "";

                            if (snapshot.hasData && snapshot.data!.exists) {
                              var data = snapshot.data!.data() as Map<String, dynamic>;
                              bankName = data['bankName'] ?? bankName;
                              accNo = data['accountNumber'] ?? accNo;
                              accName = data['accountName'] ?? accName;
                            }

                            return Column(
                              children: [
                                const Icon(Icons.qr_code_2, size: 200, color: Colors.black),
                                const SizedBox(height: 10),
                                Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 5),
                                Text(accNo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                                if (accName.isNotEmpty)
                                  Text(accName, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saveQrImage, 
                      icon: const Icon(Icons.save_alt, color: Color(0xFF5D4037)),
                      label: const Text("บันทึก QR ลงเครื่อง", style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    // --- 🔥 ส่วนรับเงินสด (Cash) ---
                    const Icon(Icons.payments, size: 80, color: Colors.green),
                    const SizedBox(height: 20),
                    
                    // ช่องกรอกเงินที่รับมา
                    TextField(
                      controller: _cashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                      decoration: InputDecoration(
                        labelText: "รับเงินมา (บาท)",
                        hintText: "0.00",
                        prefixText: "฿ ",
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // แสดงเงินทอน
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("เงินทอน", style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text(
                          "฿${_change > 0 ? _change.toStringAsFixed(2) : '0.00'}", 
                          style: TextStyle(
                            fontSize: 28, 
                            fontWeight: FontWeight.bold, 
                            color: _change >= 0 ? Colors.green : Colors.red
                          )
                        ),
                      ],
                    ),
                  ],
                  
                  const Divider(height: 30),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ยอดชำระ", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      Text(
                        "฿${widget.amount.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA6C48A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _adminConfirmPayment,
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ยืนยันการชำระเงิน", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}