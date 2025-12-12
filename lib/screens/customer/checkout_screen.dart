import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import 'payment_screen.dart';
import '../../screens/admin/table_monitor_screen.dart'; 
// --- 🔥 เพิ่ม Import 2 ไฟล์นี้ ---
import '../../services/promotion_service.dart';
import '../../models/model_promotion.dart';

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
  double _discountAmount = 0.0;
  String _discountNote = "";

  @override
  void initState() {
    super.initState();
    _currentTable = widget.tableNumber;
  }

  // --- 🔥 ฟังก์ชันแสดงหน้าต่างเลือกโปรโมชั่น ---
  void _showPromotionDialog(List<CartItem> items, double totalAmount) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("เลือกโปรโมชั่น", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              // 1. ส่วนลดกำหนดเอง (Manual)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("ส่วนลดกำหนดเอง (Manual)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDiscountDialog(totalAmount); // เรียก Dialog เดิม
                },
              ),
              const Divider(),
              
              // 2. โปรโมชั่นอัตโนมัติ (Auto)
              Expanded(
                child: StreamBuilder<List<Promotion>>(
                  stream: PromotionService().getActivePromotions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var promos = snapshot.data!;
                    if (promos.isEmpty) return const Center(child: Text("ไม่มีโปรโมชั่นที่เปิดใช้งาน"));

                    return ListView.builder(
                      itemCount: promos.length,
                      itemBuilder: (context, index) {
                        var p = promos[index];
                        // คำนวณส่วนลด
                        double calDiscount = PromotionService().calculateDiscount(p, items, totalAmount);
                        bool isApplicable = calDiscount > 0;

                        return ListTile(
                          leading: const Icon(Icons.local_offer, color: Colors.orange),
                          title: Text(p.name),
                          subtitle: Text(isApplicable ? "ลด ฿${calDiscount.toStringAsFixed(0)}" : "เงื่อนไขไม่ตรง"),
                          trailing: isApplicable ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          enabled: isApplicable, // กดได้เฉพาะถ้าเงื่อนไขตรง
                          onTap: isApplicable ? () {
                            setState(() {
                              _discountAmount = calDiscount;
                              _discountNote = p.name;
                            });
                            Navigator.pop(ctx);
                          } : null,
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      }
    );
  }

  // (Dialog เดิมของคุณ)
  void _showDiscountDialog(double totalAmount) {
     final valueCtrl = TextEditingController();
     bool isPercent = false;
     showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("เพิ่มส่วนลด"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [Expanded(child: TextField(controller: valueCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isPercent ? "%" : "บาท"))), const SizedBox(width: 10), ToggleButtons(isSelected: [!isPercent, isPercent], onPressed: (index) => setState(() => isPercent = index == 1), children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("฿")), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("%"))])])]),
          actions: [TextButton(onPressed: () { this.setState(() { _discountAmount = 0; _discountNote = ""; }); Navigator.pop(ctx); }, child: const Text("ล้าง")), ElevatedButton(onPressed: () { double val = double.tryParse(valueCtrl.text) ?? 0; double cal = isPercent ? totalAmount * (val/100) : val; this.setState(() { _discountAmount = cal; _discountNote = isPercent ? "ลด $val%" : "ลด $val บาท"; }); Navigator.pop(ctx); }, child: const Text("ตกลง"))]
        )
      )
     );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final items = cart.items.values.toList(); 
    
    double totalAmount = cart.totalAmount;
    double finalTotal = totalAmount - _discountAmount;
    if (finalTotal < 0) finalTotal = 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(title: const Text("Checkout"), backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Table Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
            child: ListTile(
              leading: const Icon(Icons.table_restaurant, color: Color(0xFFA6C48A)),
              title: const Text("โต๊ะ / คิว", style: TextStyle(fontSize: 14, color: Colors.grey)),
              subtitle: Text(_currentTable, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              trailing: widget.isCustomer ? null : TextButton(onPressed: () async { final t = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TableMonitorScreen(isSelectionMode: true))); if(t!=null) setState(()=>_currentTable=t); }, child: const Text("เปลี่ยน")),
            ),
          ),
          const SizedBox(height: 15),

          // --- Items List ---
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
                    var cartItem = items[index];
                    return Row(
                      children: [
                        // ปุ่มถังขยะ
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.brown), 
                          onPressed: () => cart.removeItem(cartItem.key) 
                        ),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cartItem.menu.name, style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                              if (cartItem.sweetness != 'ปกติ (100%)' || cartItem.milk != 'นมวัว')
                                Text("หวาน: ${cartItem.sweetness}, ${cartItem.milk}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ),
                        
                        // ปุ่ม +/-
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18, color: Colors.black),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
                                onPressed: () => cart.removeSingleItem(cartItem.key),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8), 
                                decoration: BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: Colors.grey.shade300))), 
                                child: Text("${cartItem.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18, color: Colors.green),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
                                onPressed: () => cart.addQuantity(cartItem.key),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 15),
                        Text("฿${(cartItem.menu.price * cartItem.quantity).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                
                // --- 🔥 แถวส่วนลด (กดเพื่อเรียก Popup) ---
                InkWell(
                  onTap: () => _showPromotionDialog(items, totalAmount), // เรียกฟังก์ชันใหม่
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                           const Text("ส่วนลด / โปรโมชั่น", style: TextStyle(color: Colors.grey)),
                           const SizedBox(width: 5),
                           const Icon(Icons.local_offer, size: 14, color: Colors.orange), // ไอคอน Tag
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
                Row(children: [Expanded(child: SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen(amount: finalTotal, paymentMethod: _paymentMethod, tableNumber: _currentTable, isCustomer: widget.isCustomer, discount: _discountAmount))); }, child: Text("จ่าย (฿${finalTotal.toStringAsFixed(0)})", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))))), const SizedBox(width: 10), Expanded(child: SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5B6B6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(context), child: const Text("ยกเลิกออเดอร์", style: TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold)))))])
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) { return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text("฿${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey))])); }
  Widget _buildPaymentButton(String label, IconData icon, bool isSelected, VoidCallback onTap) { return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: isSelected ? const Color(0xFF5D4037) : Colors.grey.shade300, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(10), color: Colors.white), child: Column(children: [Icon(icon, color: const Color(0xFF5D4037)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))])))); }
}