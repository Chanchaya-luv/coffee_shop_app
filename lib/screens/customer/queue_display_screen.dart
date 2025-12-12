import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';

class QueueDisplayScreen extends StatelessWidget {
  const QueueDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Caffy Queue",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20), // ลดขนาด Title
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: Row(
        children: [
          // ฝั่งซ้าย
          Expanded(
            child: _buildQueueColumn(
              title: "กำลังทำ\n(Cooking)", // ขึ้นบรรทัดใหม่ให้ประหยัดที่
              icon: Icons.coffee,
              statusList: ['cooking'],
              headerColor: Colors.orange,
              textColor: Colors.orangeAccent,
            ),
          ),
          // เส้นคั่นบางๆ
          Container(width: 1, color: Colors.grey[850]),
          // ฝั่งขวา
          Expanded(
            child: _buildQueueColumn(
              title: "เชิญรับ\n(Ready)", 
              icon: Icons.check_circle,
              statusList: ['served'],
              headerColor: Colors.green,
              textColor: Colors.greenAccent,
              isHighlight: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueColumn({
    required String title,
    required IconData icon,
    required List<String> statusList,
    required Color headerColor,
    required Color textColor,
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        // Header (ปรับลด Padding และขนาด)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.12),
            border: Border(bottom: BorderSide(color: headerColor, width: 2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: headerColor, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, // ปรับขนาดให้อ่านง่ายบนมือถือ
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', whereIn: statusList)
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "- ว่าง -",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.separated(
                padding: const EdgeInsets.all(12), // ลด Padding ขอบจอ
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10), // ลดระยะห่างระหว่างการ์ด
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String orderId = data['orderId'] ?? '???';
                  String tableNo = data['tableNumber'] ?? '-';

                  return AnimatedScale(
                    duration: const Duration(milliseconds: 350),
                    scale: 1.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      opacity: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isHighlight
                              ? Colors.green.withOpacity(0.15)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: headerColor.withOpacity(0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (isHighlight)
                              BoxShadow(
                                color: headerColor.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                          ],
                        ),
                        // --- 🔥 ใช้ Column เพื่อให้จัดวางได้สวยในจอแคบ ---
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // เลข Order ตัวใหญ่
                            AutoSizeText(
                              orderId,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              minFontSize: 28,
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 8),

                            // เลขโต๊ะ (ป้ายเล็กๆ ด้านล่าง)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "โต๊ะ $tableNo",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}