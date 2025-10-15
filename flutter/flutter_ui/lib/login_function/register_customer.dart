// register_customer.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.6:8000/',
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

  // Primary color for the modern look
  static const Color primaryBlue = Color(0xFF0050C8);

  // Helper function for elegant TextFormField design
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    bool obscureText = false,
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
          labelStyle: TextStyle(color: primaryBlue.withOpacity(0.8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Hide default border
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

  // LOGIC FUNCTIONS (Unchanged, for context)

  // ✅ NEW FUNCTION TO SEND TOKEN TO BACKEND
  Future<void> _sendTokenToBackend(String token, int customerId) async {
    print('Attempting to send FCM token to backend...');
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/customer/save-fcm-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': token,
          'customer_id': customerId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ FCM token successfully sent and saved on backend.');
      } else {
        print('❌ Failed to save FCM token. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error during HTTP request to save FCM token: $e');
    }
  }

  // ✅ NEW HELPER FUNCTION TO LOG IN AND SAVE TOKEN
  Future<void> _loginAndSaveToken() async {
    print('Attempting to login to get customer ID...');
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
          print('🔑 FCM Token obtained: $fcmToken');
          await _sendTokenToBackend(fcmToken, customerId);
        }
      } else {
        print('❌ Failed to log in after registration. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error during post-registration login: $e');
    }
  }

  Future<void> registerCustomer() async {
    if (!_formKey.currentState!.validate()) return; // Added form validation check

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

        setState(() {
          successMsg = 'Registered successfully! You may now log in.';
          nameController.clear();
          emailController.clear();
          passwordController.clear();
          contactController.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Pop back to the login screen
        }
      } else {
        final data = json.decode(response.body);
        // Better error message extraction for user readability
        String displayError = 'Registration failed. Please check your details.';
        if (data is Map && data.containsKey('email') && data['email'] is List) {
          displayError = 'Email: ${data['email'][0]}';
        } else if (data is Map) {
          displayError = data.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
        }

        setState(() => errorMsg = displayError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Registration Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  // UI LAYOUT (Enhanced)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 12.0, 16.0, 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: primaryBlue),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Sign up to start ordering your medicines.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Registration Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
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
                        validator: (value) => value!.isEmpty ? 'Please enter your contact number' : null,
                      ),
                      _buildTextFormField(
                        controller: passwordController,
                        labelText: "Password",
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      
                      const SizedBox(height: 32),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerCustomer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: isLoading
                              ? const Center(child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                ))
                              : const Text(
                                  "REGISTER",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Login prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Login here",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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