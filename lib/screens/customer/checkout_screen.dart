import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import 'payment_screen.dart';
import '../../screens/admin/table_monitor_screen.dart'; 
import '../../services/promotion_service.dart';
import '../../models/model_promotion.dart';

import '../../services/smart_upsell_service.dart';
import '../../models/model_menu.dart'; 
// ลบ import member

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
  bool _hasCheckedUpsell = false;

  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentTable = widget.tableNumber;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedUpsell) {
        _checkAndShowUpsell();
      }
    });
  }

  Future<void> _checkAndShowUpsell() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final items = cart.items.values.toList();
    
   // ถ้ามีของแถม หรือ โปรโมชั่นแล้ว ไม่ต้อง Upsell
    bool hasPromoItem = items.any((item) => item.menu.id.endsWith('_PROMO') || item.menu.id.endsWith('_FREE'));
    if (hasPromoItem) return;

    List<MenuItem> upsellItems = await SmartUpsellService().getUpsellItems(items);

    if (upsellItems.isNotEmpty && mounted) {
      _showUpsellDialog(upsellItems); 
      _hasCheckedUpsell = true; 
    }
  }

  // --- 🔥 ฟังก์ชันเช็คโค้ดส่วนลด (ปรับปรุงใหม่) ---
  Future<void> _verifyAndApplyCode() async {
    String code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();

    final cart = Provider.of<CartProvider>(context, listen: false);
    final items = cart.items.values.toList();

    // เรียก Service ตรวจสอบ
    final result = await PromotionService().verifyPromoCode(code, items);

    if (result['isValid'] == true) {
      // กรณี 1: ส่วนลดเงินสด
      if (result['type'] == 'discount') {
        setState(() {
          _discountAmount = (result['discountAmount'] as num).toDouble();
          _discountNote = "Code: $code";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
          Navigator.pop(context); // ปิด Dialog กรอกโค้ด
        }
      }
      // กรณี 2: ของแถม (Buy X Get Y)
      else if (result['type'] == 'free_item') {
        double maxPrice = (result['maxPrice'] as num).toDouble();
        if (mounted) {
          Navigator.pop(context); // ปิด Dialog กรอกโค้ดก่อน
          _showFreeItemSelector(maxPrice); // เปิด Dialog เลือกของแถม
        }
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  // --- 🔥 Dialog เลือกของแถม (เฉพาะเครื่องดื่มที่ราคา <= maxPrice) ---
  void _showFreeItemSelector(double maxPrice) async {
    // โหลดข้อมูลสินค้าที่แถมได้
    List<MenuItem> freeItems = await PromotionService().getEligibleFreeItems(maxPrice);

    if (!mounted) return;

    if (freeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่พบสินค้าที่เข้าเงื่อนไขของแถม"), backgroundColor: Colors.orange));
      return;
    }
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Column(
          children: [
            const Icon(Icons.card_giftcard, size: 40, color: Colors.purple),
            const SizedBox(height: 10),
            const Text("เลือกของแถมฟรี! 🎁", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("เลือกเครื่องดื่มราคาไม่เกิน ฿${maxPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.separated(
            itemCount: freeItems.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final item = freeItems[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s)=> Container(width:50,height:50,color:Colors.brown[100],child:const Icon(Icons.local_cafe,color:Colors.brown)))
                      : Container(width: 50, height: 50, color: Colors.brown[100], child: const Icon(Icons.local_cafe, color: Colors.brown)),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("ปกติ ฿${item.price.toStringAsFixed(0)}", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(60, 30)),
                  onPressed: () {
                     // เพิ่มของแถมลงตะกร้า (ราคา 0, ห้ามแก้ไข)
                     MenuItem freeItem = MenuItem(
                        id: "${item.id}_FREE", // เติม _FREE เพื่อแยก
                        name: "${item.name} (FREE)",
                        price: 0.0,
                        category: item.category,
                        imageUrl: item.imageUrl,
                        recipe: item.recipe,
                        isAvailable: true,
                      );
                      
                      Provider.of<CartProvider>(context, listen: false).addItem(
                        freeItem,
                        type: 'ปกติ', 
                        priceAdjustment: 0.0, 
                        sweetness: '-', 
                        milk: '-',
                      );

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("รับของแถมเรียบร้อย!"), backgroundColor: Colors.green));
                  },
                  child: const Text("รับฟรี"),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("สละสิทธิ์", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  void _showUpsellDialog(List<MenuItem> upsellItems) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 100,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF6F4E37),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.yellow, size: 36),
                  const SizedBox(height: 5),
                  const Text("ข้อเสนอพิเศษ!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text("เลือกรับสิทธิ์แลกซื้อ 1 อย่าง (ลด 20%)", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            
            // List Items
            Container(
              height: 300, 
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: upsellItems.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (context, index) {
                  final item = upsellItems[index];
                  double specialPrice = item.price * 0.8;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(item.imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 60, height: 60, color: Colors.brown[100], child: const Icon(Icons.coffee, color: Colors.brown)))
                          : Container(width: 60, height: 60, color: Colors.brown[100], child: const Icon(Icons.cake, color: Colors.brown)),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Row(
                      children: [
                        Text("฿${item.price.toStringAsFixed(0)}", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 5),
                        Text("฿${specialPrice.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA6C48A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(70, 35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                         MenuItem discountedItem = MenuItem(
                            id: "${item.id}_PROMO", 
                            name: "${item.name} (Pro 20%)",
                            price: specialPrice,
                            category: item.category,
                            imageUrl: item.imageUrl,
                            recipe: item.recipe,
                            isAvailable: true,
                          );
                          
                          // --- 🔥 แก้ไข: เช็คหมวดหมู่เพื่อกำหนดค่าเริ่มต้นให้ถูกต้อง ---
                          bool isBakery = ['เบเกอรี่', 'ขนม', 'เค้ก', 'ของหวาน', 'ผลไม้'].contains(item.category);

                          Provider.of<CartProvider>(context, listen: false).addItem(
                            discountedItem,
                            // ถ้าเป็นเบเกอรี่ ให้เป็นปกติ ไม่บวกเงิน และไม่มีความหวาน/นม
                            type: isBakery ? 'ปกติ' : 'เย็น', 
                            priceAdjustment: isBakery ? 0.0 : 5.0, 
                            sweetness: isBakery ? '-' : 'ปกติ (100%)',
                            milk: isBakery ? '-' : 'นมวัว',
                          );

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เพิ่มสินค้าโปรโมชั่นแล้ว!"), backgroundColor: Colors.green));
                      },
                      child: const Text("เลือก"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text("ไม่รับ ขอบคุณ", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🔥 Dialog กรอกโค้ด ---
  void _showPromoCodeDialog() {
    _codeCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("กรอกโค้ดส่วนลด"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ใส่โค้ดที่คุณได้รับจากร้านค้า", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: "",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: _verifyAndApplyCode,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6F4E37), foregroundColor: Colors.white),
            child: const Text("ใช้โค้ด"),
          ),
        ],
      ),
    );
  }

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
appBar: AppBar(
  title: const Text(
    "Checkout",
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: const Color(0xFF6F4E37),
  foregroundColor: Colors.white,
),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Table Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
            child: ListTile(
              leading: const Icon(Icons.table_restaurant, color: Color(0xFFA6C48A)),
              title: const Text("โต๊ะ", style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                    bool isPromo = cartItem.menu.id.endsWith('_PROMO'); 
                    
                    bool hasOptions = (cartItem.sweetness != '-' && cartItem.sweetness != 'ปกติ (100%)') ||
                                      (cartItem.milk != '-' && cartItem.milk != 'นมวัว');

                    return Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

                      
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.brown), onPressed: () => cart.removeItem(cartItem.key)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- แสดงชื่อและประเภท ---
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
  child: Text(
        cartItem.menu.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF5D4037),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

                                  const SizedBox(width: 5),
                                  if (cartItem.type != 'ปกติ')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.brown[50], borderRadius: BorderRadius.circular(4)),
                                      child: Text(cartItem.type, style: const TextStyle(fontSize: 10, color: Colors.brown, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                              if (hasOptions)
                                Text("หวาน: ${cartItem.sweetness}, ${cartItem.milk}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              InkWell(onTap: () => cart.removeSingleItem(cartItem.key), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("-", style: TextStyle(fontSize: 20)))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: Colors.grey.shade300))), child: Text("${cartItem.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              InkWell(
                                onTap: isPromo 
                                  ? () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("สินค้าโปรโมชั่นจำกัด 1 ชิ้นต่อออเดอร์ หากต้องการเพิ่มกรุณาสั่งแบบราคาปกติ"), duration: Duration(seconds: 2))); } 
                                  : () => cart.addQuantity(cartItem.key),
                                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text("+", style: TextStyle(fontSize: 20, color: isPromo ? Colors.grey : Colors.green)))
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        // ราคารวม (คำนวณจากสูตรใหม่ใน Provider)
                        Text("฿${( (cartItem.menu.price + cartItem.priceAdjustment) * cartItem.quantity).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                // --- 🔥 เปลี่ยนปุ่มส่วนลดเป็นปุ่มกรอกโค้ด ---
                  InkWell(
                    // เปิดให้ลูกค้ากดได้แล้ว
                    onTap: () => _showPromoCodeDialog(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                               const Icon(Icons.confirmation_number_outlined, size: 18, color: Colors.orange), 
                               const SizedBox(width: 8),
                               Text(_discountNote.isEmpty ? "มีโค้ดส่วนลดไหม?" : _discountNote, style: TextStyle(color: _discountNote.isEmpty ? Colors.grey : Colors.blue, fontWeight: FontWeight.bold))
                            ]),
                            Text("- ฿${_discountAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
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