import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class MyOrdersPage extends StatefulWidget {
  final int customerId;

  const MyOrdersPage({super.key, required this.customerId});

  @override
  _MyOrdersPageState createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _ordersFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ordersFuture = _fetchCustomerOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchCustomerOrders();
    });
  }

  Future<List<dynamic>> _fetchCustomerOrders() async {
    final url = 'http://192.168.1.21:8000/api/customer/${widget.customerId}/online-orders/';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<void> _cancelOrder(int orderId) async {
    final url = 'http://192.168.1.21:8000/api/customer/cancel-online-order/$orderId/';
    final response = await http.put(Uri.parse(url));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully.')),
      );
      _refreshOrders();
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['detail'] ?? 'Failed to cancel order.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _confirmCancelOrder(int orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: const Text('Are you sure you want to cancel this order?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelOrder(orderId);
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
        title: const Text('My Orders'),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color.fromARGB(255, 83, 167, 235),
          indicatorWeight: 4.0,
          tabs: const [
            Tab(text: 'Ongoing Orders'),
            Tab(text: 'All Orders'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no online orders.'));
          } else {
            final orders = snapshot.data!;
            final ongoingOrders = orders.where((order) => order['status'] == 'pending' || order['status'] == 'ready for pickup').toList();
            final pastOrders = orders.where((order) =>
                order['status'] == 'completed' || order['status'] == 'cancelled'
            ).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: ongoingOrders.isEmpty
                      ? const Center(child: Text('You have no ongoing orders.'))
                      : ListView.builder(
                    itemCount: ongoingOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(ongoingOrders[index]);
                    },
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: pastOrders.isEmpty
                      ? const Center(child: Text('You have no past orders.'))
                      : ListView.builder(
                    itemCount: pastOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(pastOrders[index]);
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final canBeCancelled = order['status'] == 'pending';
    final items = order['items'] as List<dynamic>;

    // Check if the order is cancelled and if all its items are marked as deleted.
    final allItemsDeleted = order['status'] == 'cancelled' && items.every((item) => item['medicine'] != null && (item['medicine']['is_deleted'] ?? false));

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Text('Order #${order['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${order['status'].toString().toUpperCase()}',
              style: TextStyle(
                color: canBeCancelled ? Colors.orange : (order['status'] == 'ready for pickup' ? Colors.blue : Colors.green),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (order.containsKey('pickup_schedule') && order['pickup_schedule'] != null)
              Text(
                'Pickup: ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.parse(order['pickup_schedule']).toLocal())}',
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),

                ..._buildOrderItems(items),

                const SizedBox(height: 16),
                
                // This condition now correctly hides the total amount for cancelled orders with all deleted items.
                if (!allItemsDeleted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${(double.tryParse(order['total_amount_after_discount'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                if (canBeCancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton(
                      onPressed: () => _confirmCancelOrder(order['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                if (allItemsDeleted)
                  const Text(
                    'This order was cancelled because the item/s are no longer available.',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map((item) {
      final quantitySold = int.tryParse(item['quantity_sold'].toString()) ?? 0;
      final freeQuantity = int.tryParse(item['free_quantity_given'].toString()) ?? 0;
      final price = double.tryParse(item['price_at_sale'].toString()) ?? 0.0;
      final itemTotal = price * quantitySold;

      final medicine = item['medicine'];
      final isDeleted = medicine != null && (medicine['is_deleted'] ?? false);

      final medicineName = medicine != null ? medicine['name'] ?? 'N/A' : 'N/A';
      final genericName = medicine != null ? medicine['generic_name'] ?? 'N/A' : 'N/A';
      final imageUrl = isDeleted ? '' : (medicine['image'] ?? '');
      final requiresPrescription = medicine != null ? medicine['requires_prescription'] ?? false : false;

      final imageOrPlaceholder = imageUrl.isNotEmpty
          ? Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.medication, size: 60, color: Colors.grey),
      )
          : const Icon(Icons.medication, size: 60, color: Colors.grey);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: imageOrPlaceholder,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (!isDeleted)
                    Text(
                      genericName,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  if (requiresPrescription)
                    const Text(
                      'Prescription Required',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (isDeleted)
                    const Text(
                      'This item is no longer available.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (freeQuantity > 0)
                    Text(
                      'Quantity: $quantitySold, Promo: $freeQuantity',
                      style: const TextStyle(fontSize: 14),
                    )
                  else
                    Text(
                      'Quantity: $quantitySold',
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
            if (!isDeleted)
              Text(
                '₱${itemTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }).toList();
  }
}