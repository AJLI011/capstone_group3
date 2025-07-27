import 'dart:convert';
import 'package:http/http.dart' as http;

import 'total_quantity.dart';
import 'batch_detail.dart';

class InventoryApiService {
  static const String inventoryUrl =
      'http://10.0.2.2:8000/api/inventory/total-quantities/';

  // ✅ Fetch inventory list
  static Future<List<TotalQuantity>> fetchInventoryItems() async {
    try {
      final response = await http.get(Uri.parse(inventoryUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Optionally print for debugging
        // print("Fetched items: ${data.length}");

        return data.map((json) => TotalQuantity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load inventory data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching inventory: $e');
    }
  }

  // ✅ Fetch batch details for a specific medicine
  static Future<List<BatchDetail>> fetchBatchDetails(int medicineId) async {
    final String batchDetailsUrl =
        'http://10.0.2.2:8000/api/inventory/batches/$medicineId/';

    try {
      final response = await http.get(Uri.parse(batchDetailsUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BatchDetail.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load batch details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching batch details: $e');
    }
  }
}
