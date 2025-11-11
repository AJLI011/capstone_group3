import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------

const String _apiUrlBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: '10.0.2.2:8000',
);
const Color _primaryColor = Color.fromARGB(255, 10, 84, 182);

// -------------------------------------------------------------------
// Edit Customer Profile Page
// -------------------------------------------------------------------

class EditCustomerProfilePage extends StatefulWidget {
  final int customerId;

  const EditCustomerProfilePage({super.key, required this.customerId});

  @override
  _EditCustomerProfilePageState createState() => _EditCustomerProfilePageState();
}

class _EditCustomerProfilePageState extends State<EditCustomerProfilePage> {
  // --- State & Controllers ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;

  bool _isLoading = true;
  bool _isSaving = false;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contactController = TextEditingController();
    _emailController = TextEditingController();
    // Fetch data after the initial frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCustomerData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- Utility Methods ---

  /// Shows a successful SnackBar message.
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Shows an error SnackBar message.
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- API Methods ---

  /// Fetches the current customer data from the API.
  void _fetchCustomerData() async {
    // Basic validation
    if (widget.customerId == 0) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Customer ID not valid. Please log in again.');
      }
      return;
    }

    final url = Uri.parse('$_apiUrlBase/api/customers/${widget.customerId}/');

    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _nameController.text = data['name'] ?? '';
            _contactController.text = data['contact_num'] ?? '';
            _emailController.text = data['email'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Failed to load profile data.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Network error. Check your connection.');
      }
    }
  }

  /// Saves the profile changes to the API.
  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final url = Uri.parse('$_apiUrlBase/api/customers/${widget.customerId}/');
    final body = json.encode({
      'email': _emailController.text.trim(),
      'name': _nameController.text.trim(),
      'contact_num': _contactController.text.trim(),
    });

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (response.statusCode == 200) {
        // Update SharedPreferences on successful save
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customerName', _nameController.text.trim());
        await prefs.setString('customerEmail', _emailController.text.trim());

        _showSuccessSnackBar('Profile updated successfully! 🥳');
        Navigator.pop(context, true);
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showErrorSnackBar('Something went wrong. Could not connect to the server.');
    }
  }

  // --- UI Handler ---

  /// Displays a confirmation dialog before saving.
  Future<void> _confirmSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to save these changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // User cancelled
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // User confirmed
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _saveProfile();
    }
  }

  // --- Helper Widget for consistent input design ---
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        fillColor: readOnly ? Colors.grey.shade100 : Colors.transparent,
        filled: readOnly,
      ),
      keyboardType: label.contains('Contact') ? TextInputType.phone : TextInputType.text,
      validator: validator,
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text('Loading profile...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextFormField(
                      controller: _nameController,
                      label: "Name",
                      icon: Icons.person_rounded,
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: _contactController,
                      label: "Contact Number",
                      icon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_rounded,
                      readOnly: true,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _confirmSaveProfile,
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
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
}