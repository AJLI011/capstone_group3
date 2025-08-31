import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:developer';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const String _baseUrl = 'http://10.0.2.2:8000/api';

// NEW: Data model for OnlineOrderItem
class OnlineOrderItem {
  final String medicineName;
  final int quantitySold;
  final int freeQuantity; // Added new field
  final double priceAtSale;

  OnlineOrderItem({
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantity, // Updated constructor
    required this.priceAtSale,
  });

  factory OnlineOrderItem.fromJson(Map<String, dynamic> json) {
    return OnlineOrderItem(
      medicineName: json['medicine_name'] ?? 'Unknown',
      quantitySold: json['quantity_sold'] ?? 0,
      freeQuantity: json['free_quantity_given'] ?? 0, // Updated factory
      priceAtSale: double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

// NEW: Data model for OnlineOrderDetails
class OnlineOrderDetails {
  final int id;
  final String customerName;
  final String customerEmail;
  final List<OnlineOrderItem> items;

  OnlineOrderDetails({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.items,
  });

  factory OnlineOrderDetails.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List;
    List<OnlineOrderItem> itemsList = list.map((i) => OnlineOrderItem.fromJson(i)).toList();
    return OnlineOrderDetails(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? 'Unknown',
      customerEmail: json['customer_email'] ?? 'Unknown',
      items: itemsList,
    );
  }
}

// Existing InStoreOrderItem model (unchanged)
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

// Existing InStoreOrderDetails model (unchanged)
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

// UPDATED: OrderLog model with dynamic orderDetails field
class OrderLog {
  final int id;
  final String staffName;
  final String staffRole;
  final String actionType;
  final String description;
  final DateTime timestamp;
  final dynamic orderDetails; // Can be InStoreOrderDetails or OnlineOrderDetails

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
    dynamic parsedDetails;
    if (json['order_details'] != null) {
      if (json['order_details'].containsKey('customer_name')) {
        // It's an online order because it has a customer_name
        parsedDetails = OnlineOrderDetails.fromJson(json['order_details']);
      } else if (json['order_details'].containsKey('staff_name')) {
        // It's an in-store order because it has a staff_name
        parsedDetails = InStoreOrderDetails.fromJson(json['order_details']);
      }
    }

    // Get the UTC time from Django's timestamp string.
    final DateTime utcTimestamp = DateTime.parse(json['timestamp']).toUtc();

    // Convert the UTC timestamp to the specific 'Asia/Manila' timezone.
    final location = tz.getLocation('Asia/Manila');
    final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);

    return OrderLog(
      id: json['id'] ?? 0,
      staffName: json['staff_name'] ?? 'Unknown',
      staffRole: json['staff_role'] ?? 'Unknown',
      actionType: json['action_type'] ?? 'Unknown',
      description: json['description'] ?? '',
      timestamp: manilaTimestamp,
      orderDetails: parsedDetails,
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
    // Initialize timezone data
    tz.initializeTimeZones();
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
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
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
              '${log.actionType.replaceAll('_', ' ')} by ${log.staffName}',
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
                    if (log.orderDetails is InStoreOrderDetails)
                      _buildInStoreOrderDetails(log.orderDetails as InStoreOrderDetails)
                    else if (log.orderDetails is OnlineOrderDetails)
                      _buildOnlineOrderDetails(log.orderDetails as OnlineOrderDetails),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInStoreOrderDetails(InStoreOrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('In-Store Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Order ID: #${details.id}'),
        Text('Cashier: ${details.staffName}'),
        const SizedBox(height: 8),
        const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...details.items.map((item) => Text(
          ' - ${item.medicineName} (x${item.quantitySold}) - Php${item.priceAtSale.toStringAsFixed(2)}',
        )).toList(),
      ],
    );
  }

  Widget _buildOnlineOrderDetails(OnlineOrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Online Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Order ID: #${details.id}'),
        Text('Customer: ${details.customerName} (${details.customerEmail})'),
        const SizedBox(height: 8),
        const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...details.items.map((item) {
          String quantityText = ' (x${item.quantitySold})';
          if (item.freeQuantity > 0) {
            quantityText = ' (x${item.quantitySold} + ${item.freeQuantity} Promo)';
          }
          return Text(
            ' - ${item.medicineName}${quantityText} - Php${item.priceAtSale.toStringAsFixed(2)}',
          );
        }).toList(),
      ],
    );
  }
}