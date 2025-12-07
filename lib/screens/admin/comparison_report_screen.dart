import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// --- เพิ่ม Import สำหรับ PDF ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/date_symbol_data_local.dart';

class ComparisonReportScreen extends StatefulWidget {
  const ComparisonReportScreen({super.key});

  @override
  State<ComparisonReportScreen> createState() => _ComparisonReportScreenState();
}

class _ComparisonReportScreenState extends State<ComparisonReportScreen> {
  // ปีปัจจุบันและปีก่อนหน้า (พ.ศ. = ค.ศ. + 543)
  int _year1 = DateTime.now().year - 1; // ปีเก่า (เช่น 2024)
  int _year2 = DateTime.now().year;     // ปีใหม่ (เช่น 2025)

  // --- ฟังก์ชันสร้าง PDF รายงานเปรียบเทียบ ---
  Future<void> _printReport({
    required Map<int, double> dataYear1,
    required Map<int, double> dataYear2,
    required double totalYear1,
    required double totalYear2,
  }) async {
    await initializeDateFormatting('th', null);
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    final doc = pw.Document();
    final String printDate = DateFormat('d MMMM yyyy HH:mm', 'th').format(DateTime.now());
    final months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];

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
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text("รายงานเปรียบเทียบยอดขายรายปี", style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.brown800)),
                        pw.Text("Caffy Coffee System", style: pw.TextStyle(font: font, fontSize: 14)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Text("พิมพ์เมื่อ: $printDate", style: pw.TextStyle(font: font, fontSize: 10)),
                    ]),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              pw.Text("การเปรียบเทียบ: ปี พ.ศ. ${_year1 + 543} vs ${_year2 + 543}", style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.SizedBox(height: 10),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStatBox("ยอดรวมปี ${_year1 + 543}", totalYear1, font, fontBold, PdfColors.grey700),
                    _buildPdfStatBox("ยอดรวมปี ${_year2 + 543}", totalYear2, font, fontBold, PdfColors.green800),
                    pw.Column(children: [
                        pw.Text("ส่วนต่าง (Growth)", style: pw.TextStyle(font: font, fontSize: 12)),
                        pw.Text(
                          "${totalYear2 >= totalYear1 ? '+' : ''}${NumberFormat('#,##0').format(totalYear2 - totalYear1)}", 
                          style: pw.TextStyle(font: fontBold, fontSize: 18, color: totalYear2 >= totalYear1 ? PdfColors.green : PdfColors.red)
                        ),
                    ]),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Text("ตารางเปรียบเทียบรายเดือน", style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 10),

              // Table
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown),
                cellStyle: pw.TextStyle(font: font, fontSize: 12),
                cellAlignment: pw.Alignment.centerRight,
                data: <List<String>>[
                  <String>['เดือน', 'ปี ${_year1 + 543}', 'ปี ${_year2 + 543}', 'ผลต่าง'],
                  ...List.generate(12, (index) {
                    double v1 = dataYear1[index + 1] ?? 0;
                    double v2 = dataYear2[index + 1] ?? 0;
                    double diff = v2 - v1;
                    return [
                      months[index],
                      NumberFormat('#,##0').format(v1),
                      NumberFormat('#,##0').format(v2),
                      "${diff > 0 ? '+' : ''}${NumberFormat('#,##0').format(diff)}",
                    ];
                  }),
                ],
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // เดือนกว้างหน่อย
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildPdfStatBox(String title, double value, pw.Font font, pw.Font fontBold, PdfColor color) {
    return pw.Column(children: [
      pw.Text(title, style: pw.TextStyle(font: font, fontSize: 12)),
      pw.Text(
        NumberFormat('#,##0').format(value), 
        style: pw.TextStyle(font: fontBold, fontSize: 18, color: color)
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("เปรียบเทียบยอดขาย", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. ส่วนเลือกปี ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildYearSelector("ปีหลัก", _year1, Colors.grey, (val) => setState(() => _year1 = val)),
                const Icon(Icons.compare_arrows, color: Color(0xFF6F4E37)),
                _buildYearSelector("ปีเปรียบเทียบ", _year2, const Color(0xFFA6C48A), (val) => setState(() => _year2 = val)),
              ],
            ),
          ),

          // --- 2. เนื้อหาและการคำนวณ ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                List<DocumentSnapshot> docs = snapshot.data!.docs;

                // ข้อมูลสำหรับกราฟ (เดือน 1-12)
                Map<int, double> dataYear1 = {};
                Map<int, double> dataYear2 = {};
                double totalYear1 = 0;
                double totalYear2 = 0;

                for (var doc in docs) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  if (data['status'] == 'cancelled') continue;
                  if (data['timestamp'] == null) continue;

                  DateTime date = (data['timestamp'] as Timestamp).toDate();
                  double price = 0.0;
                  if (data['totalPrice'] != null) price = double.tryParse(data['totalPrice'].toString()) ?? 0.0;

                  // แยกยอดตามปี
                  if (date.year == _year1) {
                    dataYear1[date.month] = (dataYear1[date.month] ?? 0) + price;
                    totalYear1 += price;
                  } else if (date.year == _year2) {
                    dataYear2[date.month] = (dataYear2[date.month] ?? 0) + price;
                    totalYear2 += price;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // --- กราฟเปรียบเทียบ ---
                      Container(
                        height: 350,
                        padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10, bottom: 20),
                              child: Text("กราฟเปรียบเทียบรายเดือน (บาท)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            Expanded(
                              child: _buildComparisonChart(dataYear1, dataYear2),
                            ),
                            const SizedBox(height: 10),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem("ปี ${_year1 + 543}", Colors.grey),
                                const SizedBox(width: 20),
                                _buildLegendItem("ปี ${_year2 + 543}", const Color(0xFFA6C48A)),
                              ],
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- สรุปตัวเลข ---
                      Row(
                        children: [
                          Expanded(child: _buildSummaryCard("ยอดรวมปี ${_year1 + 543}", totalYear1, Colors.grey)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildSummaryCard("ยอดรวมปี ${_year2 + 543}", totalYear2, const Color(0xFFA6C48A))),
                        ],
                      ),

                      const SizedBox(height: 10),
                      
                      // ส่วนต่าง (Growth)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: totalYear2 >= totalYear1 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: totalYear2 >= totalYear1 ? Colors.green : Colors.red, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              totalYear2 >= totalYear1 ? Icons.trending_up : Icons.trending_down,
                              color: totalYear2 >= totalYear1 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "ส่วนต่าง: ${totalYear2 >= totalYear1 ? '+' : ''}${NumberFormat('#,##0').format(totalYear2 - totalYear1)} บาท",
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: totalYear2 >= totalYear1 ? Colors.green[800] : Colors.red[800]
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- 🔥 ปุ่มพิมพ์รายงาน PDF ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () => _printReport(
                            dataYear1: dataYear1,
                            dataYear2: dataYear2,
                            totalYear1: totalYear1,
                            totalYear2: totalYear2,
                          ),
                          icon: const Icon(Icons.print),
                          label: const Text("พิมพ์รายงานเปรียบเทียบ (PDF)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
  }

  // Widget เลือกปี
  Widget _buildYearSelector(String label, int year, Color color, Function(int) onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        DropdownButton<int>(
          value: year,
          underline: Container(height: 2, color: color),
          icon: Icon(Icons.arrow_drop_down, color: color),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          items: List.generate(5, (index) {
            int y = DateTime.now().year - 2 + index; 
            return DropdownMenuItem(value: y, child: Text("พ.ศ. ${y + 543}"));
          }),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ],
    );
  }

  // Widget กราฟเปรียบเทียบ
  Widget _buildComparisonChart(Map<int, double> data1, Map<int, double> data2) {
    double max1 = data1.isNotEmpty ? data1.values.reduce((curr, next) => curr > next ? curr : next) : 0;
    double max2 = data2.isNotEmpty ? data2.values.reduce((curr, next) => curr > next ? curr : next) : 0;
    double maxY = (max1 > max2 ? max1 : max2) * 1.2;
    if (maxY == 0) maxY = 500;

    List<FlSpot> spots1 = [];
    List<FlSpot> spots2 = [];
    for (int i = 1; i <= 12; i++) {
      spots1.add(FlSpot(i.toDouble(), data1[i] ?? 0));
      spots2.add(FlSpot(i.toDouble(), data2[i] ?? 0));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
                int index = value.toInt() - 1;
                if (index >= 0 && index < 12) {
                  if (index % 2 == 0) {
                    return SideTitleWidget(axisSide: meta.axisSide, child: Text(months[index], style: const TextStyle(fontSize: 10, color: Colors.grey)));
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1, maxX: 12, minY: 0, maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots1,
            isCurved: true,
            color: Colors.grey.withOpacity(0.5),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: spots2,
            isCurved: true,
            color: const Color(0xFFA6C48A),
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xFFA6C48A).withOpacity(0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final isYear2 = barSpot.barIndex == 1;
                return LineTooltipItem(
                  '${isYear2 ? "ปี $_year2" : "ปี $_year1"}\n฿${barSpot.y.toInt()}',
                  TextStyle(
                    color: isYear2 ? const Color(0xFFA6C48A) : Colors.grey, 
                    fontWeight: FontWeight.bold
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Text("฿${NumberFormat('#,##0').format(value)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}