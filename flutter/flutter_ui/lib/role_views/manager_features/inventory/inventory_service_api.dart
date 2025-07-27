import 'dart:convert';
import 'package:http/http.dart' as http;

import 'medicine.dart';
import 'inventory_item.dart';
import 'total_quantity.dart';


class InventoryApiService {
  static const String baseUrl = 'http://127.0.0.1:8000'; // Change this if needed

  static Future<List<InventoryItem>> fetchInventoryItems() async {
    final url = Uri.parse('$baseUrl/api/inventory/total-quantities/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((item) => InventoryItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load inventory');
    }
  }
}
