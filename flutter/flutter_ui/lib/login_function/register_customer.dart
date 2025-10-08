// register_customer.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ✅ NEW IMPORT

// ✅ NEW IMPORT FOR FIREBASE MESSAGING
import 'package:firebase_messaging/firebase_messaging.dart';

// Use dart-define to override in different environments
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

  final nameController     = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final contactController  = TextEditingController();

  String errorMsg   = '';
  String successMsg = '';
  bool   isLoading  = false;

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
    setState(() {
      isLoading  = true;
      errorMsg   = '';
      successMsg = '';
    });

    try {
      final url = Uri.parse('$API_BASE/api/register/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name'        : nameController.text.trim(),
          'email'       : emailController.text.trim(),
          'password'    : passwordController.text.trim(),
          'contact_num' : contactController.text.trim(),
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        // ✅ NEW LOGIC: Log in after successful registration to get the customer ID
        // and then save the FCM token.
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
        setState(() => errorMsg = data.toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with back button + Register text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Register",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Registration form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: "Email"),
                      ),
                      TextFormField(
                        controller: contactController,
                        decoration: const InputDecoration(labelText: "Contact Number"),
                      ),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: "Password"),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : registerCustomer,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : const Text("Register"),
                      ),
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