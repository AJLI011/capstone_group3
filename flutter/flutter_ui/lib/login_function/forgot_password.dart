import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otp_input.dart'; // Ensure this file exists in your project

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  String message = '';
  bool isLoading = false;

  static const Color primaryBlue = Color(0xFF0050C8);

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

  // UPDATED LOGIC
  Future<void> sendOtpCode() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => message = 'Please enter your email');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => message = 'Please enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      // Changed to the new send-otp endpoint
      final url = Uri.parse('http://10.0.2.2:8000/api/send-otp/');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'email': email}),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        // Navigate to OTP Screen and pass the email
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpInputScreen(email: email),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          message = errorData['error'] ?? 'No account found with that email';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        message = 'Connection error. Check your server.';
      });
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
                    "Forgot Password",
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
                "Enter your email address to receive a 6-digit verification code.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextFormField(
                      controller: emailController,
                      labelText: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : sendOtpCode, // Changed function name
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: isLoading
                            ? const Center(
                                child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              ))
                            : const Text(
                                'SEND OTP CODE', // Updated text
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}