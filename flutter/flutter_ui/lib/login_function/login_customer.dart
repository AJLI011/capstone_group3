// login_customer.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forgot_password.dart';

import '../role_views/customer_view.dart';
import 'register_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_staff.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

const String API_BASE = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.5:8000/',
);

class LoginCustomer extends StatefulWidget {
  const LoginCustomer({super.key});

  @override
  State<LoginCustomer> createState() => _LoginCustomerState();
}

class _LoginCustomerState extends State<LoginCustomer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: SingleChildScrollView( // Changed from Stack to SingleChildScrollView
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Stack( // We can use a stack here to layer the background
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/bg-login.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50), // Spacing from the top
                        // Moved Header inside the Column
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF5C7C9A),
                                Color(0xFF86A5C7)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_rounded, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Customer Login',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 200,
                          width: 200,
                        ),
                        const SizedBox(height: 20),

                        const CustomerLoginForm(),
                        const SizedBox(height: 20),

                        // Staff login
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginStaff(),
                              ),
                            );
                          },
                          child: const Text(
                            'Staff? Click here',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerLoginForm extends StatefulWidget {
  const CustomerLoginForm({super.key});

  @override
  State<CustomerLoginForm> createState() => _CustomerLoginFormState();
}

class _CustomerLoginFormState extends State<CustomerLoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String errorMsg = '';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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

  Future<void> loginCustomer() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    final url = Uri.parse('$API_BASE/api/login/');
    try {
      final response = await http.post(url, body: {
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Login Response: $data');

        if (data['user_type'] == 'customer') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('role', data['user_type']);
          final customerId = data['id'];
          await prefs.setInt('customerId', customerId);
          await prefs.setString('customerName', data['name']);
          await prefs.setString('customerEmail', data['email']);

          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            print('🔑 FCM Token obtained: $fcmToken');
            await _sendTokenToBackend(fcmToken, customerId);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustomerView()),
            );
          }
        } else {
          setState(() => errorMsg = 'Login failed. This email is associated with a staff account. Please use the staff login page.');
        }
      } else {
        final errorData = json.decode(response.body);
        setState(() => errorMsg = errorData['error'] ?? 'Invalid email or password');
      }
    } catch (e) {
      setState(() => errorMsg = 'Network error. Please try again.');
      print('Login Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: 'Email',
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Password',
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterCustomer()),
                );
              },
              child: const Text(
                'Register',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                );
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: isLoading ? null : loginCustomer,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color.fromRGBO(71, 102, 137, 1),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
        ),

        if (errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMsg,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}