class Ingredient {
  final String id;
  final String name;
  final double currentStock;
  final String unit;
  final double minThreshold;

  Ingredient({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.unit,
    required this.minThreshold,
  });

  factory Ingredient.fromMap(Map<String, dynamic> data, String documentId) {
    return Ingredient(
      id: documentId,
      name: data['name'] ?? '',
      currentStock: (data['currentStock'] ?? 0).toDouble(),
      unit: data['unit'] ?? '',
      minThreshold: (data['minThreshold'] ?? 0).toDouble(),
    );
  }
}