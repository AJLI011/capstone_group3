import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  String message = '';
  bool isLoading = false;

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => message = 'Please enter your email');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    // final url = Uri.parse('https://aaron.pythonanywhere.com/api/forgot-password/');
    final url = Uri.parse('http://bluewhiteph.pythonanywhere.com/api/forgot-password/');
    final response = await http.post(url, body: {'email': email});

    setState(() => isLoading = false);

    if (response.statusCode == 200) {
      setState(() {
        message = 'Reset link sent to your email. Check your inbox.';
      });
    } else {
      setState(() {
        message = 'No account found with that email';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // ✅ match Register screen
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row with Back Button + Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Forgot Password",
                    style: TextStyle(
                      fontSize: 22, // ✅ same as Register
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Email Input + Button
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isLoading ? null : sendResetLink,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50), // ✅ consistency
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Send Reset Link'),
                    ),

                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: message.contains('sent')
                                ? Colors.green
                                : Colors.red,
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
