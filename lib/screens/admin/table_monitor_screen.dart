import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TableMonitorScreen extends StatelessWidget {
  final bool isSelectionMode; // ถ้า true แปลว่าเปิดมาเพื่อเลือกโต๊ะ (ตอนสั่งของ)
  
  const TableMonitorScreen({super.key, this.isSelectionMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(isSelectionMode ? "เลือกโต๊ะ" : "สถานะโต๊ะ (8 โต๊ะ)"),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ดึงข้อมูลโต๊ะจาก Firebase (ต้องสร้าง collection 'tables' ไว้)
        stream: FirebaseFirestore.instance.collection('tables').orderBy('id').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("เกิดข้อผิดพลาด"));
          
          // ถ้ายังไม่มีข้อมูล ให้ Mockup โต๊ะ 1-8 ขึ้นมาแสดงก่อน
          List<Map<String, dynamic>> tables = [];
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            tables = List.generate(8, (index) => {
              'id': '${index + 1}',
              'status': 'available', // available, occupied
            });
          } else {
            tables = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 แถวแนวตั้ง
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.5,
            ),
            itemCount: 8, // กำหนดตายตัว 8 โต๊ะ
            itemBuilder: (context, index) {
              // หาข้อมูลของโต๊ะเลขนี้ (ถ้ามี)
              String tableId = '${index + 1}';
              var tableData = tables.firstWhere(
                (t) => t['id'] == tableId, 
                orElse: () => {'id': tableId, 'status': 'available'}
              );
              
              bool isOccupied = tableData['status'] == 'occupied';

              return GestureDetector(
                onTap: () {
                  if (isSelectionMode) {
                    // ถ้าเลือกโต๊ะเพื่อสั่งอาหาร -> ส่งเลขโต๊ะกลับไป
                    Navigator.pop(context, tableId);
                  } else {
                    // ถ้าดูสถานะเฉยๆ -> อาจจะมี Dialog เคลียร์โต๊ะ (Manual)
                    _showClearTableDialog(context, tableId, isOccupied);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isOccupied ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOccupied ? Colors.red : Colors.green,
                      width: 2,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOccupied ? Icons.person : Icons.event_seat_outlined,
                        size: 40,
                        color: isOccupied ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "โต๊ะ $tableId",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isOccupied ? Colors.red[800] : Colors.green[800],
                        ),
                      ),
                      Text(
                        isOccupied ? "ไม่ว่าง" : "ว่าง",
                        style: TextStyle(
                          color: isOccupied ? Colors.red : Colors.green,
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearTableDialog(BuildContext context, String tableId, bool isOccupied) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("จัดการโต๊ะ $tableId"),
        content: Text(isOccupied ? "ต้องการเคลียร์โต๊ะนี้ให้ว่างไหม?" : "ต้องการจองโต๊ะนี้ไหม?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () {
              // อัปเดตสถานะโต๊ะใน Firebase
              FirebaseFirestore.instance.collection('tables').doc(tableId).set({
                'id': tableId,
                'status': isOccupied ? 'available' : 'occupied', // สลับสถานะ
              });
              Navigator.pop(ctx);
            },
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );
  }
}