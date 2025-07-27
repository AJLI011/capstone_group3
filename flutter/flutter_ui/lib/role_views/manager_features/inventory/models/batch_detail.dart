class BatchDetail {
  final String batchNumber;
  final String expirationDate;
  final int quantity;
  final double price;
  final String name;
  final String genericName;

  BatchDetail({
    required this.batchNumber,
    required this.expirationDate,
    required this.quantity,
    required this.price,
    required this.name,
    required this.genericName,
  });

  factory BatchDetail.fromJson(Map<String, dynamic> json) {
    return BatchDetail(
      batchNumber: json['batch_num'] ?? '',
      expirationDate: json['exp_date'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
    );
  }
}
