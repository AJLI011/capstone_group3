import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PendingOrdersScreen extends StatefulWidget {
  final int cashierId;

  const PendingOrdersScreen({Key? key, required this.cashierId}) : super(key: key);

  @override
  _PendingOrdersScreenState createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  static const String _baseUrl = "http://10.0.2.2:8000";

  late Future<List<InStoreOrder>> _pendingOrders;

  @override
  void initState() {
    super.initState();
    _pendingOrders = _fetchPendingOrders();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _pendingOrders = _fetchPendingOrders();
    });
  }

  Future<List<InStoreOrder>> _fetchPendingOrders() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/sales/pending-orders/'));

    if (response.statusCode == 200) {
      final List<dynamic> ordersJson = json.decode(response.body);
      return ordersJson.map((json) => InStoreOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pending orders');
    }
  }

  Future<void> _processOrder(int orderId, String status) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/sales/pending-orders/$orderId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'cashier_id': widget.cashierId,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been $status.'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.grey,
        ),
      );
      _refreshOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $status order $orderId: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(int orderId, String status) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'Approve Order' : 'Reject Order'),
          content: Text('Are you sure you want to $status order #$orderId?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
              onPressed: () {
                Navigator.of(context).pop();
                _processOrder(orderId, status);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ), 
        ),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<InStoreOrder>>(
        future: _pendingOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending orders found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final order = snapshot.data![index];
                return _buildOrderCard(order);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(InStoreOrder order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff Name
            Text(
              'Initiated by: ${order.staffName} (Staff)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            // List of Items
            ...order.items.map((item) => _buildOrderItem(item)).toList(),
            const SizedBox(height: 16),
            // Totals
            _buildTotalsSection(order),
            const SizedBox(height: 16),
            // Action Buttons
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(InStoreOrderItem item) {
    double itemSubtotal = item.quantitySold * item.priceAtSale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Promo (Qty)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('x${item.quantitySold}'),
              Text(
                item.freeQuantityGiven > 0 ? '${item.freeQuantityGiven}' : '-',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Text(
            '₱${itemSubtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(InStoreOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Text(
                '₱${order.totalAmountBeforeDiscount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Discount (20%):', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Text(
                '₱${(order.totalAmountBeforeDiscount - order.totalAmountAfterDiscount).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              '₱${order.totalAmountAfterDiscount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(InStoreOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog(order.id, 'approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog(order.id, 'rejected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }
}

// Data model classes for InStoreOrder and InStoreOrderItem
class InStoreOrder {
  final int id;
  final String staffName;
  final bool isPwd;
  final double totalAmountBeforeDiscount;
  final double totalAmountAfterDiscount;
  final List<InStoreOrderItem> items;

  InStoreOrder({
    required this.id,
    required this.staffName,
    required this.isPwd,
    required this.totalAmountBeforeDiscount,
    required this.totalAmountAfterDiscount,
    required this.items,
  });

  factory InStoreOrder.fromJson(Map<String, dynamic> json) {
    return InStoreOrder(
      id: json['id'],
      staffName: json['staff_name'],
      isPwd: json['is_pwd'],
      totalAmountBeforeDiscount: double.tryParse(json['total_amount_before_discount']?.toString() ?? '0.0') ?? 0.0,
      totalAmountAfterDiscount: double.tryParse(json['total_amount_after_discount']?.toString() ?? '0.0') ?? 0.0,
      items: (json['items'] as List? ?? [])
          .map((itemJson) => InStoreOrderItem.fromJson(itemJson))
          .toList(),
    );
  }
}

class InStoreOrderItem {
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final double priceAtSale;

  InStoreOrderItem({
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.priceAtSale,
  });

  factory InStoreOrderItem.fromJson(Map<String, dynamic> json) {
    return InStoreOrderItem(
      medicineName: json['medicine_name'],
      quantitySold: json['quantity_sold'],
      freeQuantityGiven: json['free_quantity_given'],
      priceAtSale: double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}