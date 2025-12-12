import 'package:flutter/material.dart';
import '../../models/model_menu.dart';

class ProductCustomizeDialog extends StatefulWidget {
  final MenuItem menu;
  final Function(String sweetness, String milk) onConfirm;

  const ProductCustomizeDialog({
    super.key, 
    required this.menu, 
    required this.onConfirm
  });

  @override
  State<ProductCustomizeDialog> createState() => _ProductCustomizeDialogState();
}

class _ProductCustomizeDialogState extends State<ProductCustomizeDialog> {
  String _sweetness = 'ปกติ (100%)';
  String _milk = 'นมวัว';

  final List<String> _sweetnessOptions = ['0%', '25%', '50%', 'ปกติ (100%)', '125%'];
  final List<String> _milkOptions = ['นมวัว', 'นมโอ๊ต', 'นมถั่วเหลือง'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.menu.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ระดับความหวาน", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _sweetnessOptions.map((option) {
                bool isSelected = _sweetness == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: const Color(0xFFA6C48A),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    if (selected) setState(() => _sweetness = option);
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 20),
            
            const Text("ประเภทนม", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _milkOptions.map((option) {
                bool isSelected = _milk == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: const Color(0xFF6F4E37),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    if (selected) setState(() => _milk = option);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), foregroundColor: Colors.white),
          onPressed: () {
            widget.onConfirm(_sweetness, _milk);
            Navigator.pop(context);
          },
          child: const Text("เพิ่มใส่ตะกร้า"),
        ),
      ],
    );
  }
}