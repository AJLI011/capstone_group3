import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:shared_preferences/shared_preferences.dart'; // Retained commented import

/// -------------------------------------------------------------------
/// Supplier List Main Page
/// -------------------------------------------------------------------

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  // --- Data & API Endpoints ---
  List<dynamic> suppliers = [];
  final String _apiUrl = 'http://192.168.1.11:8000/api/suppliers/';
  // NOTE: In a production app, the token should be secured, not hardcoded.
  final String _token = 'YOUR_ADMIN_TOKEN_HERE'; 

  // --- Lifecycle & Initialization ---
  @override
  void initState() {
    super.initState();
    _fetchSuppliers(); // Use leading underscore for private methods
  }

  // ----------------------------------------------------------------------
  // ⬇️ NEW: Snackbar Utility Method
  // ----------------------------------------------------------------------
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // ----------------------------------------------------------------------

  // --- API Methods ---

  /// Fetches the list of suppliers from the backend API.
  Future<void> _fetchSuppliers() async {
    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {'Authorization': 'Token $_token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        suppliers = json.decode(response.body);
      });
    } else {
      // Use proper error handling, e.g., show a Snackbar or error state
      debugPrint('Failed to fetch suppliers: ${response.statusCode}'); 
    }
  }

  /// Adds a new supplier to the backend.
  Future<void> _addSupplier(String name, String contact) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: json.encode({'name': name, 'contact': contact}),
    );

    if (response.statusCode == 201) {
      // Success, refresh the list
      await _fetchSuppliers(); 
      _showSnackbar('Supplier "$name" added successfully.');
    } else {
      debugPrint('Failed to add supplier: ${response.statusCode}');
      _showSnackbar('Failed to add supplier.');
    }
  }

  /// Edits an existing supplier via their ID.
  Future<void> _editSupplier(int id, String name, String contact) async {
    final response = await http.put(
      Uri.parse('$_apiUrl$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: json.encode({'name': name, 'contact': contact}),
    );

    if (response.statusCode == 200) {
      // Success, refresh the list
      await _fetchSuppliers();
      _showSnackbar('Supplier "$name" updated successfully.');
    } else {
      debugPrint('Failed to update supplier: ${response.statusCode}');
      _showSnackbar('Failed to update supplier.');
    }
  }

  /// Deletes a supplier using their ID.
  Future<void> _deleteSupplier(int id) async {
    // ----------------------------------------------------------------------
    // ⬇️ MODIFIED: Capture supplier name before deletion for the Snackbar
    // ----------------------------------------------------------------------
    final int index = suppliers.indexWhere((s) => s['id'] == id);
    final String deletedName = (index != -1) ? suppliers[index]['name'] : 'Supplier';
    // ----------------------------------------------------------------------
    
    final response = await http.delete(
      Uri.parse('$_apiUrl$id/'),
      headers: {'Authorization': 'Token $_token'},
    );

    if (response.statusCode == 204) {
      // Success (No Content), refresh the list
      await _fetchSuppliers();
      // ----------------------------------------------------------------------
      // ⬇️ NEW: Show simple success Snackbar
      // ----------------------------------------------------------------------
      _showSnackbar('$deletedName deleted successfully.');
      // ----------------------------------------------------------------------
    } else {
      debugPrint('Failed to delete supplier: ${response.statusCode}');
      // ----------------------------------------------------------------------
      // ⬇️ NEW: Show error Snackbar
      // ----------------------------------------------------------------------
      _showSnackbar('Failed to delete $deletedName.');
      // ----------------------------------------------------------------------
    }
  }

  // --- Navigation & UI Handlers ---

  void _openAddPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          onSubmit: (name, contact) => _addSupplier(name, contact),
        ),
      ),
    );
  }

  void _openEditPage(int id, String name, String contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormPage(
          supplierId: id,
          initialName: name,
          initialContact: contact,
          onSubmit: (newName, newContact) =>
              _editSupplier(id, newName, newContact),
        ),
      ),
    );
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    // Define a modern, formal color palette
    const Color primaryColor = Color(0xFF5C7C9A); // A clean slate-blue/gray
    const Color accentColor = Color(0xFF007BFF); // A subtle, standard blue for actions
    const Color deleteColor = Colors.redAccent;
    const Color editColor = Colors.orangeAccent;

    return Scaffold(
      appBar: AppBar(
        // Use an elevated, subtle app bar for a modern look
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4, // Subtle shadow
        title: const Text(
          'Supplier Management',
          style: TextStyle(fontWeight: FontWeight.w600), // Slightly bolder title
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), // Modern back icon
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded), // A more specific icon for "Add"
            onPressed: _openAddPage,
            tooltip: 'Add New Supplier',
          ),
          const SizedBox(width: 8), // Added spacing
        ],
      ),
      body: suppliers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No supplier records found. Tap the (+) icon to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          : ListView.separated( // Use ListView.separated for clean division lines
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: suppliers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1, 
                indent: 16, 
                endIndent: 16, 
                color: Color(0xFFE0E0E0), // Light divider color
              ),
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                return InkWell( // Use InkWell for a slight tap effect on the whole tile
                  onTap: () => _openEditPage(
                      supplier['id'], supplier['name'], supplier['contact']),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Text(
                        supplier['name'][0].toUpperCase(),
                        style: TextStyle(
                            color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      supplier['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                    subtitle: Text(
                      supplier['contact'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        IconButton(
                          icon: Icon(Icons.edit_note_rounded, color: editColor),
                          tooltip: 'Edit Supplier',
                          onPressed: () => _openEditPage(
                            supplier['id'],
                            supplier['name'],
                            supplier['contact'],
                          ),
                        ),
                        // Delete Button
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              color: deleteColor),
                          tooltip: 'Delete Supplier',
                          onPressed: () => _showDeleteConfirmation(
                              context, supplier['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Extracts the delete confirmation logic to a separate, clean function.
  Future<void> _showDeleteConfirmation(BuildContext context, int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text(
            'Are you sure you want to permanently delete this supplier record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton( // Used an elevated button for the primary, destructive action
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteSupplier(id);
    }
  }
}

// ───────────────────────────────────────────────────────────────────
// Supplier Add/Edit Form Page (Reusable)
// ───────────────────────────────────────────────────────────────────

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
  // Use a GlobalKey for form validation (better practice for forms)
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); 

  late TextEditingController _nameController;
  late TextEditingController _contactController;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _contactController =
        TextEditingController(text: widget.initialContact ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // --- Handler ---
  Future<void> _handleSubmit() async {
    // Basic validation check
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final bool isEdit = widget.supplierId != null;
    final String name = _nameController.text.trim();
    final String contact = _contactController.text.trim();

    // Determine confirmation dialog details
    final String dialogTitle = isEdit ? 'Save Changes' : 'Confirm Add';
    final String dialogContent = isEdit
        ? 'Are you sure you want to save these changes?'
        : 'Are you sure you want to add this new supplier?';
    final String actionText = isEdit ? 'Save' : 'Add Supplier';
    final Color actionColor = isEdit ? const Color(0xFF5C7C9A) : Colors.green;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dialogTitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onSubmit(name, contact);
      // Navigate back only after successful action
      if (mounted) Navigator.pop(context); 
    }
  }
  
  // --- Widget Build ---
  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.supplierId != null;
    const Color primaryColor = Color(0xFF5C7C9A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        title: Text(
          isEdit ? 'Edit Supplier' : 'Add New Supplier',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24), // Use a close icon for modal form
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form( // Wrapped fields in a Form widget
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch button/fields
            children: [
              // Supplier Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name',
                  border: OutlineInputBorder(), // Modern outlined input
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a supplier name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Contact Info Field
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.text, // Assuming contact can be phone/email/etc
                decoration: const InputDecoration(
                  labelText: 'Contact Information',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.contact_mail_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter contact information';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              // Submission Button
              ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: Icon(isEdit ? Icons.save_rounded : Icons.add_circle_rounded),
                label: Text(
                  isEdit ? 'SAVE CHANGES' : 'ADD SUPPLIER',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEdit ? primaryColor : Colors.green[600],
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Slightly rounded button
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}