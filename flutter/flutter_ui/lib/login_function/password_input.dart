import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PasswordInputScreen extends StatefulWidget {
  final String email;
  final String otpCode;

  const PasswordInputScreen({
    super.key,
    required this.email,
    required this.otpCode,
  });

  @override
  State<PasswordInputScreen> createState() => _PasswordInputScreenState();
}

class _PasswordInputScreenState extends State<PasswordInputScreen> {
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  String _message = '';

  static const Color primaryBlue = Color(0xFF0050C8);

  Future<void> _resetPassword() async {
    final password = _passController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    // 1. Validation
    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _message = 'Please fill in all fields');
      return;
    }

    if (password.length < 8) {
      setState(() => _message = 'Password must be at least 8 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _message = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // 2. Final API Call to your Django backend
      final url = Uri.parse('http://10.0.2.2:8000/api/reset-password/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp_code': widget.otpCode,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccessDialog();
      } else {
        setState(() => _message = data['error'] ?? 'Failed to reset password');
      }
    } catch (e) {
      setState(() => _message = 'Connection error. Is the server running?');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Your password has been reset successfully. Please login with your new password.'),
        actions: [
          TextButton(
            onPressed: () {
              // Pop all the way back to the Login screen
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('LOG IN NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Password"),
        foregroundColor: primaryBlue,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Set your new password below.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Password Field
            TextField(
              controller: _passController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: "New Password",
                prefixIcon: const Icon(Icons.lock_outline, color: primaryBlue),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Confirm Password Field
            TextField(
              controller: _confirmPassController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                prefixIcon: const Icon(Icons.lock_reset, color: primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            const SizedBox(height: 32),

            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_message, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("RESET PASSWORD", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}