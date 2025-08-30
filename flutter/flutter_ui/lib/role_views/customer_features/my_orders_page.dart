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
    final url = 'http://10.0.2.2:8000/api/customer/${widget.customerId}/online-orders/';
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
    final url = 'http://10.0.2.2:8000/api/customer/cancel-online-order/$orderId/';
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

  // ADDED: Function to show a confirmation dialog before canceling an order
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
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
                _cancelOrder(orderId); // Call the cancel function
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
        backgroundColor: const Color.fromARGB(255, 10, 84, 182),// added color to appbar
        foregroundColor: Colors.white, //changed font color
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Set the color of the selected tab text
          unselectedLabelColor: Colors.grey, // Set the color of the unselected tab text
          indicatorColor: const Color.fromARGB(255, 83, 167, 235), // Set the color of the tab indicator
          indicatorWeight: 4.0, // Set the thickness of the tab indicator
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
            // Now include 'ready for pickup' as an ongoing order
            final ongoingOrders = orders.where((order) => order['status'] == 'pending' || order['status'] == 'ready for pickup').toList();
            final pastOrders = orders.where((order) => 
              order['status'] == 'completed' || order['status'] == 'cancelled'
            ).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                // Ongoing Orders Tab
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
                // All Orders Tab
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
    final totalAmount = double.tryParse(order['total_amount_after_discount'].toString()) ?? 0.0;
    // Determine if the order is cancellable (i.e., status is pending)
    final canBeCancelled = order['status'] == 'pending';

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
                ..._buildOrderItems(order['items']),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (canBeCancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton(
                      // MODIFIED: Call the confirmation dialog function instead of the cancel function directly
                      onPressed: () => _confirmCancelOrder(order['id']),
                      style: ElevatedButton.styleFrom(
                        //: Colors.red, // old color
                        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Cancel'),
                    ),
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
      
      // Correctly access the nested medicine data
      final medicine = item['medicine'] as Map<String, dynamic>;
      final medicineName = medicine['name'] ?? 'N/A';
      final genericName = medicine['generic_name'] ?? 'N/A';
      final imageUrl = medicine['image'] ?? '';
      final requiresPrescription = medicine['requires_prescription'] ?? false; // New line

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60),
                ),
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
                  Text(
                    genericName,
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  if (requiresPrescription) // New line
                    const Text(
                      'Prescription Required',
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