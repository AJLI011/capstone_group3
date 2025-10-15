import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------

const String _apiUrlBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.6:8000',
);
const Color _primaryColor = Color(0xFF5C7C9A);

// -------------------------------------------------------------------
// Edit Staff Profile Page
// -------------------------------------------------------------------

class EditStaffProfilePage extends StatefulWidget {
  final int staffId;

  const EditStaffProfilePage({super.key, required this.staffId});

  @override
  _EditStaffProfilePageState createState() => _EditStaffProfilePageState();
}

class _EditStaffProfilePageState extends State<EditStaffProfilePage> {
  // --- State & Controllers ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late final TextEditingController _roleController;

  bool _isLoading = true;
  bool _isSaving = false;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contactController = TextEditingController();
    _emailController = TextEditingController();
    _roleController = TextEditingController();
    _fetchStaffData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  // --- API Methods ---

  /// Fetches the current staff data from the API.
  Future<void> _fetchStaffData() async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$_apiUrlBase/api/staff/${widget.staffId}/profile/');
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _nameController.text = data['name'] ?? '';
          _contactController.text = data['contact_num'] ?? '';
          _emailController.text = data['email'] ?? '';
          _roleController.text = data['role'] ?? 'staff';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load profile: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Saves the profile changes to the API.
  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true); // Pop and signal success
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update profile')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong, please try again.')),
        );
      }
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
    Color? readOnlyBackground,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        fillColor: readOnlyBackground,
        filled: readOnlyBackground != null,
      ),
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
                  Text('Loading profile...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextFormField(
                      controller: _nameController,
                      label: "Name",
                      icon: Icons.person_rounded,
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: _contactController,
                      label: "Contact",
                      icon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: _roleController,
                      label: "Role",
                      icon: Icons.badge_rounded,
                      readOnly: true,
                      readOnlyBackground: Colors.grey.shade100,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_rounded,
                      readOnly: true,
                      readOnlyBackground: Colors.grey.shade100,
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