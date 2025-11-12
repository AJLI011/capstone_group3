import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------

const String _apiUrlBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.12:8000',
);
const Color _primaryColor = Color(0xFF5C7C9A);

// -------------------------------------------------------------------
// Edit Manager Profile Page
// -------------------------------------------------------------------

class EditManagerProfilePage extends StatefulWidget {
  final int staffId;

  const EditManagerProfilePage({super.key, required this.staffId});

  @override
  _EditManagerProfilePageState createState() => _EditManagerProfilePageState();
}

class _EditManagerProfilePageState extends State<EditManagerProfilePage> {
  // --- State & Controllers ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late final TextEditingController _roleController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contactController = TextEditingController();
    _emailController = TextEditingController();
    _roleController = TextEditingController();
    // Fetch data after the initial frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchManagerData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _roleController.dispose();
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

  // --- API Methods ---

  /// Fetches the current manager data from the API.
  void _fetchManagerData() async {
    // Basic validation
    if (widget.staffId == 0) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Staff ID not valid. Please log in again.');
      }
      return;
    }

    final url = Uri.parse('$_apiUrlBase/api/staff/${widget.staffId}/profile/');

    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _nameController.text = data['name'] ?? '';
            _contactController.text = data['contact_num'] ?? '';
            _emailController.text = data['email'] ?? '';
            _roleController.text = data['role'] ?? 'Manager';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showError('Failed to load profile data.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Network error. Check your connection.');
      }
    }
  }

  /// Saves the profile changes to the API.
  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    setState(() => _errorMessage = null);

    final url = Uri.parse('$_apiUrlBase/api/staff/${widget.staffId}/update-profile/');
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
        final data = json.decode(response.body);
        final updatedStaffData = data['staff'];

        if (updatedStaffData != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', updatedStaffData['name'] ?? _nameController.text.trim());
          await prefs.setString('email', updatedStaffData['email'] ?? _emailController.text.trim());
        }

        _showSuccessSnackBar('Profile updated successfully! 🥳');
        Navigator.pop(context, true);
      } else {
        final data = json.decode(response.body);
        _showError(data['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Something went wrong. Could not connect to the server.');
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
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
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
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
                      controller: _roleController,
                      label: "Role",
                      icon: Icons.badge_rounded,
                      readOnly: true,
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