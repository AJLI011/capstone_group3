import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'edit_customer_view.dart';          // <-- new import

//import 'package:shared_preferences/shared_preferences.dart';

// ── Customer model
class Customer {
  final int id;
  final String name;
  final String email;
  final String? contact;

  Customer({required this.id, required this.name, required this.email, this.contact});

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
      id: j['id'],
      name: j['name'],
      email: j['email'],
      contact: j['contact_num'],  // ← FIXED: match the backend
    );

}

// ── Main screen
class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  List<Customer> customers = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    setState(() { isLoading = true; error = ''; });
    try {
      final res = await http.get(Uri.parse('http://10.0.2.2:8000/api/customers/'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        customers = data.map((j) => Customer.fromJson(j)).toList();
      } else {
        error = 'Failed: ${res.statusCode}';
      }
    } catch (e) {
      error = 'Error: $e';
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteCustomer(int id) async {
    final res = await http.delete(Uri.parse('http://10.0.2.2:8000/api/customers/$id/'));
    if (res.statusCode == 204) {
      setState(() => customers.removeWhere((c) => c.id == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
    }
  }

  void confirmDelete(Customer c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete ${c.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); deleteCustomer(c.id); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Customers')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (_, i) {
                    final c = customers[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text('${c.email}\n${c.contact ?? "No contact"}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditCustomerView(
                                    id: c.id,
                                    name: c.name,
                                    email: c.email,
                                    contact: c.contact,
                                  ),
                                ),
                              );
                              if (updated == true) fetchCustomers();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => confirmDelete(c),
                          ),
                        ],
                      ),
                    );

                  },
                ),
    );
  }
}
