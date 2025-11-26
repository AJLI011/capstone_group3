import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'prescription_details_cashier.dart'; // Import the new cashier details screen

class PrescriptionsCashier extends StatefulWidget {
  const PrescriptionsCashier({super.key});

  @override
  State<PrescriptionsCashier> createState() => _PrescriptionsCashierState();
}

class _PrescriptionsCashierState extends State<PrescriptionsCashier> {
  late Future<List<dynamic>> _prescriptionsWithImages;
  
  // This should be your base API URL for the cashier view
  final String apiUrl = "http://192.168.1.4:8000/api/prescriptions/cashier/";

  @override
  void initState() {
    super.initState();
    _prescriptionsWithImages = _fetchPrescriptionsWithImages();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<dynamic>> _fetchPrescriptionsWithImages() async {
    final token = await _getAuthToken();
    // Temporarily disable token check for testing purposes
    // if (token == null) {
    //   throw Exception('Authentication token not found');
    // }

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        // Temporarily disable sending the token for testing
        // 'Authorization': 'Token $token', 
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> allPrescriptions = json.decode(response.body);

      // --- MODIFIED FILTERING LOGIC STARTS HERE ---
      List<dynamic> filteredPrescriptions = allPrescriptions.where((prescription) {
        final hasImages = (prescription['images'] as List).isNotEmpty;
        final orderItems = prescription['order_items'] as List;
        final hasOrderItems = orderItems.isNotEmpty;
        final orderType = prescription['order_type'];
        final orderStatus = prescription['status']; // Assuming 'status' field exists

        // 1. Must have uploaded images to be considered a prescription order
        if (!hasImages) {
            return false;
        }

        // 2. Filter out online orders that have been explicitly cancelled.
        // Assuming 'cancelled' is the status for a cancelled order.
        if (orderType == 'online' && orderStatus == 'cancelled') {
            return false;
        }

        // 3. Filter out orders where all items have been deleted.
        // This is necessary because deleting the last item is another form of "cancellation" 
        // that might not update the 'status' field.
        if (!hasOrderItems) {
            return false;
        }

        // Only show prescriptions that have images, aren't cancelled (if online), and still have items.
        return true; 
        
      }).toList();
      // --- MODIFIED FILTERING LOGIC ENDS HERE ---

      return filteredPrescriptions;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Invalid or expired token');
    } else {
      throw Exception('Failed to load prescriptions: ${response.statusCode}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Orders'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _prescriptionsWithImages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No prescriptions with images found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final prescription = snapshot.data![index];
                final orderId = prescription['order_id'];
                final orderType = prescription['order_type'];
                final name = prescription['staff_or_customer_name'];
                final date = prescription['date_uploaded'];
                // NOTE: Use the API's totalAmount here. The details screen will recalculate it if it's 0.0.
                final totalAmount = prescription['total_amount_after_discount'];
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    // Distinguish order type in the title
                    title: Text(
                      orderType == 'in_store' ? 'In-store Order #$orderId' : 'Online Order #$orderId',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Conditionally display 'Staff' or 'Customer' based on order type
                        if (orderType == 'in_store')
                          Text('Staff: ${name ?? 'N/A'}')
                        else
                          Text('Customer: ${name ?? 'N/A'}'),
                        Text('Date: ${date.substring(0, 10)}'),
                        // Display the total amount. If the API value is 0.0, this will display ₱0.0, 
                        // which signals the issue in the list view, but the details view will be correct.
                        Text('Total: ₱$totalAmount'),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to the view-only details screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrescriptionDetailsCashier(prescription: prescription),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}