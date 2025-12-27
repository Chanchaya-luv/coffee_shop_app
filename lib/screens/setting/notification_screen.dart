import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // เก็บรายการที่เลือก { id: data }
  final Map<String, Map<String, dynamic>> _selectedItems = {};

  Future<void> _clearNotifications(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ล้างประวัติแจ้งเตือน"),
        content: const Text("คุณต้องการซ่อนการแจ้งเตือนเก่าทั้งหมดใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ล้าง", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('metadata').doc('notifications').set({
        'lastClearedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ล้างการแจ้งเตือนแล้ว")));
      }
    }
  }

  // --- 🔥 ฟังก์ชันดึงชื่อคนทำรายการ ---
  Future<String> _getRecorderName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) return doc.data()?['name'] ?? 'พนักงาน';
      } catch (e) {
        print("Error: $e");
      }
    }
    return 'Admin';
  }

  // --- 🔥 ฟังก์ชันเปิด Dialog เติมสต๊อกแบบกลุ่ม ---
  void _showBulkRestockDialog() {
    // เตรียม Controllers สำหรับแต่ละรายการ
    Map<String, TextEditingController> controllers = {};
    _selectedItems.forEach((id, _) {
      controllers[id] = TextEditingController();
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("เติมสต๊อก (${_selectedItems.length} รายการ)"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _selectedItems.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (ctx, index) {
              String id = _selectedItems.keys.elementAt(index);
              var data = _selectedItems[id]!;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("เหลือ: ${data['currentStock']} ${data['unit']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    )
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controllers[id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "เพิ่ม (+)",
                        suffixText: data['unit'],
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("บันทึกทั้งหมด"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
            onPressed: () async {
              String recorder = await _getRecorderName();
              WriteBatch batch = FirebaseFirestore.instance.batch();
              bool hasUpdate = false;

              for (var entry in _selectedItems.entries) {
                String id = entry.key;
                var data = entry.value;
                String valStr = controllers[id]!.text.trim();
                double addAmount = double.tryParse(valStr) ?? 0;

                if (addAmount != 0) {
                   hasUpdate = true;
                   double current = (data['currentStock'] ?? 0).toDouble();
                   double newStock = current + addAmount;
                   
                   // อัปเดตสต๊อก
                   DocumentReference ref = FirebaseFirestore.instance.collection('ingredients').doc(id);
                   batch.update(ref, {'currentStock': newStock});
                   
                   // บันทึก Log
                   DocumentReference logRef = FirebaseFirestore.instance.collection('stock_logs').doc();
                   batch.set(logRef, {
                      'ingredientName': data['name'],
                      'changeAmount': addAmount,
                      'remainingStock': newStock,
                      'reason': 'เติมสต๊อกด่วน (Bulk)',
                      'recorder': recorder,
                      'timestamp': FieldValue.serverTimestamp(),
                   });
                }
              }

              if (hasUpdate) {
                await batch.commit();
                if (mounted) {
                  setState(() { _selectedItems.clear(); });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เติมสต๊อกเรียบร้อย!"), backgroundColor: Colors.green));
                }
              }
              if (mounted) Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("การแจ้งเตือนทั้งหมด", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "ล้างการแจ้งเตือน",
            onPressed: () => _clearNotifications(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('metadata').doc('notifications').snapshots(),
        builder: (context, metaSnapshot) {
          
          Timestamp? lastClearedAt;
          if (metaSnapshot.hasData && metaSnapshot.data!.exists) {
            final data = metaSnapshot.data!.data() as Map<String, dynamic>;
            lastClearedAt = data['lastClearedAt'] as Timestamp?;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("⚠️ วัตถุดิบที่ต้องเติม (Low Stock)", Colors.red[800]!),
                _buildLowStockList(),

                const SizedBox(height: 10),

                _buildSectionHeader("💸 รายจ่ายล่าสุด (Expenses)", Colors.orange[900]!),
                _buildExpenseList(lastClearedAt),

                const SizedBox(height: 10),

                _buildSectionHeader("🕒 กิจกรรมล่าสุด (Timeline)", const Color(0xFF5D4037)),
                _buildUnifiedTimeline(lastClearedAt), 
                
                // เผื่อที่ให้ FAB
                const SizedBox(height: 80),
              ],
            ),
          );
        }
      ),
      // --- 🔥 ปุ่ม Floating Action Button สำหรับเติมของที่เลือก ---
      floatingActionButton: _selectedItems.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _showBulkRestockDialog,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text("เติมสต๊อก (${_selectedItems.length})"),
            backgroundColor: const Color(0xFF6F4E37),
            foregroundColor: Colors.white,
          )
        : null,
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Icon(Icons.label_important, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- 🔥 ปรับปรุง Low Stock List ให้มี Checkbox ---
  Widget _buildLowStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ingredients').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator(minHeight: 2));
        
        var lowStockItems = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          double current = (data['currentStock'] ?? 0).toDouble();
          double min = (data['minThreshold'] ?? 0).toDouble();
          return current <= min;
        }).toList();

        if (lowStockItems.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("สต๊อกวัตถุดิบเพียงพอทุกรายการ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            var data = lowStockItems[index].data() as Map<String, dynamic>;
            String id = lowStockItems[index].id;
            bool isSelected = _selectedItems.containsKey(id);

            return Card(
              color: isSelected ? Colors.orange[50] : Colors.red[50], // เปลี่ยนสีเมื่อเลือก
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.orange : Colors.red.shade100)),
              child: ListTile(
                leading: Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF6F4E37),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItems[id] = data;
                      } else {
                        _selectedItems.remove(id);
                      }
                    });
                  },
                ),
                title: Text(data['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                subtitle: Text("เหลือ: ${data['currentStock']} ${data['unit']}", style: TextStyle(fontSize: 12, color: Colors.red[800])),
                trailing: const Text("ต้องเติม", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                onTap: () {
                   setState(() {
                      if (isSelected) {
                        _selectedItems.remove(id);
                      } else {
                        _selectedItems[id] = data;
                      }
                   });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpenseList(Timestamp? lastClearedAt) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('expenses').orderBy('date', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator(minHeight: 2));

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['date'] == null) return false;
          if (lastClearedAt != null) {
            Timestamp expenseTime = data['date'];
            if (expenseTime.compareTo(lastClearedAt) <= 0) return false;
          }
          return true;
        }).toList();

        if (docs.isEmpty) {
return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีรายจ่ายใหม่", style: TextStyle(color: Colors.grey))));        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String title = data['title'] ?? 'รายจ่ายทั่วไป';
            double amount = (data['amount'] ?? 0).toDouble();
            Timestamp ts = data['date'];
            String timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.withOpacity(0.3))),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: Colors.orange[50], child: const Icon(Icons.money_off, color: Colors.orange, size: 20)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(timeStr, style: const TextStyle(fontSize: 12)),
                trailing: Text("-฿${NumberFormat('#,##0').format(amount)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnifiedTimeline(Timestamp? lastClearedAt) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).limit(30).snapshots(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('expenses').orderBy('date', descending: true).limit(30).snapshots(),
          builder: (context, expenseSnapshot) {
            if (!orderSnapshot.hasData || !expenseSnapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }

            List<Map<String, dynamic>> activities = [];
            for (var doc in orderSnapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['type'] = 'order'; 
              data['sortTime'] = data['timestamp']; 
              activities.add(data);
            }

            for (var doc in expenseSnapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['type'] = 'expense';
              data['sortTime'] = data['date']; 
              activities.add(data);
            }

            var filteredActivities = activities.where((data) {
              Timestamp? ts = data['sortTime'];
              if (ts == null) return false;
              if (lastClearedAt != null && ts.compareTo(lastClearedAt) <= 0) return false;
              return true;
            }).toList();

            filteredActivities.sort((a, b) {
              Timestamp t1 = a['sortTime'];
              Timestamp t2 = b['sortTime'];
              return t2.compareTo(t1);
            });

            if (filteredActivities.isEmpty) {
               return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีกิจกรรมใหม่", style: TextStyle(color: Colors.grey))));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                var data = filteredActivities[index];
                bool isLast = index == filteredActivities.length - 1;
                
                if (data['type'] == 'order') {
                  return _buildOrderTile(data, isLast);
                } else {
                  return _buildExpenseTile(data, isLast);
                }
              },
            );
          }
        );
      }
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> data, bool isLast) {
    String orderId = data['orderId'] ?? '-';
    String tableNo = data['tableNumber'] ?? '-';
    double totalPrice = (data['totalPrice'] ?? 0).toDouble();
    String method = data['paymentMethod'] ?? 'Cash';
    Timestamp ts = data['timestamp'];
    String timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());

    bool isQR = method == 'QR';
    Color iconColor = isQR ? Colors.blue : Colors.green;
    IconData iconData = isQR ? Icons.qr_code_2 : Icons.attach_money;

    return _buildTimelineItem(
      icon: iconData,
      iconColor: iconColor,
      timeStr: timeStr,
      title: "ได้รับเงินเข้า (Order #$orderId)",
      amount: "+฿${NumberFormat('#,##0').format(totalPrice)}",
      amountColor: iconColor,
      subtitle: "โต๊ะ: $tableNo | ${isQR ? 'PromptPay' : 'เงินสด'}",
      isLast: isLast,
    );
  }

  Widget _buildExpenseTile(Map<String, dynamic> data, bool isLast) {
    String title = data['title'] ?? 'รายจ่ายทั่วไป';
    double amount = (data['amount'] ?? 0).toDouble();
    Timestamp ts = data['date'];
    String timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());
    String recorder = data['recorder'] ?? 'Admin';

    return _buildTimelineItem(
      icon: Icons.money_off,
      iconColor: Colors.orange,
      timeStr: timeStr,
      title: "รายจ่าย: $title",
      amount: "-฿${NumberFormat('#,##0').format(amount)}",
      amountColor: Colors.red,
      subtitle: "บันทึกโดย $recorder", 
      isLast: isLast,
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String timeStr,
    required String title,
    required String amount,
    required Color amountColor,
    required String subtitle,
    required bool isLast,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0), 
      child: IntrinsicHeight( 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: iconColor.withOpacity(0.5))),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey[200])),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)), Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]))]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}