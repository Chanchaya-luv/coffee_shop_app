import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintBillScreen extends StatelessWidget {
  final String orderId;
  const PrintBillScreen({super.key, required this.orderId});

  Future<void> _printBill(Map<String, dynamic> data) async {
    await initializeDateFormatting('th', null);
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();
    final doc = pw.Document();

    String displayId = data['orderId'] ?? '-';
    String tableNo = data['tableNumber'] ?? '-';
    Timestamp? ts = data['timestamp'];
    String dateStr = ts != null ? DateFormat('d MMM yy, HH:mm', 'th').format(ts.toDate()) : '-';
    
    double totalPrice = (data['totalPrice'] ?? 0).toDouble(); // ยอดสุทธิ
    double discount = (data['discount'] ?? 0).toDouble();     // ส่วนลด
    double originalPrice = totalPrice + discount;            // ราคาก่อนลด

    List<dynamic> rawItems = data['items'] ?? [];
    Map<String, int> itemCounts = {};
    for (var item in rawItems) { itemCounts[item] = (itemCounts[item] ?? 0) + 1; }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text("Caffy Coffee", style: pw.TextStyle(font: fontBold, fontSize: 24))),
              pw.Center(child: pw.Text("ใบเสร็จรับเงิน", style: pw.TextStyle(font: font, fontSize: 14))),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Order: #$displayId", style: pw.TextStyle(font: font, fontSize: 12)), pw.Text("Table: $tableNo", style: pw.TextStyle(font: font, fontSize: 12))]),
              pw.Text("Date: $dateStr", style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Divider(),
              pw.Row(children: [pw.Expanded(flex: 3, child: pw.Text("รายการ", style: pw.TextStyle(font: fontBold, fontSize: 12))), pw.Expanded(flex: 1, child: pw.Text("จน.", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 12))), pw.Expanded(flex: 1, child: pw.Text("รวม", textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 12)))]),
              pw.SizedBox(height: 5),
              ...itemCounts.entries.map((entry) {
                return pw.Row(children: [pw.Expanded(flex: 3, child: pw.Text(entry.key, style: pw.TextStyle(font: font, fontSize: 12))), pw.Expanded(flex: 1, child: pw.Text("x${entry.value}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 12))), pw.Expanded(flex: 1, child: pw.Text("-", textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 12)))]);
              }).toList(),
              pw.Divider(),
              
              // --- 🔥 แสดงยอดเงินและส่วนลดใน PDF ---
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("ยอดรวม", style: pw.TextStyle(font: font, fontSize: 12)), pw.Text("${originalPrice.toStringAsFixed(0)}", style: pw.TextStyle(font: font, fontSize: 12))]),
              if (discount > 0)
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("ส่วนลด", style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.red)), pw.Text("-${discount.toStringAsFixed(0)}", style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.red))]),
              
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("ยอดสุทธิ", style: pw.TextStyle(font: fontBold, fontSize: 16)), pw.Text("฿${totalPrice.toStringAsFixed(0)}", style: pw.TextStyle(font: fontBold, fontSize: 16))]),
              
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("ขอบคุณที่ใช้บริการ", style: pw.TextStyle(font: font, fontSize: 12))),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(title: const Text("Print Bill", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("ไม่พบข้อมูลออเดอร์"));

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String displayId = data['orderId'] ?? '-';
          String tableNo = data['tableNumber'] ?? '-';
          Timestamp? ts = data['timestamp'];
          String dateStr = ts != null ? DateFormat('d/MM/yyyy HH:mm').format(ts.toDate()) : '-';
          
          double totalPrice = (data['totalPrice'] ?? 0).toDouble();
          double discount = (data['discount'] ?? 0).toDouble();
          double originalPrice = totalPrice + discount;

          List<dynamic> rawItems = data['items'] ?? [];
          Map<String, int> itemCounts = {};
          for (var item in rawItems) { itemCounts[item] = (itemCounts[item] ?? 0) + 1; }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 50, color: Color(0xFF6F4E37)),
                      const SizedBox(height: 10),
                      Text("Caffy Coffee", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6F4E37))),
                      const Divider(),
                      Text("Order #$displayId - $tableNo"),
                      Text(dateStr, style: const TextStyle(color: Colors.grey)),
                      const Divider(),
                      ...itemCounts.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${e.key} x${e.value}"),]))).toList(),
                      const Divider(),
                      
                      // --- 🔥 แสดงยอดบนหน้าจอ Preview ---
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ยอดรวม"), Text("฿${originalPrice.toStringAsFixed(0)}")]),
                      if (discount > 0)
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ส่วนลด", style: TextStyle(color: Colors.red)), Text("-฿${discount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red))]),
                      const SizedBox(height: 5),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ยอดสุทธิ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5D4037)))]),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: () => _printBill(data), icon: const Icon(Icons.print), label: const Text("สั่งพิมพ์ใบเสร็จ (PDF)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))
              ],
            ),
          );
        },
      ),
    );
  }
}