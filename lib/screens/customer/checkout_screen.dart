import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import 'payment_screen.dart';
// --- 1. Import หน้าผังโต๊ะ ---
import '../../screens/admin/table_monitor_screen.dart'; 

class CheckoutScreen extends StatefulWidget {
  final String tableNumber; // รับเลขโต๊ะเริ่มต้น หรือ TA-001

  const CheckoutScreen({
    super.key, 
    required this.tableNumber, required bool isCustomer
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'Cash';
  
  // --- 2. ตัวแปรเก็บเลขโต๊ะปัจจุบัน (เพื่อให้เปลี่ยนได้) ---
  late String _currentTable;

  @override
  void initState() {
    super.initState();
    // กำหนดค่าเริ่มต้นจากที่ส่งมา (เช่น TA-001)
    _currentTable = widget.tableNumber;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final items = cart.items.values.toList();
    
    double discount = 0.0; 
    double finalTotal = cart.totalAmount > discount ? cart.totalAmount - discount : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      
      body: Column(
        children: [
          const SizedBox(height: 20),

          // --- 3. เพิ่มส่วนเลือกโต๊ะ (Table Selector) ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFA6C48A).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_restaurant, color: Color(0xFFA6C48A)),
              ),
              title: const Text("โต๊ะ / คิว", style: TextStyle(fontSize: 14, color: Colors.grey)),
              subtitle: Text(
                _currentTable, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))
              ),
              trailing: TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("เปลี่ยน"),
                onPressed: () async {
                  // เปิดหน้าเลือกโต๊ะ (TableMonitor)
                  final selectedTable = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TableMonitorScreen(isSelectionMode: true),
                    ),
                  );

                  // ถ้ามีการเลือกกลับมา ให้อัปเดตค่า
                  if (selectedTable != null) {
                    setState(() {
                      _currentTable = selectedTable;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 15),

          // --- รายการสินค้า (Card สีขาว) ---
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: items.isEmpty 
              ? const Center(child: Text("ไม่มีสินค้าในตะกร้า"))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 30),
                  itemBuilder: (context, index) {
                    var item = items[index];
                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.brown),
                          onPressed: () => cart.removeSingleItem(item.menu.id),
                        ),
                        Expanded(
                          child: Text(item.menu.name, style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037))),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => cart.updateQuantity(item.menu, -1),
                                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("-", style: TextStyle(fontSize: 20))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: Colors.grey.shade300))),
                                child: Text("${item.quantity}"),
                              ),
                              InkWell(
                                onTap: () => cart.updateQuantity(item.menu, 1),
                                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("+", style: TextStyle(fontSize: 20, color: Colors.green))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text("฿${(item.menu.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
            ),
          ),

          // --- Footer สรุปยอด ---
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF9F9F9),
            child: Column(
              children: [
                _buildSummaryRow("ยอดรวม", cart.totalAmount),
                _buildSummaryRow("ส่วนลด/โปรโมชั่น", discount, isDiscount: true),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("ยอดรวมทั้งหมด", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    Text("฿${finalTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                const Align(alignment: Alignment.centerLeft, child: Text("วิธีการชำระ:", style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildPaymentButton("เงินสด", Icons.payments, _paymentMethod == 'Cash', () => setState(() => _paymentMethod = 'Cash')),
                    const SizedBox(width: 15),
                    _buildPaymentButton("QR-Code", Icons.qr_code_2, _paymentMethod == 'QR', () => setState(() => _paymentMethod = 'QR')),
                  ],
                ),

                const SizedBox(height: 20),

                // ปุ่ม Action
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA6C48A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentScreen(
                                  amount: finalTotal,
                                  paymentMethod: _paymentMethod,
                                  tableNumber: _currentTable, // --- 4. ส่งค่าโต๊ะที่เลือกไป ---
                                ),
                              ),
                            );
                          },
                          child: Text("จ่าย (฿${finalTotal.toStringAsFixed(0)})", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5B6B6), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("ยกเลิกออเดอร์", style: TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          isDiscount 
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                child: Text(amount.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            : Text("฿${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? const Color(0xFF5D4037) : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF5D4037)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            ],
          ),
        ),
      ),
    );
  }
}