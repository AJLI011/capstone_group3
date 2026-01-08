import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String _apiUrlBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://bluewhiteph.pythonanywhere.com',
);
const Color _primaryColor = Color.fromARGB(255, 10, 84, 182);

class ChangeCustomerPasswordPage extends StatefulWidget {
  final int customerId;
  const ChangeCustomerPasswordPage({super.key, required this.customerId});

  @override
  State<ChangeCustomerPasswordPage> createState() => _ChangeCustomerPasswordPageState();
}

class _ChangeCustomerPasswordPageState extends State<ChangeCustomerPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  bool _obscureText = true; // Added for password visibility toggle

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final url = Uri.parse('$_apiUrlBase/api/customer/${widget.customerId}/change-password/');
    final body = json.encode({
      'current_password': _currentPasswordController.text.trim(),
      'new_password': _newPasswordController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['error'] ?? 'Failed to change password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  Future<void> _confirmPasswordChange() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Change'),
        content: const Text('Are you sure you want to change your password?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _changePassword();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      _buildErrorBox(),

                    const Text(
                      "New password must be at least 12 characters and include uppercase, lowercase, numbers, and symbols.",
                      style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),

                    // Current Password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureText,
                      decoration: _buildInputDecoration('Current Password', Icons.lock_rounded),
                      validator: (value) => value!.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 20),

                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureText,
                      decoration: _buildInputDecoration('New Password', Icons.lock_open_rounded),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter a new password';
                        if (value.length < 12) return 'Must be at least 12 characters';
                        
                        // Complexity Check
                        bool hasUpper = value.contains(RegExp(r'[A-Z]'));
                        bool hasLower = value.contains(RegExp(r'[a-z]'));
                        bool hasDigit = value.contains(RegExp(r'[0-9]'));
                        bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                        
                        if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
                          return 'Use uppercase, lowercase, number, & symbol';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureText,
                      decoration: _buildInputDecoration('Confirm New Password', Icons.lock_reset_rounded),
                      validator: (value) {
                        if (value != _newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _confirmPasswordChange,
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('CHANGE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}