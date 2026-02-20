import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000/',
);

class RegisterCustomer extends StatefulWidget {
  const RegisterCustomer({super.key});

  @override
  State<RegisterCustomer> createState() => _RegisterCustomerState();
}

class _RegisterCustomerState extends State<RegisterCustomer> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final contactController = TextEditingController();

  String errorMsg = '';
  String successMsg = '';
  bool isLoading = false;
  
  // Toggle for password visibility
  bool _obscurePassword = true;

  static const Color primaryBlue = Color(0xFF0050C8);

  // Updated Helper function to include suffixIcon for password toggle
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: icon != null ? Icon(icon, color: primaryBlue.withOpacity(0.7)) : null,
          suffixIcon: suffixIcon,
          labelStyle: TextStyle(color: primaryBlue.withOpacity(0.8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _sendTokenToBackend(String token, int customerId) async {
    try {
      await http.post(
        Uri.parse('$API_BASE/api/customer/save-fcm-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': token,
          'customer_id': customerId,
        }),
      );
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _loginAndSaveToken() async {
    try {
      final url = Uri.parse('$API_BASE/api/login/');
      final response = await http.post(url, body: {
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final customerId = data['id'];
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _sendTokenToBackend(fcmToken, customerId);
        }
      }
    } catch (e) {
      debugPrint('Post-registration login error: $e');
    }
  }

  Future<void> registerCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMsg = '';
      successMsg = '';
    });

    try {
      final url = Uri.parse('$API_BASE/api/register/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text.trim(),
          'contact_num': contactController.text.trim(),
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        await _loginAndSaveToken();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registered successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        final data = json.decode(response.body);
        String displayError = 'Registration failed.';
        if (data is Map) {
          // Specifically look for password validation errors from Django
          if (data.containsKey('password')) {
            displayError = (data['password'] is List) ? data['password'][0] : data['password'].toString();
          } else {
            displayError = data.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
          }
        }
        setState(() => errorMsg = displayError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 12.0, 16.0, 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: primaryBlue),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: primaryBlue),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Sign up to start ordering your medicines.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextFormField(
                        controller: nameController,
                        labelText: "Full Name",
                        icon: Icons.person_outline,
                        validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                      ),
                      _buildTextFormField(
                        controller: emailController,
                        labelText: "Email Address",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                      ),
                      _buildTextFormField(
                        controller: contactController,
                        labelText: "Contact Number",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) => value!.isEmpty ? 'Please enter contact number' : null,
                      ),
                      
                      // PASSWORD SECTION
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "Password length must be 8 characters long with Upper, Lower, Number & Symbol",
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildTextFormField(
                        controller: passwordController,
                        labelText: "Password",
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a password';
                          if (value.length < 8) return 'Password must be at least 8 characters';
                          if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])').hasMatch(value)) {
                            return 'Requirements: 1 Upper, 1 Lower, 1 Number, 1 Symbol';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerCustomer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text("REGISTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account?", style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Login here", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}