// flutter_ui/lib/role_views/manager_features/order_logs/order_logs.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:developer';

const String _baseUrl = 'http://10.0.2.2:8000/api';

// Data model for InStoreOrderItem
class InStoreOrderItem {
  final String medicineName;
  final int quantitySold;
  final double priceAtSale;

  InStoreOrderItem({
    required this.medicineName,
    required this.quantitySold,
    required this.priceAtSale,
  });

  factory InStoreOrderItem.fromJson(Map<String, dynamic> json) {
    return InStoreOrderItem(
      medicineName: json['medicine_name'] ?? 'Unknown',
      quantitySold: json['quantity_sold'] ?? 0,
      priceAtSale: double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

// Data model for InStoreOrderDetails
class InStoreOrderDetails {
  final int id;
  final String staffName;
  final List<InStoreOrderItem> items;

  InStoreOrderDetails({
    required this.id,
    required this.staffName,
    required this.items,
  });

  factory InStoreOrderDetails.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List;
    List<InStoreOrderItem> itemsList = list.map((i) => InStoreOrderItem.fromJson(i)).toList();
    return InStoreOrderDetails(
      id: json['id'] ?? 0,
      staffName: json['staff_name'] ?? 'Unknown',
      items: itemsList,
    );
  }
}

// Data model for OrderLog
class OrderLog {
  final int id;
  final String staffName;
  final String staffRole;
  final String actionType;
  final String description;
  final DateTime timestamp;
  final InStoreOrderDetails? orderDetails;

  OrderLog({
    required this.id,
    required this.staffName,
    required this.staffRole,
    required this.actionType,
    required this.description,
    required this.timestamp,
    this.orderDetails,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    return OrderLog(
      id: json['id'] ?? 0,
      staffName: json['staff_name'] ?? 'Unknown',
      staffRole: json['staff_role'] ?? 'Unknown',
      actionType: json['action_type'] ?? 'Unknown',
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      orderDetails: json['in_store_order_details'] != null
          ? InStoreOrderDetails.fromJson(json['in_store_order_details'])
          : null,
    );
  }
}

class OrderLogsScreen extends StatefulWidget {
  const OrderLogsScreen({super.key});

  @override
  _OrderLogsScreenState createState() => _OrderLogsScreenState();
}

class _OrderLogsScreenState extends State<OrderLogsScreen> {
  late Future<List<OrderLog>> _futureOrderLogs;

  @override
  void initState() {
    super.initState();
    _futureOrderLogs = fetchOrderLogs();
  }

  Future<List<OrderLog>> fetchOrderLogs() async {
    final url = Uri.parse('$_baseUrl/order-logs/');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      log('API Response Status: ${response.statusCode}');
      log('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> logsJson = json.decode(response.body);
        return logsJson.map((json) => OrderLog.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load order logs: ${response.statusCode}');
      }
    } catch (e) {
      log('Error during API call: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Logs'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: FutureBuilder<List<OrderLog>>(
        future: _futureOrderLogs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No order logs found.'));
          } else {
            return _buildOrderLogsList(snapshot.data!);
          }
        },
      ),
    );
  }

  Widget _buildOrderLogsList(List<OrderLog> logs) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ExpansionTile(
            title: Text(
              '${log.actionType} by ${log.staffName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('yyyy-MM-dd h:mm a').format(log.timestamp)),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description: ${log.description}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    if (log.orderDetails != null) ...[
                      const Text('Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Order ID: #${log.orderDetails!.id}'),
                      Text('Cashier: ${log.orderDetails!.staffName}'),
                      const SizedBox(height: 8),
                      const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...log.orderDetails!.items.map((item) => Text(
                        ' - ${item.medicineName} (x${item.quantitySold}) - Php${item.priceAtSale.toStringAsFixed(2)}',
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}