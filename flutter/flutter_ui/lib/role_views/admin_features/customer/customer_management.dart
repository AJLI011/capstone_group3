// customer_management.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// NOTE: The import for 'edit_customer_view.dart' is removed.

// -------------------------------------------------------------------
// Customer Data Model
// -------------------------------------------------------------------

class Customer {
  final int id;
  final String name;
  final String email;
  final String? contact;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    this.contact,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        contact: j['contact_num'] as String?,
      );
}

// -------------------------------------------------------------------
// Customer List and Management Screen
// -------------------------------------------------------------------

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  // --- State & Constants ---
  List<Customer> customers = [];
  bool _isLoading = true;
  String _error = '';
  static const Color _primaryColor = Color(0xFF5C7C9A);
  static const String _apiUrl = 'http://192.168.1.4:8000/api/customers/';

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  // --- API Method (Only Fetch remains) ---

  /// Fetches the list of all customers.
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await http.get(Uri.parse(_apiUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        customers = data.map((j) => Customer.fromJson(j)).toList();
      } else {
        _error = 'Failed to load customers: ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Network Error: $e';
    }
    setState(() => _isLoading = false);
  }

  // NOTE: All deletion/editing methods (_deleteCustomer, _confirmDelete, _navigateToEdit) are removed.

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Profiles',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text('Loading customers...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                'An error occurred: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchCustomers,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (customers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No customer records found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // List View for Customers (View Only)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (_, i) {
        final c = customers[i];
        return ListTile(
          // onTap: is removed to prevent navigation/editing.
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: CircleAvatar(
            backgroundColor: _primaryColor.withOpacity(0.1),
            child: Text(
              c.name[0].toUpperCase(),
              style: const TextStyle(
                  color: _primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            c.name,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.email, style: TextStyle(color: Colors.grey[600])),
              Text(
                c.contact ?? 'No contact number provided',
                style: TextStyle(
                  color: c.contact == null ? Colors.orange : Colors.grey[600],
                  fontStyle: c.contact == null ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
          // trailing: is removed, thus removing the Edit/Delete buttons.
        );
      },
    );
  }
}