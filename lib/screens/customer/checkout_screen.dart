import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import 'payment_screen.dart';
import '../../screens/admin/table_monitor_screen.dart'; 

class CheckoutScreen extends StatefulWidget {
  final String tableNumber;
  final bool isCustomer;

  const CheckoutScreen({
    super.key, 
    required this.tableNumber,
    this.isCustomer = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'Cash';
  late String _currentTable;
  
  // --- 🔥 ตัวแปรส่วนลด ---
  double _discountAmount = 0.0;
  String _discountNote = ""; // เช่น "ลด 10%", "พนักงานทานเอง"

  @override
  void initState() {
    super.initState();
    _currentTable = widget.tableNumber;
  }

  // --- ฟังก์ชันแสดง Dialog ใส่ส่วนลด ---
  void _showDiscountDialog(double totalAmount) {
    final valueCtrl = TextEditingController();
    bool isPercent = false; // true = %, false = บาท

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("เพิ่มส่วนลด"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isPercent ? "เปอร์เซ็นต์ (%)" : "จำนวนเงิน (บาท)",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ToggleButtons(
                      isSelected: [!isPercent, isPercent],
                      onPressed: (index) {
                        setState(() => isPercent = index == 1);
                      },
                      borderRadius: BorderRadius.circular(8),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("฿")),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("%")),
                      ],
                    )
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                   // เคลียร์ส่วนลด
                   this.setState(() {
                     _discountAmount = 0;
                     _discountNote = "";
                   });
                   Navigator.pop(ctx);
                },
                child: const Text("ล้างส่วนลด", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
                onPressed: () {
                  double val = double.tryParse(valueCtrl.text) ?? 0;
                  double calDiscount = 0;

                  if (isPercent) {
                    calDiscount = totalAmount * (val / 100);
                    _discountNote = "ลด $val%";
                  } else {
                    calDiscount = val;
                    _discountNote = "ลด $val บาท";
                  }

                  // อัปเดตหน้าจอหลัก
                  this.setState(() {
                    _discountAmount = calDiscount;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("ตกลง"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final items = cart.items.values.toList();
    
    // คำนวณยอด
    double totalAmount = cart.totalAmount;
    double finalTotal = totalAmount - _discountAmount;
    if (finalTotal < 0) finalTotal = 0;

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

          // Table Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFA6C48A).withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.table_restaurant, color: Color(0xFFA6C48A))),
              title: const Text("โต๊ะ / คิว", style: TextStyle(fontSize: 14, color: Colors.grey)),
              subtitle: Text(_currentTable, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              trailing: widget.isCustomer 
                  ? null 
                  : TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("เปลี่ยน"),
                      onPressed: () async {
                        final selectedTable = await Navigator.push(context, MaterialPageRoute(builder: (context) => const TableMonitorScreen(isSelectionMode: true)));
                        if (selectedTable != null) setState(() => _currentTable = selectedTable);
                      },
                    ),
            ),
          ),

          const SizedBox(height: 15),

          // Items List
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: items.isEmpty 
              ? const Center(child: Text("ไม่มีสินค้าในตะกร้า"))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 30),
                  itemBuilder: (context, index) {
                    var item = items[index];
                    return Row(
                      children: [
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.brown), onPressed: () => cart.removeSingleItem(item.menu.id)),
                        Expanded(child: Text(item.menu.name, style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037)))),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              InkWell(onTap: () => cart.updateQuantity(item.menu, -1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("-", style: TextStyle(fontSize: 20)))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: Colors.grey.shade300))), child: Text("${item.quantity}")),
                              InkWell(onTap: () => cart.updateQuantity(item.menu, 1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("+", style: TextStyle(fontSize: 20, color: Colors.green)))),
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

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF9F9F9),
            child: Column(
              children: [
                _buildSummaryRow("ยอดรวม", totalAmount),
                
                // --- 🔥 แถวส่วนลด (กดได้) ---
                InkWell(
                  onTap: () => _showDiscountDialog(totalAmount), // กดเพื่อใส่ส่วนลด
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                           const Text("ส่วนลด", style: TextStyle(color: Colors.grey)),
                           const SizedBox(width: 5),
                           const Icon(Icons.edit, size: 14, color: Colors.blue), // ไอคอนบอกว่ากดแก้ได้
                           if (_discountNote.isNotEmpty) Text(" ($_discountNote)", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                        ]),
                        Text("- ฿${_discountAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ยอดรวมทั้งหมด", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))), Text("฿${finalTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]),
                const SizedBox(height: 20),
                
                const Align(alignment: Alignment.centerLeft, child: Text("วิธีการชำระ:", style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 10),
                Row(children: [_buildPaymentButton("เงินสด", Icons.payments, _paymentMethod == 'Cash', () => setState(() => _paymentMethod = 'Cash')), const SizedBox(width: 15), _buildPaymentButton("QR-Code", Icons.qr_code_2, _paymentMethod == 'QR', () => setState(() => _paymentMethod = 'QR'))]),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            // --- 🔥 ส่งค่า discount ไปหน้า Payment ---
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentScreen(
                                  amount: finalTotal, // ยอดที่ลดแล้ว
                                  paymentMethod: _paymentMethod,
                                  tableNumber: _currentTable,
                                  isCustomer: widget.isCustomer,
                                  discount: _discountAmount, // ส่งยอดส่วนลดไปด้วย
                                ),
                              ),
                            );
                          },
                          child: Text("จ่าย (฿${finalTotal.toStringAsFixed(0)})", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5B6B6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(context), child: const Text("ยกเลิกออเดอร์", style: TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold))))),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text("฿${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey))]));
  }

  Widget _buildPaymentButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: isSelected ? const Color(0xFF5D4037) : Colors.grey.shade300, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(10), color: Colors.white), child: Column(children: [Icon(icon, color: const Color(0xFF5D4037)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]))));
  }
}