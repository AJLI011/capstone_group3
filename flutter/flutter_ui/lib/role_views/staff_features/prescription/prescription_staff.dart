// In your prescriptions_staff.dart file

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'prescription_details_staff.dart'; // Import the new details screen

class PrescriptionsStaff extends StatefulWidget {
  const PrescriptionsStaff({super.key});

  @override
  State<PrescriptionsStaff> createState() => _PrescriptionsStaffState();
}

class _PrescriptionsStaffState extends State<PrescriptionsStaff> {
  late Future<List<dynamic>> _pendingPrescriptions;
  
  // This should be your base API URL
  final String apiUrl = "http://jallybee.pythonanywhere.com/api/prescriptions/pending/";

  @override
  void initState() {
    super.initState();
    _pendingPrescriptions = _fetchPendingPrescriptions();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token'); // Make sure you save the token with this key
  }

  Future<List<dynamic>> _fetchPendingPrescriptions() async {
    final token = await _getAuthToken();
    // Temporarily disable token check for testing purposes
    // if (token == null) {
    //   throw Exception('Authentication token not found');
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
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Invalid or expired token');
    } else {
      throw Exception('Failed to load pending prescriptions: ${response.statusCode}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Prescriptions'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _pendingPrescriptions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending prescriptions found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final prescription = snapshot.data![index];
                final orderId = prescription['order_id'];
                final orderType = prescription['order_type'];
                final name = prescription['staff_or_customer_name'];
                final date = prescription['date_uploaded'];
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
                        Text('Total: ₱$totalAmount'),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      // Navigate to the details screen and wait for the user to come back
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrescriptionDetailsStaff(prescription: prescription),
                        ),
                      );
                      
                      // When the user returns, re-fetch the list to refresh the UI
                      setState(() {
                        _pendingPrescriptions = _fetchPendingPrescriptions();
                      });
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