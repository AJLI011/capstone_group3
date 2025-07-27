class TotalQuantity {
  final int medicineId; // 
  final String name;
  final String genericName;
  final String image;
  final String category;
  final int totalQuantity;

  TotalQuantity({
    required this.medicineId, 
    required this.name,
    required this.genericName,
    required this.image,
    required this.category,
    required this.totalQuantity,
  });

  factory TotalQuantity.fromJson(Map<String, dynamic> json) {
    return TotalQuantity(
      medicineId: json['medicine_id'], // 👈 This maps the ID from your JSON
      name: json['name'],
      genericName: json['generic_name'],
      image: json['image'] ?? '',
      category: json['category'],
      totalQuantity: json['total_quantity'],
    );
  }
}
