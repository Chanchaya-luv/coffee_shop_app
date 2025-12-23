import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// Import สำหรับ PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import สำหรับ Export/Email
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import 'comparison_report_screen.dart';

class ReportScreen extends StatefulWidget {
  final bool isFullReport; 

  const ReportScreen({super.key, this.isFullReport = true});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedPeriod = 'Daily';
  late Future<void> _initializeLocaleFuture;
  
  // ตัวแปรคุมสถานะ Loading
  bool _isProcessing = false;
  
  Map<String, String> _menuCategories = {};

  @override
  void initState() {
    super.initState();
    _initializeLocaleFuture = initializeDateFormatting('th', null);
    
    if (widget.isFullReport) {
      _selectedPeriod = 'Weekly'; 
    } else {
      _selectedPeriod = 'Daily';
    }
    
    _fetchMenuData();
  }

  Future<void> _fetchMenuData() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('menu_items').get();
      Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String name = data['name'] ?? '';
        String cat = data['category'] ?? '';
        if (name.isNotEmpty) {
          tempMap[name] = cat;
        }
      }
      if (mounted) {
        setState(() {
          _menuCategories = tempMap;
        });
      }
    } catch (e) {
      print("Error fetching menu data: $e");
    }
  }

  String _cleanMenuName(String fullName) {
    if (fullName.contains(' (')) {
      return fullName.split(' (')[0]; 
    }
    return fullName;
  }

  // --- 🔥 1. ฟังก์ชันสร้าง PDF (Bytes) ---
  Future<Uint8List> _generatePdfBytes({
    required double totalSales,
    required double totalDiscount,
    required int totalCups,
    required int totalOrders,
    required int totalBakery,
    required int totalUpsell,
    required List<MapEntry<String, int>> topMenus,
  }) async {
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();
    final doc = pw.Document();
    final String printDate = DateFormat('d MMMM yyyy HH:mm', 'th').format(DateTime.now());
    
    String periodText = '';
    if (_selectedPeriod == 'Daily') periodText = 'รายวัน (Daily)';
    else if (_selectedPeriod == 'Weekly') periodText = 'รายสัปดาห์ (Weekly)';
    else if (_selectedPeriod == 'Monthly') periodText = 'รายเดือน (Monthly)';
    else periodText = 'รายปี (Yearly)';

    final top3Menus = topMenus.take(3).toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("สรุปยอดขาย - Caffy Coffee", style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.brown800)),
                      pw.Text(widget.isFullReport ? "รายงานภาพรวม ($periodText)" : "รายงานประจำวัน (Today)", style: pw.TextStyle(font: font, fontSize: 14)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text("พิมพ์เมื่อ: $printDate", style: pw.TextStyle(font: font, fontSize: 10)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 20),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                _buildPdfStatBox("ยอดขายสุทธิ", "${NumberFormat('#,##0.00').format(totalSales)} บ.", font, fontBold, PdfColors.green800),
                _buildPdfStatBox("ส่วนลดรวม", "${NumberFormat('#,##0.00').format(totalDiscount)} บ.", font, fontBold, PdfColors.red800),
                _buildPdfStatBox("จำนวนออเดอร์", "$totalOrders บิล", font, fontBold, PdfColors.blue800),
              ]),
              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                _buildPdfStatBox("จำนวนแก้วรวม", "$totalCups แก้ว", font, fontBold, PdfColors.orange800),
                _buildPdfStatBox("เบเกอรี่/เค้ก", "$totalBakery ชิ้น", font, fontBold, PdfColors.brown800),
                _buildPdfStatBox("รับข้อเสนอ (Upsell)", "$totalUpsell ครั้ง", font, fontBold, PdfColors.purple800),
              ]),
              
              pw.SizedBox(height: 30),
              pw.Text("รายละเอียดสินค้าขายดี (Top 3)", style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context, border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown),
                cellStyle: pw.TextStyle(font: font, fontSize: 12),
                data: <List<String>>[
                  <String>['อันดับ', 'ชื่อเมนู', 'จำนวน (แก้ว/ชิ้น)'],
                  ...top3Menus.asMap().entries.map((entry) {
                    return [(entry.key + 1).toString(), entry.value.key, entry.value.value.toString()];
                  }).toList(),
                ],
                columnWidths: {0: const pw.FixedColumnWidth(50), 1: const pw.FlexColumnWidth(), 2: const pw.FixedColumnWidth(100)},
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  pw.Widget _buildPdfStatBox(String title, String value, pw.Font font, pw.Font fontBold, PdfColor color) {
    return pw.Container(
      width: 150, padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5), color: PdfColor(color.red, color.green, color.blue, 0.05)),
      child: pw.Column(children: [pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9)), pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 14, color: color))])
    );
  }

  // --- 🔥 2. ฟังก์ชัน Export CSV ---
  Future<void> _exportCsv({required List<DocumentSnapshot> transactions}) async {
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
      final path = "${directory.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvContent);

      await Share.shareXFiles([XFile(path)], text: 'Sales Report CSV');

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 🔥 3. ฟังก์ชันส่งอีเมล (จำลอง) ---
  Future<void> _processAndSendEmail(
      String email,
      double totalSales,
      double totalDiscount,
      int totalCups,
      int totalOrders,
      int totalBakery,
      int totalUpsell,
      List<MapEntry<String, int>> topMenus
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // สร้างไฟล์ PDF
      final pdfBytes = await _generatePdfBytes(
        totalSales: totalSales, totalDiscount: totalDiscount, totalCups: totalCups, 
        totalOrders: totalOrders, totalBakery: totalBakery, totalUpsell: totalUpsell, topMenus: topMenus
      );
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/report_email.pdf');
      await file.writeAsBytes(pdfBytes);

      // จำลองการส่ง
      await Future.delayed(const Duration(seconds: 2));

      // ลองเปิดแอปอีเมล (ถ้ามี) หรือ Share Sheet
      try {
        final Email sendEmail = Email(
          body: 'เรียนเจ้าของร้าน,\n\nแนบไฟล์รายงานสรุปยอดขายมาพร้อมกับอีเมลฉบับนี้\n\nขอบคุณครับ',
          subject: 'รายงานยอดขาย Caffy Coffee',
          recipients: [email],
          attachmentPaths: [file.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(sendEmail);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เปิดแอปอีเมลสำเร็จ"), backgroundColor: Colors.green));
      } catch (e) {
        // Fallback: Share Sheet
         await Share.shareXFiles([XFile(file.path)], text: 'รายงานยอดขาย PDF');
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่พบแอปอีเมล -> เปิดเมนูแชร์แทน"), backgroundColor: Colors.orange));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Dialog กรอกอีเมล
  Future<void> _showEmailDialog(
      BuildContext context,
      double totalSales,
      double totalDiscount,
      int totalCups,
      int totalOrders,
      int totalBakery,
      int totalUpsell,
      List<MapEntry<String, int>> topMenus
  ) async {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ส่งรายงานทางอีเมล"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("กรุณากรอกอีเมลปลายทาง", style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 15), TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "อีเมล", prefixIcon: Icon(Icons.email), border: OutlineInputBorder(), hintText: "example@gmail.com"))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton.icon(
            onPressed: () {
              if (emailCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _processAndSendEmail(emailCtrl.text.trim(), totalSales, totalDiscount, totalCups, totalOrders, totalBakery, totalUpsell, topMenus);
              }
            },
            icon: const Icon(Icons.send), label: const Text("ส่ง"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันพิมพ์ปกติ
  Future<void> _printReport({
    required double totalSales, required double totalDiscount, required int totalCups, required int totalOrders, required int totalBakery, required int totalUpsell, required List<MapEntry<String, int>> topMenus,
  }) async {
    final pdfBytes = await _generatePdfBytes(totalSales: totalSales, totalDiscount: totalDiscount, totalCups: totalCups, totalOrders: totalOrders, totalBakery: totalBakery, totalUpsell: totalUpsell, topMenus: topMenus);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeLocaleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(backgroundColor: Color(0xFFF9F9F9), body: Center(child: CircularProgressIndicator()));

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF9F9F9),
              appBar: AppBar(
                title: Text(widget.isFullReport ? "สรุปยอดขาย (ภาพรวม)" : "ยอดขายวันนี้ (Today)", style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF6F4E37),
                foregroundColor: Colors.white,
                centerTitle: true,
                actions: [
                  if (widget.isFullReport)
                    IconButton(
                      icon: const Icon(Icons.compare_arrows),
                      tooltip: "เปรียบเทียบยอดขายรายปี",
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ComparisonReportScreen())),
                    ),
                ],
              ),
              body: Column(
                children: [
                  if (widget.isFullReport)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          _buildPeriodTab('Weekly', 'รายสัปดาห์'),
                          _buildPeriodTab('Monthly', 'รายเดือน'),
                          _buildPeriodTab('Yearly', 'รายปี'),
                        ],
                      ),
                    ),
                  
                  if (!widget.isFullReport) const SizedBox(height: 20),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        List<DocumentSnapshot> docs = snapshot.hasData ? snapshot.data!.docs : [];
                        List<DocumentSnapshot> filteredDocs = _filterDocsByPeriod(docs);

                        double totalSales = 0;
                        double totalDiscount = 0;
                        int totalCups = 0;
                        int totalOrders = 0;
                        int totalBakery = 0; 
                        int totalUpsell = 0; 
                        
                        Map<String, int> menuPopularity = {};
                        Map<int, double> chartData = {};

                        for (var doc in filteredDocs) {
                          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                          if (data['status'] != 'cancelled') {
                            double price = (data['totalPrice'] ?? 0).toDouble();
                            double discount = (data['discount'] ?? 0).toDouble();
                            
                            totalSales += price;
                            totalDiscount += discount;
                            totalOrders += 1;
                            
                            List<dynamic> items = data['items'] ?? [];
                            totalCups += items.length;

                            for (var item in items) {
                              String fullName = item.toString();
                              String cleanName = _cleanMenuName(fullName);
                              menuPopularity[cleanName] = (menuPopularity[cleanName] ?? 0) + 1;

                              String category = _menuCategories[cleanName] ?? '';
                              if (['เบเกอรี่', 'เค้ก', 'ขนม', 'ของหวาน'].contains(category)) {
                                totalBakery++;
                              }

                              if (fullName.contains('(Pro 20%)')) {
                                totalUpsell++;
                              }
                            }

                            Timestamp? ts = data['timestamp'];
                            if (ts != null) {
                              DateTime date = ts.toDate();
                              int key;
                              if (_selectedPeriod == 'Daily') key = date.hour;
                              else if (_selectedPeriod == 'Weekly') key = date.weekday;
                              else if (_selectedPeriod == 'Monthly') key = date.day;
                              else key = date.month;
                              chartData[key] = (chartData[key] ?? 0) + price;
                            }
                          }
                        }
                        var sortedMenu = menuPopularity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                height: 350, 
                                padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(padding: const EdgeInsets.only(left: 10, bottom: 20), child: Text(_getChartTitle(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16))),
                                    Expanded(child: _buildLineChart(chartData)),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(child: _buildSummaryCard("ยอดขายสุทธิ", "฿${NumberFormat('#,##0').format(totalSales)}", Icons.monetization_on, Colors.green)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildSummaryCard("ส่วนลดรวม", "-฿${NumberFormat('#,##0').format(totalDiscount)}", Icons.discount, Colors.redAccent)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              
                              Row(
                                children: [
                                  Expanded(child: _buildSummaryCard("จำนวนบิล", "$totalOrders ใบ", Icons.receipt, Colors.blue)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildSummaryCard("เครื่องดื่มรวม", "$totalCups แก้ว", Icons.local_cafe, Colors.orange)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              
                              Row(
                                children: [
                                  Expanded(child: _buildSummaryCard("เบเกอรี่/เค้ก", "$totalBakery ชิ้น", Icons.cake, Colors.brown)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildSummaryCard("รับสิทธิ์แลกซื้อ", "$totalUpsell สิทธิ์", Icons.thumb_up, Colors.purple)),
                                ],
                              ),
                              
                              const SizedBox(height: 30),
                              const Text("3 อันดับเมนูขายดี", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                              const SizedBox(height: 15),

                              if (sortedMenu.isEmpty)
                                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีรายการขายในช่วงนี้", style: TextStyle(color: Colors.grey))))
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: sortedMenu.length > 3 ? 3 : sortedMenu.length,
                                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    var entry = sortedMenu[index];
                                    double percent = (totalCups > 0) ? (entry.value / totalCups) : 0;
                                    return _buildTopMenuCard(index, entry.key, entry.value, percent);
                                  },
                                ),
                              
                              const SizedBox(height: 30),

                              // --- 🔥 ปุ่ม Action 3 ปุ่ม ---
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : () => _printReport(totalSales: totalSales, totalDiscount: totalDiscount, totalCups: totalCups, totalOrders: totalOrders, totalBakery: totalBakery, totalUpsell: totalUpsell, topMenus: sortedMenu),
                                      icon: const Icon(Icons.print),
                                      label: const Text("PDF", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : () => _showEmailDialog(context, totalSales, totalDiscount, totalCups, totalOrders, totalBakery, totalUpsell, sortedMenu),
                                      icon: const Icon(Icons.email),
                                      label: const Text("Email", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : () => _exportCsv(transactions: filteredDocs),
                                      icon: const Icon(Icons.file_download),
                                      label: const Text("Excel", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                ],
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
            ),
              
              if (_isProcessing)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text("กำลังดำเนินการ...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
    );
  }


  // (Helper Functions เดิม)
  String _getChartTitle() { if (_selectedPeriod == 'Daily') return "ยอดขายรายชั่วโมง (วันนี้)"; if (_selectedPeriod == 'Weekly') return "ยอดขายรายวัน (สัปดาห์นี้)"; if (_selectedPeriod == 'Monthly') return "ยอดขายรายวัน (เดือนนี้)"; return "ยอดขายรายเดือน (ปีนี้)"; }
  Widget _buildLineChart(Map<int, double> data) { double maxY = 0; if (data.isNotEmpty) maxY = data.values.reduce((curr, next) => curr > next ? curr : next); maxY = maxY == 0 ? 500 : maxY * 1.2; int maxX = (_selectedPeriod == 'Daily') ? 23 : (_selectedPeriod == 'Weekly') ? 7 : (_selectedPeriod == 'Monthly') ? 31 : 12; int startX = (_selectedPeriod == 'Daily') ? 0 : 1; List<FlSpot> spots = []; for (int i = startX; i <= maxX; i++) { spots.add(FlSpot(i.toDouble(), data[i] ?? 0)); } return LineChart(LineChartData(gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)), titlesData: FlTitlesData(show: true, rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _selectedPeriod == 'Yearly' ? 1 : (_selectedPeriod == 'Monthly' ? 5 : (_selectedPeriod == 'Daily' ? 4 : 1)), getTitlesWidget: (value, meta) { String text = ''; int v = value.toInt(); if (_selectedPeriod == 'Weekly') { const days = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา']; if (v >= 1 && v <= 7) text = days[v-1]; } else if (_selectedPeriod == 'Daily') { if (v % 4 == 0) text = '${v.toString().padLeft(2,'0')}:00'; } else if (_selectedPeriod == 'Yearly') { const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']; if (v >= 1 && v <= 12) text = months[v-1]; } else { if (v % 5 == 0 || v == 1) text = '$v'; } return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))); }))), borderData: FlBorderData(show: false), minX: startX.toDouble(), maxX: maxX.toDouble(), minY: 0, maxY: maxY, lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: const Color(0xFFA6C48A), barWidth: 4, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: const Color(0xFFA6C48A).withOpacity(0.2)))])); }
  List<DocumentSnapshot> _filterDocsByPeriod(List<DocumentSnapshot> allDocs) { DateTime now = DateTime.now(); DateTime start; DateTime end; if (_selectedPeriod == 'Daily') { start = DateTime(now.year, now.month, now.day); end = DateTime(now.year, now.month, now.day, 23, 59, 59); } else if (_selectedPeriod == 'Weekly') { start = now.subtract(Duration(days: now.weekday - 1)); start = DateTime(start.year, start.month, start.day); end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1)); } else if (_selectedPeriod == 'Monthly') { start = DateTime(now.year, now.month, 1); end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1)); } else { start = DateTime(now.year, 1, 1); end = DateTime(now.year, 12, 31, 23, 59, 59); } return allDocs.where((doc) { Map<String, dynamic> data = doc.data() as Map<String, dynamic>; if (data['timestamp'] == null) return false; DateTime date = (data['timestamp'] as Timestamp).toDate(); return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1))); }).toList(); }
  Widget _buildPeriodTab(String period, String label) { bool isSelected = _selectedPeriod == period; return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedPeriod = period), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? const Color(0xFF6F4E37) : Colors.transparent, borderRadius: BorderRadius.circular(25)), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))))); }
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) { return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 5), Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis))]), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]))); }
  Widget _buildTopMenuCard(int index, String name, int count, double percent) { return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]), child: Column(children: [Row(children: [if (index == 0) const Text("🥇 ", style: TextStyle(fontSize: 20)), if (index == 1) const Text("🥈 ", style: TextStyle(fontSize: 20)), if (index == 2) const Text("🥉 ", style: TextStyle(fontSize: 20)), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), Text("$count แก้ว", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA6C48A)))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[100], color: const Color(0xFFA6C48A), minHeight: 8))])); }
}