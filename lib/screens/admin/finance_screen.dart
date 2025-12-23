import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import สำหรับ PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

// --- 🔥 เพิ่ม Import หน้าบันทึกรายจ่าย ---
import 'expense_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<void> _initializeLocaleFuture;
  bool _isProcessing = false;

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

  // --- ฟังก์ชันสร้าง PDF (Bytes) ---
  Future<Uint8List> _generatePdfBytes({
    required DateTime date, required double totalSales, required double totalDiscount, required double totalExpenses, required double netProfit, required double cashSales, required double qrSales, required int totalOrders, required List<DocumentSnapshot> transactions,
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
                    _buildPdfSummaryItem("ยอดขายสุทธิ", totalSales, font, fontBold, PdfColors.black),
                    _buildPdfSummaryItem("ส่วนลดที่ให้", totalDiscount, font, fontBold, PdfColors.red800),
                    _buildPdfSummaryItem("เงินสด", cashSales, font, fontBold, PdfColors.green800),
                    _buildPdfSummaryItem("QR Payment", qrSales, font, fontBold, PdfColors.blue800),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("รายการเดินบัญชี (Transactions)", style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(50), 
                  1: const pw.FlexColumnWidth(),   
                  2: const pw.FixedColumnWidth(70), 
                  3: const pw.FixedColumnWidth(60), 
                  4: const pw.FixedColumnWidth(70), 
                },
                data: <List<String>>[
                  <String>['เวลา', 'Order ID', 'ช่องทาง', 'ส่วนลด', 'ยอดสุทธิ'],
                  ...transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = (data['timestamp'] as Timestamp).toDate();
                    return [DateFormat('HH:mm').format(ts), "#${data['orderId'] ?? '-'}", data['paymentMethod'] == 'QR' ? 'QR' : 'เงินสด', (data['discount'] ?? 0) > 0 ? "-${NumberFormat('#,##0').format(data['discount'])}" : "-", NumberFormat('#,##0').format(data['totalPrice'] ?? 0)];
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  // --- ฟังก์ชันสั่งพิมพ์ PDF ---
  Future<void> _printFinanceReport({required DateTime date, required double totalSales, required double totalDiscount, required double totalExpenses, required double netProfit, required double cashSales, required double qrSales, required int totalOrders, required List<DocumentSnapshot> transactions}) async {
    final pdfBytes = await _generatePdfBytes(date: date, totalSales: totalSales, totalDiscount: totalDiscount, totalExpenses: totalExpenses, netProfit: netProfit, cashSales: cashSales, qrSales: qrSales, totalOrders: totalOrders, transactions: transactions);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
  }

  // --- 🔥 ฟังก์ชันส่งอีเมล (แบบมีแผนสำรอง) ---
  Future<void> _processAndSendEmail(
      BuildContext context, 
      String email,
      DateTime date,
      double totalSales,
      double totalDiscount,
      double totalExpenses,
      double netProfit,
      double cashSales,
      double qrSales,
      int totalOrders,
      List<DocumentSnapshot> transactions) async {
    
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final box = context.findRenderObject() as RenderBox?;
    final Rect sharePosition = box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;

    try {
      final pdfBytes = await _generatePdfBytes(
        date: date, totalSales: totalSales, totalDiscount: totalDiscount, totalExpenses: totalExpenses, netProfit: netProfit, cashSales: cashSales, qrSales: qrSales, totalOrders: totalOrders, transactions: transactions
      );
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(date);
      final file = File('${directory.path}/report_$dateStr.pdf');
      await file.writeAsBytes(pdfBytes);

      try {
        final Email sendEmail = Email(
          body: 'เรียนเจ้าของร้าน,\n\nแนบไฟล์รายงานสรุปยอดขายประจำวันที่ ${DateFormat('dd/MM/yyyy').format(date)} มาพร้อมกับอีเมลฉบับนี้\n\nขอบคุณครับ\nCaffy Coffee System',
          subject: 'รายงานยอดขาย Caffy Coffee (${DateFormat('dd/MM/yyyy').format(date)})',
          recipients: [email], attachmentPaths: [file.path], isHTML: false,
        );
        await FlutterEmailSender.send(sendEmail);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เปิดแอปอีเมลสำเร็จ กรุณากดส่ง"), backgroundColor: Colors.green));
      } catch (e) {
        await Share.shareXFiles([XFile(file.path)], text: 'รายงานยอดขาย (${DateFormat('dd/MM/yyyy').format(date)})', sharePositionOrigin: sharePosition);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่พบแอปอีเมล -> เปิดเมนูแชร์แทน"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showEmailDialog(BuildContext context, {required DateTime date, required double totalSales, required double totalDiscount, required double totalExpenses, required double netProfit, required double cashSales, required double qrSales, required int totalOrders, required List<DocumentSnapshot> transactions}) async {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ส่งรายงานทางอีเมล"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("กรุณากรอกอีเมลปลายทาง", style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 15), TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "อีเมล", prefixIcon: Icon(Icons.email), border: OutlineInputBorder(), hintText: "example@gmail.com"))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          Builder(builder: (btnContext) {
            return ElevatedButton.icon(onPressed: () { if (emailCtrl.text.isNotEmpty) { Navigator.pop(ctx); _processAndSendEmail(btnContext, emailCtrl.text.trim(), date, totalSales, totalDiscount, totalExpenses, netProfit, cashSales, qrSales, totalOrders, transactions); } }, icon: const Icon(Icons.send), label: const Text("ส่ง"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white));
          }),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String title, double value, pw.Font font, pw.Font fontBold, PdfColor color) {
    return pw.Column(children: [pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10)), pw.Text(NumberFormat('#,##0.00').format(value), style: pw.TextStyle(font: fontBold, fontSize: 14, color: color))]);
  }

  Future<void> _exportCsv({required List<DocumentSnapshot> transactions, required DateTime date}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      String csvContent = "Date,Time,Order ID,Items,Payment Method,Discount,Total Price\n";
      for (var doc in transactions) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime ts = (data['timestamp'] as Timestamp).toDate();
        String dateStr = DateFormat('yyyy-MM-dd').format(ts);
        String timeStr = DateFormat('HH:mm:ss').format(ts);
        String orderId = data['orderId'] ?? '-';
        String method = data['paymentMethod'] ?? 'Cash';
        double price = (data['totalPrice'] ?? 0).toDouble();
        double discount = (data['discount'] ?? 0).toDouble();
        List<dynamic> itemsRaw = data['items'] ?? [];
        String itemsStr = itemsRaw.join(" | ").replaceAll(",", " ");
        csvContent += "$dateStr,$timeStr,$orderId,$itemsStr,$method,$discount,$price\n";
      }
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/sales_report_${DateFormat('yyyyMMdd').format(date)}.csv";
      final file = File(path);
      await file.writeAsString(csvContent);
      await Share.shareXFiles([XFile(path)], text: 'Sales Report for ${DateFormat('dd/MM/yyyy').format(date)}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeLocaleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(backgroundColor: Color(0xFFF9F9F9), body: Center(child: CircularProgressIndicator()));

        String dateLabel = DateFormat('d MMMM yyyy', 'th').format(_selectedDate);
        DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF9F9F9),
              appBar: AppBar(
                title: const Text("สรุปการเงิน (Finance)", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF6F4E37),
                foregroundColor: Colors.white,
                elevation: 0,
                // --- 🔥 เพิ่มปุ่มบันทึกรายจ่าย ---
                actions: [
                  TextButton.icon(
                    onPressed: _isProcessing ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseScreen())).then((_) => setState((){})),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                    label: const Text("บันทึกรายจ่าย", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              body: Column(
                children: [
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF6F4E37), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dateLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), ElevatedButton.icon(onPressed: _isProcessing ? null : () => _pickDate(context), icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF6F4E37)), label: const Text("เลือกวัน", style: TextStyle(color: Color(0xFF6F4E37), fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))))])),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                      builder: (context, orderSnapshot) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
                          builder: (context, expenseSnapshot) {
                            if (!orderSnapshot.hasData || !expenseSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                            var orderDocs = orderSnapshot.data!.docs.where((doc) {
                              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                              if (data['timestamp'] == null || data['status'] == 'cancelled') return false;
                              DateTime ts = (data['timestamp'] as Timestamp).toDate();
                              return ts.isAfter(startOfDay) && ts.isBefore(endOfDay);
                            }).toList();

                            // --- 🔥 แก้ไขการเรียงลำดับ (ล่าสุดขึ้นก่อน) ---
                            orderDocs.sort((a, b) { 
                                Timestamp t1 = (a.data() as Map)['timestamp']; 
                                Timestamp t2 = (b.data() as Map)['timestamp']; 
                                return t2.compareTo(t1); // ใหม่ไปเก่า
                            });

                            double totalSales = 0; double totalDiscount = 0; double cashSales = 0; double qrSales = 0; int cashCount = 0; int qrCount = 0;
                            for (var doc in orderDocs) {
                              var data = doc.data() as Map<String, dynamic>;
                              double price = (data['totalPrice'] ?? 0).toDouble();
                              double discount = (data['discount'] ?? 0).toDouble();
                              String method = data['paymentMethod'] ?? 'Cash';
                              totalSales += price; totalDiscount += discount;
                              if (method == 'QR') { qrSales += price; qrCount++; } else { cashSales += price; cashCount++; }
                            }

                            var expenseDocs = expenseSnapshot.data!.docs.where((doc) {
                              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                              if (data['date'] == null) return false;
                              DateTime ts = (data['date'] as Timestamp).toDate();
                              return ts.isAfter(startOfDay) && ts.isBefore(endOfDay);
                            }).toList();
                            double totalExpenses = 0;
                            for (var doc in expenseDocs) { totalExpenses += (doc['amount'] ?? 0).toDouble(); }

                            double netProfit = totalSales - totalExpenses;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildNetProfitCard(netProfit, totalSales, totalExpenses),
                                  const SizedBox(height: 20),
                                  Row(children: [Expanded(child: _buildMethodCard("เงินสด (Cash)", cashSales, cashCount, Icons.payments, Colors.green)), const SizedBox(width: 15), Expanded(child: _buildMethodCard("QR Payment", qrSales, qrCount, Icons.qr_code_2, Colors.blue))]),
                                  if (totalDiscount > 0) ...[const SizedBox(height: 15), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.discount, color: Colors.red), SizedBox(width: 8), Text("ส่วนลดที่ให้ไปวันนี้", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]), Text("- ฿${NumberFormat('#,##0.00').format(totalDiscount)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]))],
                                  const SizedBox(height: 30),
                                  const Align(alignment: Alignment.centerLeft, child: Text("รายการเดินบัญชี (ล่าสุด)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))),
                                  const SizedBox(height: 10),
                                  
                                  if (orderDocs.isEmpty) 
                                    const Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีรายการขายในวันนี้", style: TextStyle(color: Colors.grey))) 
                                  else 
                                    ListView.builder(
                                      shrinkWrap: true, 
                                      physics: const NeverScrollableScrollPhysics(), 
                                      itemCount: orderDocs.length, 
                                      itemBuilder: (context, index) { 
                                        // --- 🔥 แก้ไข index ให้เรียงถูกต้อง (0 คือตัวแรกของ list ที่เรียงแล้ว) ---
                                        var doc = orderDocs[index];
                                        
                                        var data = doc.data() as Map<String, dynamic>; 
                                        String timeStr = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()); 
                                        String method = data['paymentMethod'] ?? 'Cash'; 
                                        double price = (data['totalPrice'] ?? 0).toDouble(); 
                                        double discount = (data['discount'] ?? 0).toDouble(); 
                                        String orderId = data['orderId'] ?? '-'; 
                                        
                                        return Card(margin: const EdgeInsets.only(bottom: 8), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: method == 'QR' ? Colors.blue[50] : Colors.green[50], child: Icon(method == 'QR' ? Icons.qr_code : Icons.money, color: method == 'QR' ? Colors.blue : Colors.green, size: 20)), title: Text("Order #$orderId", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("เวลา: $timeStr"), if (discount > 0) Text("ส่วนลด: -${NumberFormat('#,##0').format(discount)}", style: const TextStyle(color: Colors.red, fontSize: 12))]), trailing: Text("+${price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037))))); 
                                      }
                                    ),
                                  
                                  const SizedBox(height: 30),
                                  
                                  // ปุ่ม Print, Email, Excel
                                  Row(children: [
                                    Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _printFinanceReport(date: _selectedDate, totalSales: totalSales, totalDiscount: totalDiscount, totalExpenses: totalExpenses, netProfit: netProfit, cashSales: cashSales, qrSales: qrSales, totalOrders: orderDocs.length, transactions: orderDocs), icon: const Icon(Icons.print), label: const Text("PDF", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
                                    const SizedBox(width: 15),
                                    Expanded(child: Builder(builder: (btnContext) { return ElevatedButton.icon(onPressed: _isProcessing ? null : () => _showEmailDialog(btnContext, date: _selectedDate, totalSales: totalSales, totalDiscount: totalDiscount, totalExpenses: totalExpenses, netProfit: netProfit, cashSales: cashSales, qrSales: qrSales, totalOrders: orderDocs.length, transactions: orderDocs), icon: const Icon(Icons.email), label: const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12))); })),
                                    const SizedBox(width: 15),
                                    Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _exportCsv(transactions: orderDocs, date: _selectedDate), icon: const Icon(Icons.file_download), label: const Text("Excel", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
                                  ]),
                                  const SizedBox(height: 50),
                                ],
                              ),
                            );
                          }
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
              if (_isProcessing) Container(color: Colors.black45, child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 20), Text("กำลังดำเนินการ...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]))),
            ],
          );
      },
    );
  }

  Widget _buildNetProfitCard(double netProfit, double sales, double expenses) { return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6F4E37), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF6F4E37).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(children: [const Text("กำไรสุทธิ (Net Profit)", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 5), Text("฿${NumberFormat('#,##0.00').format(netProfit)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)), const SizedBox(height: 15), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Column(children: [const Text("ยอดขาย", style: TextStyle(color: Colors.white70, fontSize: 12)), Text("+${NumberFormat('#,##0').format(sales)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), Container(height: 30, width: 1, color: Colors.white30), Column(children: [const Text("รายจ่าย", style: TextStyle(color: Colors.white70, fontSize: 12)), Text("-${NumberFormat('#,##0').format(expenses)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))])])])); }
  Widget _buildMethodCard(String title, double amount, int count, IconData icon, Color color) { return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 5), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))]), const SizedBox(height: 10), Text("฿${NumberFormat('#,##0').format(amount)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text("$count รายการ", style: TextStyle(fontSize: 12, color: Colors.grey[600]))])); }
}