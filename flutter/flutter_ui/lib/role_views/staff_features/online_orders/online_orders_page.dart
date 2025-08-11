import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class OnlineOrdersPage extends StatefulWidget {
  const OnlineOrdersPage({super.key});

  @override
  State<OnlineOrdersPage> createState() => _OnlineOrdersPageState();
}

class _OnlineOrdersPageState extends State<OnlineOrdersPage> {
  List<dynamic> _ongoingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOngoingOrders();
  }

  Future<void> _fetchOngoingOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // You may need to adjust this URL to your actual API endpoint for fetching ongoing orders
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/orders/?status=ongoing'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _ongoingOrders = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while fetching orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmOrder(int orderId) async {
    final confirmedStatus = 'ready for pickup'; // The new status

    try {
      final response = await http.patch(
        Uri.parse('http://10.0.2.2:8000/api/orders/$orderId/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'status': confirmedStatus,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order confirmed and set to "ready for pickup".'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list after successful confirmation
        _fetchOngoingOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm order: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Online Orders"),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ongoingOrders.isEmpty
              ? const Center(child: Text("No ongoing orders found."))
              : ListView.builder(
                  itemCount: _ongoingOrders.length,
                  itemBuilder: (context, index) {
                    final order = _ongoingOrders[index];
                    final pickupSchedule = DateTime.parse(order['pickup_schedule']);

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order ID: ${order['id']}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text("Customer ID: ${order['customer']}"),
                            Text(
                              "Scheduled for: ${DateFormat('MM-dd-yyyy hh:mm a').format(pickupSchedule)}",
                            ),
                            Text(
                              "Total: ₱${(order['total_price'] ?? 0.0).toStringAsFixed(2)}",
                            ),
                            const SizedBox(height: 10),
                            // Button to confirm the order
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _confirmOrder(order['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Confirm Order"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}