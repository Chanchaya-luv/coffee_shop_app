import 'package:flutter/material.dart';

class StoreProfileScreen extends StatelessWidget {
  final bool isReadOnly; // รับค่ามา

  const StoreProfileScreen({super.key, this.isReadOnly = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("ข้อมูลร้านค้า"),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.transparent,
              backgroundImage: NetworkImage('https://img5.pic.in.th/file/secure-sv1/05871915-7cac-440c-9a52-17e6d9d71b4c.md.png'),
            ),
            const SizedBox(height: 40),

            _buildTextField("ชื่อร้าน", "Caffy Coffee", Icons.store, isReadOnly),
            const SizedBox(height: 15),
            _buildTextField("เบอร์โทรศัพท์", "081-234-5678", Icons.phone, isReadOnly, isNumber: true),
            const SizedBox(height: 15),
            _buildTextField("ที่อยู่", "กรุงเทพมหานคร", Icons.location_on, isReadOnly, maxLines: 3),
            const SizedBox(height: 15),
            _buildTextField("เลขผู้เสียภาษี (ถ้ามี)", "-", Icons.assignment, isReadOnly),
            
            const SizedBox(height: 40),

            // --- 🔥 ซ่อนปุ่มบันทึก ถ้าเป็น Read Only ---
            if (!isReadOnly)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลเรียบร้อย")));
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("บันทึกการเปลี่ยนแปลง", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA6C48A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
               const Text("- ไม่สามารถแก้ไขข้อมูลได้ -", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, IconData icon, bool readOnly, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      readOnly: readOnly, // --- 🔥 ล็อกไม่ให้พิมพ์ ---
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: readOnly ? Colors.grey : const Color(0xFF6F4E37)),
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : Colors.white, // เปลี่ยนสีพื้นถ้าล็อก
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}