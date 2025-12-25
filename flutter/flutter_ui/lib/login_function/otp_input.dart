import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'password_input.dart'; // We will create this next

class OtpInputScreen extends StatefulWidget {
  final String email;
  const OtpInputScreen({super.key, required this.email});

  @override
  State<OtpInputScreen> createState() => _OtpInputScreenState();
}

class _OtpInputScreenState extends State<OtpInputScreen> {
  final otpController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  static const Color primaryBlue = Color(0xFF0050C8);

  Future<void> verifyOtp() async {
    if (otpController.text.length < 6) {
      setState(() => errorMessage = "Please enter the 6-digit code");
      return;
    }

    setState(() => isLoading = true);

    try {
      // Note: Using a logic-only verify check or just passing data to the next screen.
      // For best UX, we verify the OTP here before moving to the password screen.
      final url = Uri.parse('http://10.0.2.2:8000/api/reset-password/'); // We reuse the endpoint or create a verify-only one
      
      // We will actually just pass the OTP to the next screen to perform the reset in one final call, 
      // but let's do a "soft" check here or just navigate.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordInputScreen(
            email: widget.email,
            otpCode: otpController.text.trim(),
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Verify OTP"), foregroundColor: primaryBlue, backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text("Enter the code sent to ${widget.email}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: "6-Digit Code",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                child: const Text("CONTINUE", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}