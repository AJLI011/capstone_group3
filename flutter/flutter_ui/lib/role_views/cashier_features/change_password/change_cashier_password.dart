import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// -------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------

const String _apiUrlBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://bluewhiteph.pythonanywhere.com',
);
const Color _primaryColor = Color(0xFF5C7C9A);

// -------------------------------------------------------------------
// Change Cashier Password Page
// -------------------------------------------------------------------

class ChangeCashierPasswordPage extends StatefulWidget {
  final int staffId;

  const ChangeCashierPasswordPage({super.key, required this.staffId});

  @override
  State<ChangeCashierPasswordPage> createState() => _ChangeCashierPasswordPageState();
}

class _ChangeCashierPasswordPageState extends State<ChangeCashierPasswordPage> {
  // --- State & Controllers ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  bool _obscureText = true; // Added for password visibility toggle

  // --- Lifecycle ---
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- API Method ---

  Future<void> _changePassword() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final url = Uri.parse('$_apiUrlBase/api/staff/${widget.staffId}/change-password/');
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
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
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

  // --- UI Handler ---

  Future<void> _confirmPasswordChange() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Password Change', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to change your password?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _changePassword();
    }
  }

  // Helper for Input Decoration to avoid repetition
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, color: _primaryColor),
      suffixIcon: IconButton(
        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text('Changing password...', style: TextStyle(color: Colors.grey)),
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
                    if (_errorMessage != null)
                      _buildErrorBox(),
                    
                    const Text(
                      "Note: New password must be at least 12 characters and include upper, lower, numbers, and symbols.",
                      style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                      
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: _buildInputDecoration('Current Password', Icons.lock_rounded),
                      obscureText: _obscureText,
                      validator: (value) => value!.isEmpty ? 'Please enter your current password' : null,
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _newPasswordController,
                      decoration: _buildInputDecoration('New Password', Icons.lock_open_rounded),
                      obscureText: _obscureText,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a new password';
                        if (value.length < 12) return 'Password must be at least 12 characters long';
                        
                        // Complexity Check
                        bool hasUpper = value.contains(RegExp(r'[A-Z]'));
                        bool hasLower = value.contains(RegExp(r'[a-z]'));
                        bool hasDigit = value.contains(RegExp(r'[0-9]'));
                        bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                        
                        if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
                          return 'Use upper, lower, number, & symbol';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: _buildInputDecoration('Confirm New Password', Icons.lock_reset_rounded),
                      obscureText: _obscureText,
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _confirmPasswordChange,
                      icon: const Icon(Icons.key_rounded),
                      label: const Text(
                        'CHANGE PASSWORD',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
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
    );
  }
}