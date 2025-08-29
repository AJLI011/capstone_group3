import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffOrdersPage extends StatefulWidget {
  const StaffOrdersPage({super.key});

  @override
  _StaffOrdersPageState createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends State<StaffOrdersPage> with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _ordersFuture;
  late TabController _tabController;
  final String _baseUrl = 'https://aaron.pythonanywhere.com';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ordersFuture = _fetchStaffOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchStaffOrders();
    });
  }

  Future<List<dynamic>> _fetchStaffOrders() async {
    final url = '$_baseUrl/api/staff/online-orders/';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff orders');
    }
  }

  Future<void> _confirmOrder(int orderId) async {
      final url = '$_baseUrl/api/staff/confirm-online-order/$orderId/';
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? staffId = prefs.getInt('staff_id');

      if (staffId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Staff ID is missing.')),
        );
        return;
      }

      final body = jsonEncode({
        'staff_id': staffId,
      });

      try {
        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order confirmed successfully.')),
          );
          _refreshOrders();
        } else {
          final errorBody = jsonDecode(response.body);
          final errorMessage = errorBody['detail'] ?? 'Failed to confirm order.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to the server: $e')),
        );
      }
    }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          indicatorWeight: 4.0,
          tabs: const [
            Tab(text: 'Pending Orders'),
            Tab(text: 'Ready for Pickup'),
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
            return const Center(child: Text('No online orders to display.'));
          } else {
            final orders = snapshot.data!;
            final pendingOrders = orders.where((order) => order['status'] == 'pending').toList();
            
            // Filter ready for pickup orders by date
            List<dynamic> readyForPickupOrders = orders.where((order) => order['status'] == 'ready for pickup').toList();
            if (_selectedDate != null) {
              readyForPickupOrders = readyForPickupOrders.where((order) {
                final pickupDate = DateTime.parse(order['pickup_schedule']).toLocal();
                return pickupDate.year == _selectedDate!.year &&
                       pickupDate.month == _selectedDate!.month &&
                       pickupDate.day == _selectedDate!.day;
              }).toList();
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // Pending Orders Tab
                _buildOrderList(pendingOrders, isPending: true),
                // Ready for Pickup Tab with Date Picker
                _buildReadyForPickupTab(readyForPickupOrders),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildReadyForPickupTab(List<dynamic> orders) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null ? 'Select Pickup Date' : DateFormat('MMMM d, yyyy').format(_selectedDate!),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildOrderList(orders, isPending: false),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {required bool isPending}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(isPending
            ? 'No pending orders.'
            : 'No orders ready for pickup for this date.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], isPending: isPending);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {required bool isPending}) {
    final totalAmount = double.tryParse(order['total_amount_after_discount'].toString()) ?? 0.0;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Text('Order #${order['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order['customer_name'] ?? 'N/A'}'),
            Text('Status: ${order['status'].toString().toUpperCase()}'),
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
                if (isPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton(
                      onPressed: () => _confirmOrder(order['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Confirm Order'),
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
      
      final medicine = item['medicine'] as Map<String, dynamic>;
      final medicineName = medicine['name'] ?? 'N/A';
      final genericName = medicine['generic_name'] ?? 'N/A';
      final imageUrl = medicine['image'] ?? '';
      final requiresPrescription = medicine['requires_prescription'] ?? false;
      
      String fullImageUrl = imageUrl.isNotEmpty && !imageUrl.startsWith('http')
          ? '$_baseUrl$imageUrl'
          : imageUrl;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fullImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  fullImageUrl,
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
                  if (requiresPrescription)
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