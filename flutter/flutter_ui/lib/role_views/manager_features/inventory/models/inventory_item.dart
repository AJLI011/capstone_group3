import 'medicine.dart';

class InventoryItem {
  final int id;
  final Medicine medicine;

  InventoryItem({
    required this.id,
    required this.medicine,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      medicine: Medicine.fromJson(json['medicine']),
    );
  }
}
