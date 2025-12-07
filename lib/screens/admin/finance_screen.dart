import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- เพิ่ม Import สำหรับ PDF ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<void> _initializeLocaleFuture;

  @override
  void initState() {
    super.initState();
    _initializeLocaleFuture = initializeDateFormatting('th', null);
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6F4E37)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- ฟังก์ชันสร้าง PDF รายงานการเงิน ---
  Future<void> _printFinanceReport({
    required DateTime date,
    required double totalSales,
    required double cashSales,
    required double qrSales,
    required int totalOrders,
    required List<DocumentSnapshot> transactions,
  }) async {
    await initializeDateFormatting('th', null);
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    final doc = pw.Document();
    
    final String printDate = DateFormat('d MMMM yyyy HH:mm', 'th').format(DateTime.now());
    final String reportDate = DateFormat('d MMMM yyyy', 'th').format(date);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("รายงานสรุปการเงิน - Caffy Coffee", style: pw.TextStyle(font: fontBold, fontSize: 18)),
                    pw.Text("พิมพ์เมื่อ: $printDate", style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              pw.Text("ประจำวันที่: $reportDate", style: pw.TextStyle(font: font, fontSize: 14)),
              pw.Divider(),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfSummaryItem("ยอดขายรวม", totalSales, font, fontBold, PdfColors.black),
                    _buildPdfSummaryItem("เงินสด (Cash)", cashSales, font, fontBold, PdfColors.green800),
                    _buildPdfSummaryItem("QR Payment", qrSales, font, fontBold, PdfColors.blue800),
                    pw.Column(children: [
                        pw.Text("จำนวนรายการ", style: pw.TextStyle(font: font, fontSize: 12)),
                        pw.Text("$totalOrders", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                    ]),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Text("รายการเดินบัญชี (Transactions)", style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 10),

              // Table
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(60), // เวลา
                  1: const pw.FlexColumnWidth(),   // Order ID
                  2: const pw.FixedColumnWidth(80), // วิธีจ่าย
                  3: const pw.FixedColumnWidth(80), // ยอดเงิน
                },
                data: <List<String>>[
                  <String>['เวลา', 'Order ID', 'ช่องทาง', 'ยอดเงิน (บาท)'],
                  ...transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = (data['timestamp'] as Timestamp).toDate();
                    final timeStr = DateFormat('HH:mm').format(ts);
                    final orderId = data['orderId'] ?? '-';
                    final method = data['paymentMethod'] ?? 'Cash';
                    final price = (data['totalPrice'] ?? 0).toDouble();
                    
                    return [
                      timeStr,
                      "#$orderId",
                      method == 'QR' ? 'QR Payment' : 'เงินสด',
                      NumberFormat('#,##0').format(price),
                    ];
                  }).toList(),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text("ผู้ตรวจสอบ: ____________________", style: pw.TextStyle(font: font, fontSize: 12)),
                ]
              )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildPdfSummaryItem(String title, double value, pw.Font font, pw.Font fontBold, PdfColor color) {
    return pw.Column(children: [
      pw.Text(title, style: pw.TextStyle(font: font, fontSize: 12)),
      pw.Text(
        NumberFormat('#,##0.00').format(value), 
        style: pw.TextStyle(font: fontBold, fontSize: 16, color: color)
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeLocaleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9F9F9),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        String dateLabel = DateFormat('d MMMM yyyy', 'th').format(_selectedDate);
        DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            title: const Text("สรุปการเงิน (Finance)", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF6F4E37),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              // --- ส่วนหัวเลือกวันที่ ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4E37),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _pickDate(context),
                      icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF6F4E37)),
                      label: const Text("เลือกวัน", style: TextStyle(color: Color(0xFF6F4E37), fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  ],
                ),
              ),

              // --- เนื้อหาข้อมูล ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("ไม่มีข้อมูล"));
                    }

                    // 1. กรองข้อมูล
                    var docs = snapshot.data!.docs.where((doc) {
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                      if (data['timestamp'] == null) return false;
                      if (data['status'] == 'cancelled') return false;
                      
                      DateTime ts = (data['timestamp'] as Timestamp).toDate();
                      return ts.isAfter(startOfDay) && ts.isBefore(endOfDay);
                    }).toList();

                    // 2. เรียงลำดับ (ใหม่ -> เก่า)
                    docs.sort((a, b) {
                      Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
                      Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
                      Timestamp timeA = dataA['timestamp'] ?? Timestamp.now();
                      Timestamp timeB = dataB['timestamp'] ?? Timestamp.now();
                      return timeB.compareTo(timeA);
                    });

                    // 3. คำนวณยอดเงิน
                    double totalSales = 0;
                    double cashSales = 0;
                    double qrSales = 0;
                    int cashCount = 0;
                    int qrCount = 0;

                    for (var doc in docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      double price = (data['totalPrice'] ?? 0).toDouble();
                      String method = data['paymentMethod'] ?? 'Cash';

                      totalSales += price;
                      if (method == 'QR') {
                        qrSales += price;
                        qrCount++;
                      } else {
                        cashSales += price;
                        cashCount++;
                      }
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTotalCard(totalSales, docs.length),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildMethodCard("เงินสด (Cash)", cashSales, cashCount, Icons.payments, Colors.green)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildMethodCard("QR Payment", qrSales, qrCount, Icons.qr_code_2, Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Align(alignment: Alignment.centerLeft, child: Text("รายการเดินบัญชี (ล่าสุด)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))),
                          const SizedBox(height: 10),

                          if (docs.isEmpty) 
                            const Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีรายการขายในวันนี้", style: TextStyle(color: Colors.grey)))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var doc = docs[index]; 
                                var data = doc.data() as Map<String, dynamic>;
                                String timeStr = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
                                String method = data['paymentMethod'] ?? 'Cash';
                                double price = (data['totalPrice'] ?? 0).toDouble();
                                String orderId = data['orderId'] ?? '-';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: method == 'QR' ? Colors.blue[50] : Colors.green[50],
                                      child: Icon(method == 'QR' ? Icons.qr_code : Icons.money, color: method == 'QR' ? Colors.blue : Colors.green, size: 20),
                                    ),
                                    title: Text("Order #$orderId", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("เวลา: $timeStr"),
                                    trailing: Text("+${price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037))),
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 30),
                          
                          // --- 🔥 ปุ่มพิมพ์รายงาน PDF ---
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _printFinanceReport(
                                  date: _selectedDate,
                                  totalSales: totalSales,
                                  cashSales: cashSales,
                                  qrSales: qrSales,
                                  totalOrders: docs.length,
                                  transactions: docs, // ส่งรายการไปพิมพ์
                                );
                              },
                              icon: const Icon(Icons.print),
                              label: const Text("พิมพ์รายงานสรุป (PDF)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6F4E37),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalCard(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6F4E37), Color(0xFF8D6E63)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF6F4E37).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("ยอดขายสุทธิ (Net Sales)", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text("฿${NumberFormat('#,##0.00').format(total)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text("จำนวน $count ออเดอร์", style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildMethodCard(String title, double amount, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 5),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text("฿${NumberFormat('#,##0').format(amount)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text("$count รายการ", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}