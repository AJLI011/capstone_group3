class TotalQuantity {
  final int medicineId;
  final int totalQuantity;

  TotalQuantity({
    required this.medicineId,
    required this.totalQuantity,
  });

  factory TotalQuantity.fromJson(Map<String, dynamic> json) {
    return TotalQuantity(
      medicineId: json['medicine'],
      totalQuantity: json['total_quantity'],
    );
  }
}
