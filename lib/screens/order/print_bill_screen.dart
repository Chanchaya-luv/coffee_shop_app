import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// 1. เพิ่ม import นี้ เพื่อแก้ Error เรื่องวันที่
import 'package:intl/date_symbol_data_local.dart';

// Import สำหรับทำ PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintBillScreen extends StatelessWidget {
  final String orderId;

  const PrintBillScreen({super.key, required this.orderId});

  // --- ฟังก์ชันสร้าง PDF และสั่งพิมพ์ ---
  Future<void> _printBill(Map<String, dynamic> data) async {
    // 2. เรียกคำสั่งนี้ก่อนเริ่มทำงาน (โหลดข้อมูลวันที่ภาษาไทย)
    await initializeDateFormatting('th', null);

    // 1. โหลดฟอนต์ภาษาไทย (Sarabun) จาก Google Fonts
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    // 2. สร้างเอกสาร PDF
    final doc = pw.Document();

    // เตรียมข้อมูล
    String displayId = data['orderId'] ?? '-';
    String tableNo = data['tableNumber'] ?? '-';
    Timestamp? ts = data['timestamp'];
    
    // ตอนนี้ใช้ 'th' ได้แล้ว ไม่ Error แล้วครับ
    String dateStr = ts != null 
        ? DateFormat('d MMM yy, HH:mm', 'th').format(ts.toDate()) 
        : '-';
    
    double totalPrice = (data['totalPrice'] ?? 0).toDouble();
    List<dynamic> rawItems = data['items'] ?? [];
    
    // จัดกลุ่มรายการอาหาร
    Map<String, int> itemCounts = {};
    for (var item in rawItems) {
      itemCounts[item] = (itemCounts[item] ?? 0) + 1;
    }

    // 3. วาดหน้ากระดาษ (Layout)
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // ขนาดกระดาษใบเสร็จ 80mm
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(child: pw.Text("Caffy Coffee", style: pw.TextStyle(font: fontBold, fontSize: 24))),
              pw.Center(child: pw.Text("ใบเสร็จรับเงิน", style: pw.TextStyle(font: font, fontSize: 14))),
              pw.Divider(),
              
              // Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Order: #$displayId", style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.Text("Table: $tableNo", style: pw.TextStyle(font: font, fontSize: 12)),
                ]
              ),
              pw.Text("Date: $dateStr", style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Divider(),

              // Items Header
              pw.Row(children: [
                pw.Expanded(flex: 3, child: pw.Text("รายการ", style: pw.TextStyle(font: fontBold, fontSize: 12))),
                pw.Expanded(flex: 1, child: pw.Text("จน.", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 12))),
                pw.Expanded(flex: 1, child: pw.Text("รวม", textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 12))),
              ]),
              pw.SizedBox(height: 5),

              // Items List
              ...itemCounts.entries.map((entry) {
                // สมมติราคาเฉลี่ย (เนื่องจาก DB เก็บแต่ยอดรวม)
                double estimatedPrice = (totalPrice / rawItems.length) * entry.value;
                return pw.Row(children: [
                  pw.Expanded(flex: 3, child: pw.Text(entry.key, style: pw.TextStyle(font: font, fontSize: 12))),
                  pw.Expanded(flex: 1, child: pw.Text("x${entry.value}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 12))),
                  pw.Expanded(flex: 1, child: pw.Text(estimatedPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 12))),
                ]);
              }).toList(),

              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("ยอดสุทธิ", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text("฿${totalPrice.toStringAsFixed(0)}", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                ]
              ),
              
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("ขอบคุณที่ใช้บริการ", style: pw.TextStyle(font: font, fontSize: 12))),
            ],
          );
        },
      ),
    );

    // 4. สั่งพิมพ์ (จะเด้งหน้า Preview ขึ้นมา)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("Print Bill", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูลออเดอร์"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          // ดึงข้อมูลเพื่อแสดงผลบนหน้าจอ (UI Preview)
          String displayId = data['orderId'] ?? '-';
          String tableNo = data['tableNumber'] ?? '-';
          Timestamp? ts = data['timestamp'];
          String dateStr = ts != null ? DateFormat('d/MM/yyyy HH:mm').format(ts.toDate()) : '-';
          double totalPrice = (data['totalPrice'] ?? 0).toDouble();
          
          List<dynamic> rawItems = data['items'] ?? [];
          Map<String, int> itemCounts = {};
          for (var item in rawItems) {
            itemCounts[item] = (itemCounts[item] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- ส่วนแสดงตัวอย่างบนหน้าจอ (เหมือนเดิม) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 50, color: Color(0xFF6F4E37)),
                      const SizedBox(height: 10),
                      Text("Caffy Coffee", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                      const Divider(),
                      Text("Order #$displayId - $tableNo"),
                      Text(dateStr, style: const TextStyle(color: Colors.grey)),
                      const Divider(),
                      ...itemCounts.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${e.key} x${e.value}"),
                            // Text("ราคา..."), // ถ้าจะโชว์ราคาต่อหน่วยต้องคำนวณ
                          ],
                        ),
                      )).toList(),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("ยอดสุทธิ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5D4037))),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // --- ปุ่มสั่งพิมพ์ ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // เรียกฟังก์ชันสร้าง PDF และสั่งพิมพ์
                      _printBill(data);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text("สั่งพิมพ์ใบเสร็จ (PDF)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4E37),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}