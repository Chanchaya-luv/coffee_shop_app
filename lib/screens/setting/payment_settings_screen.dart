import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSettingsScreen extends StatefulWidget {
  final bool isReadOnly; // รับค่ามา

  const PaymentSettingsScreen({super.key, this.isReadOnly = false});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _bankNameCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var doc = await FirebaseFirestore.instance.collection('metadata').doc('shop_settings').get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      _bankNameCtrl.text = data['bankName'] ?? '';
      _accountNoCtrl.text = data['accountNumber'] ?? '';
      _accountNameCtrl.text = data['accountName'] ?? '';
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('metadata').doc('shop_settings').set({
        'bankName': _bankNameCtrl.text,
        'accountNumber': _accountNoCtrl.text,
        'accountName': _accountNameCtrl.text,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลสำเร็จ"), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ตั้งค่าการชำระเงิน"),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ข้อมูลบัญชีรับเงิน", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            const SizedBox(height: 10),
            const Text("ข้อมูลนี้จะถูกใช้สำหรับการอ้างอิงในการรับชำระเงิน", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            _buildTextField("ชื่อธนาคาร / PromptPay", _bankNameCtrl, icon: Icons.account_balance),
            const SizedBox(height: 15),
            _buildTextField("เลขที่บัญชี / เบอร์โทร", _accountNoCtrl, icon: Icons.numbers, isNumber: true),
            const SizedBox(height: 15),
            _buildTextField("ชื่อบัญชี", _accountNameCtrl, icon: Icons.person),

            const SizedBox(height: 40),
            
            // --- 🔥 ซ่อนปุ่มบันทึก ถ้าเป็น Read Only ---
            if (!widget.isReadOnly)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveSettings,
                  icon: const Icon(Icons.save),
                  label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("บันทึกข้อมูล", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA6C48A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
               const Center(child: Text("- ไม่สามารถแก้ไขข้อมูลได้ -", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {IconData? icon, bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      readOnly: widget.isReadOnly, // --- 🔥 ล็อกไม่ให้พิมพ์ ---
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: widget.isReadOnly ? Colors.grey : const Color(0xFF5D4037)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: widget.isReadOnly ? Colors.grey[200] : Colors.white, // เปลี่ยนสีพื้น
      ),
    );
  }
}