import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//import 'package:shared_preferences/shared_preferences.dart';

/// -------------------------------------------------------------------
/// Customer Edit Form View
/// -------------------------------------------------------------------

class EditCustomerView extends StatefulWidget {
  // --- Data (Immutable) ---
  final int id;
  final String name;
  final String email;
  final String? contact;

  const EditCustomerView({
    super.key,
    required this.id,
    required this.name,
    required this.email,
    this.contact,
  });

  @override
  State<EditCustomerView> createState() => _EditCustomerViewState();
}

class _EditCustomerViewState extends State<EditCustomerView> {
  // --- State & Controllers ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const Color _primaryColor = Color(0xFF5C7C9A);
  static const String _apiUrl = 'http://bluewhiteph.pythonanywhere.com/api/customers/';

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;

  bool _isSaving = false;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _contactController = TextEditingController(text: widget.contact ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // --- API Method ---

  /// Sends the PUT request to update the customer data.
  Future<void> _saveChanges() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final url = Uri.parse('$_apiUrl${widget.id}/');
    final body = {
      'name': _nameController.text.trim(),
      // Email must be included in payload, even if uneditable (logic retained)
      'email': _emailController.text.trim(), 
      'contact_num': _contactController.text.trim(),
    };

    try {
      final res = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res.statusCode == 200) {
        // Go back and signal success (true) to refresh the parent list
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer profile updated successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update: Status ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // --- UI Handler ---

  /// Shows confirmation dialog and proceeds to save if confirmed.
  Future<void> _confirmAndSave() async {
    // Validate form before showing confirmation
    if (!_formKey.currentState!.validate()) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Changes',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to save these changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C7C9A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _saveChanges();
    }
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Customer Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Field
              _buildTextFormField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Customer name is required' : null,
              ),
              const SizedBox(height: 24),

              // Contact Number Field
              _buildTextFormField(
                controller: _contactController,
                label: 'Contact Number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                hintText: 'Optional',
              ),
              const SizedBox(height: 24),

              // Email Field (Read-Only)
              _buildTextFormField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_rounded,
                readOnly: true,
                validator: (v) => v!.trim().isEmpty ? 'Email is required' : null,
                readOnlyBackground: Colors.grey.shade100, // Visual hint for read-only
              ),
              const SizedBox(height: 40),

              // Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _confirmAndSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'SAVING...' : 'SAVE CHANGES',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

  // --- Helper Widget for consistent input design ---
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Color? readOnlyBackground,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        fillColor: readOnlyBackground,
        filled: readOnlyBackground != null,
      ),
      validator: validator,
    );
  }
}