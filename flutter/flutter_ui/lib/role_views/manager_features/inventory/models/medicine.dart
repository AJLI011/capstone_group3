class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String category;
  final double price;
  final String image;

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.category,
    required this.price,
    required this.image,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['medicine_id'],
      name: json['name'],
      genericName: json['generic_name'],
      category: json['category'],
      price: (json['price'] ?? 0).toDouble(),
      image: json['image'] ?? '',
    );
  }
}
