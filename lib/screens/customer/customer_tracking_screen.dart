import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String orderId; // รับเลขคิว เช่น "0001"

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  // --- 🔥 เพิ่มตัวแปรเก็บสถานะการขยายรายการ ---
  bool _isExpanded = false; 
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ติดตามสถานะ", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      // Stream 1: ดึงข้อมูลออเดอร์ของตัวเอง
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('orderId', isEqualTo: widget.orderId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text("ไม่พบออเดอร์หมายเลข #$widget.orderId", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 10),
                  const Text("กรุณาติดต่อพนักงาน", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var doc = snapshot.data!.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          
          String status = data['status'] ?? 'pending';
          String displayId = data['orderId'] ?? '-';
          String tableNo = data['tableNumber'] ?? '-';
          Timestamp? myOrderTimestamp = data['timestamp'];
          
          // ดึงรายการสินค้าเพื่อคำนวณจำนวนแก้ว
          List<String> items = [];
          if (data['items'] != null) {
             var raw = data['items'];
             if (raw is List) items = raw.map((e) => e.toString()).toList();
          }
          
          // --- 🔥 จัดกลุ่มรายการ (Grouping) ---
          Map<String, int> groupedItems = {};
          int totalCups = 0;
          for (var item in items) {
            groupedItems[item] = (groupedItems[item] ?? 0) + 1;
            totalCups++;
          }

          var entryList = groupedItems.entries.toList();
          
          double totalPrice = 0.0;
          if (data['totalPrice'] != null) totalPrice = double.tryParse(data['totalPrice'].toString()) ?? 0.0;

          // --- 🔥 Stream 2: ดึงคิวทั้งหมดที่ "รอทำ" หรือ "กำลังทำ" เพื่อคำนวณเวลา ---
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', whereIn: ['pending', 'cooking']) // เอาเฉพาะที่ยังไม่เสร็จ
                .snapshots(),
            builder: (context, queueSnapshot) {
              
              String estimatedTimeStr = "--:--";
              int queueAhead = 0; // จำนวนคิวที่รอก่อนหน้า

              if (queueSnapshot.hasData && myOrderTimestamp != null) {
                // กรองหาออเดอร์ที่มาก่อนเรา (Timestamp น้อยกว่าเรา)
                var ordersAhead = queueSnapshot.data!.docs.where((qDoc) {
                  var qData = qDoc.data() as Map<String, dynamic>;
                  Timestamp? qTs = qData['timestamp'];
                  if (qTs == null) return false;
                  // เช็คว่าเป็นคนละออเดอร์ และ มาก่อนเรา
                  return qDoc.id != doc.id && qTs.compareTo(myOrderTimestamp) < 0;
                }).toList();

                queueAhead = ordersAhead.length;

                // --- 🕒 สูตรคำนวณเวลา (Algorithm) ---
                // 1. เวลาทำของตัวเอง
                int myPrepTime = 0;
                if (totalCups <= 4) {
                  myPrepTime = 10; // 1-4 แก้ว = 10 นาที
                } else {
                  myPrepTime = 15 + ((totalCups - 5) * 2); // 5 แก้วขึ้นไป = 15 นาที + (2 นาทีต่อแก้วที่เกิน)
                }

                // 2. เวลาของคิวก่อนหน้า (สมมติเฉลี่ยคิวละ 5 นาที)
                int queueDelay = queueAhead * 5; 

                // 3. เวลาเสร็จสิ้นโดยประมาณ
                DateTime orderTime = myOrderTimestamp.toDate();
                DateTime estimatedTime = orderTime.add(Duration(minutes: myPrepTime + queueDelay));
                
                // ถ้าสถานะเป็น "เสร็จแล้ว" ไม่ต้องคำนวณอนาคต
                if (status == 'served' || status == 'completed') {
                  estimatedTimeStr = "เสร็จแล้ว";
                } else {
                  estimatedTimeStr = DateFormat('HH:mm').format(estimatedTime);
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. การ์ดแสดงเวลา
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          if (status == 'served' || status == 'completed')
                            const Column(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 50),
                                SizedBox(height: 10),
                                Text("เครื่องดื่มพร้อมเสิร์ฟแล้ว", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            )
                          else
                            Column(
                              children: [
                                const Text("คาดว่าจะได้รับเครื่องดื่มเวลา", style: TextStyle(fontSize: 16, color: Colors.grey)),
                                const SizedBox(height: 5),
                                Text(
                                  estimatedTimeStr, 
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF6F4E37))
                                ),
                                if (queueAhead > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                                    child: Text("มีคิวรออยู่ก่อนหน้า $queueAhead คิว", style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text("Order #$displayId  •  โต๊ะ $tableNo", style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    // 2. Step Indicator
                    _buildStatusStepper(status),

                    const SizedBox(height: 30),

                    // 3. รายการที่สั่ง
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("รายการของคุณ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(),
                          if (items.isEmpty) const Text("- ไม่ระบุรายการ -", style: TextStyle(color: Colors.grey)),
                          
                          // --- 🔥 แสดงรายการแบบจำกัด (4 รายการแรก หรือทั้งหมดถ้ากดขยาย) ---
                      ...entryList.take(_isExpanded ? entryList.length : 4).map((entry) {
                        String itemName = entry.key;
                        int count = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF6F4E37).withOpacity(0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.coffee, size: 16, color: Color(0xFF6F4E37)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(itemName, style: const TextStyle(fontSize: 16))),
                                  if (count > 1)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF6F4E37).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Text("x$count", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6F4E37))),
                                    )
                                ],
                              ),
                            );
                          }).toList(),

                          // --- 🔥 ปุ่มดูเพิ่มเติม (จะโชว์ถ้ามีมากกว่า 4 รายการ) ---
                      if (entryList.length > 4)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isExpanded ? "ย่อรายการ" : "ดูเพิ่มเติม (${entryList.length - 4} รายการ)",
                                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                Icon(
                                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                )
                              ],
                            ),
                          ),
                        ),
                          
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("ยอดรวมสุทธิ", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("฿${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5D4037))),
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6F4E37), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("กลับหน้าหลัก", style: TextStyle(color: Color(0xFF6F4E37), fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildStatusStepper(String currentStatus) {
    int currentStep = 0;
    if (currentStatus == 'cooking') currentStep = 1;
    else if (currentStatus == 'served') currentStep = 2;
    else if (currentStatus == 'completed') currentStep = 3;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepCircle(0, currentStep, Icons.receipt_long, "รับออเดอร์"),
            _buildLine(0, currentStep),
            _buildStepCircle(1, currentStep, Icons.soup_kitchen, "กำลังทำ"),
            _buildLine(1, currentStep),
            _buildStepCircle(2, currentStep, Icons.room_service, "เสิร์ฟแล้ว"),
          ],
        ),
        if (currentStatus == 'completed')
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text("ออเดอร์เสร็จสิ้น ขอบคุณครับ/ค่ะ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildStepCircle(int stepIndex, int currentStep, IconData icon, String label) {
    bool isActive = currentStep >= stepIndex;
    Color color = isActive 
        ? (currentStep == stepIndex ? const Color(0xFF6F4E37) : const Color(0xFFA6C48A)) 
        : Colors.grey[300]!;
    Color iconColor = isActive ? Colors.white : Colors.grey;
        
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
          fontSize: 12, 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? const Color(0xFF5D4037) : Colors.grey
        )),
      ],
    );
  }

  Widget _buildLine(int stepIndex, int currentStep) {
    bool isActive = currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA6C48A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}