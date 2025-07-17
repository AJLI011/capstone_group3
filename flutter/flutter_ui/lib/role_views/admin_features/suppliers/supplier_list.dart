import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:shared_preferences/shared_preferences.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  List<dynamic> suppliers = [];
  final String apiUrl = 'http://10.0.2.2:8000/api/suppliers/';
  final String token = 'YOUR_ADMIN_TOKEN_HERE'; // Replace with actual token

  @override
  void initState() {
    super.initState();
    fetchSuppliers();
  }

  Future<void> fetchSuppliers() async {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'Token $token'},
    );
    if (response.statusCode == 200) {
      setState(() {
        suppliers = json.decode(response.body);
      });
    } else {
      print('Failed to fetch suppliers');
    }
  }

  Future<void> addSupplier(String name, String contact) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: json.encode({'name': name, 'contact': contact}),
    );
    if (response.statusCode == 201) {
      fetchSuppliers();
    } else {
      print('Failed to add supplier');
    }
  }

  Future<void> editSupplier(int id, String name, String contact) async {
    final response = await http.put(
      Uri.parse('$apiUrl$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: json.encode({'name': name, 'contact': contact}),
    );
    if (response.statusCode == 200) {
      fetchSuppliers();
    } else {
      print('Failed to update supplier');
    }
  }

  Future<void> deleteSupplier(int id) async {
    final response = await http.delete(
      Uri.parse('$apiUrl$id/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (response.statusCode == 204) {
      fetchSuppliers();
    } else {
      print('Failed to delete supplier');
    }
  }

  void openAddPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          onSubmit: (name, contact) => addSupplier(name, contact),
        ),
      ),
    );
  }

  void openEditPage(int id, String name, String contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          supplierId: id,
          initialName: name,
          initialContact: contact,
          onSubmit: (newName, newContact) =>
              editSupplier(id, newName, newContact),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Back to AdminView
        ),
        title: const Text('Supplier List'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: openAddPage),
        ],
      ),
      body: suppliers.isEmpty
          ? const Center(child: Text('No suppliers found'))
          : ListView.builder(
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                return ListTile(
                  title: Text(supplier['name']),
                  subtitle: Text(supplier['contact']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => openEditPage(
                          supplier['id'],
                          supplier['name'],
                          supplier['contact'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: const Text(
                                  'Are you sure you want to delete this supplier?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            deleteSupplier(supplier['id']);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Fullscreen Add/Edit Page (Reusable)
// ─────────────────────────────────────────────
class SupplierFormPage extends StatefulWidget {
  final int? supplierId;
  final String? initialName;
  final String? initialContact;
  final Function(String name, String contact) onSubmit;

  const SupplierFormPage({
    super.key,
    this.supplierId,
    this.initialName,
    this.initialContact,
    required this.onSubmit,
  });

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  late TextEditingController nameController;
  late TextEditingController contactController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName ?? '');
    contactController =
        TextEditingController(text: widget.initialContact ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final isEdit = widget.supplierId != null;
    final name = nameController.text.trim();
    final contact = contactController.text.trim();

    if (name.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (isEdit) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirm Edit'),
          content: Text('Are you sure you want to save changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Save'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        widget.onSubmit(name, contact);
        Navigator.pop(context);
      }
    } else {
      widget.onSubmit(name, contact);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplierId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Supplier Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: 'Contact Info'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(isEdit ? 'Save Changes' : 'Add Supplier'),
            ),
          ],
        ),
      ),
    );
  }
}
