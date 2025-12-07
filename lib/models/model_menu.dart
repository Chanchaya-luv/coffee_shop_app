import 'dart:convert';

class RecipeItem {
  final String ingredientId;
  final double quantityUsed;

  RecipeItem({
    required this.ingredientId, 
    required this.quantityUsed
  });

  factory RecipeItem.fromMap(Map<String, dynamic> data) {
    var qty = data['quantityUsed'] ?? data['quantity'] ?? 0;
    double finalQty = 0.0;
    if (qty is num) {
      finalQty = qty.toDouble();
    } else if (qty is String) {
      finalQty = double.tryParse(qty) ?? 0.0;
    }

    return RecipeItem(
      ingredientId: data['ingredientId'] ?? '',
      quantityUsed: finalQty,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String imageUrl;
  final List<RecipeItem> recipe;
  final bool isAvailable; // --- 🔥 เพิ่มตัวแปรเช็คของหมด ---

  MenuItem({
    required this.id, 
    required this.name, 
    required this.price, 
    this.category = 'อื่นๆ',
    this.imageUrl = '',
    required this.recipe,
    this.isAvailable = true, // ค่า Default คือมีของ (True)
  });
}