import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forgot_password.dart';

import '../role_views/customer_view.dart';
import 'register_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_staff.dart';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

class LoginCustomer extends StatefulWidget {
  const LoginCustomer({super.key});

  @override
  State<LoginCustomer> createState() => _LoginCustomerState();
}

class _LoginCustomerState extends State<LoginCustomer> {
  bool showRegister = false;

  @override
  Widget build(BuildContext context) {
    // FIX: Wrapped the entire Stack in a Scaffold to provide the Material context.
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: The full-screen background image
          Positioned.fill(
            child: Image.asset(
              'assets/bg-login.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Layer 2: The scrollable content for the entire screen
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    // The logo
                    Image.asset(
                      'assets/logo.png',
                      height: 200,
                      width: 200,
                    ),
                    const SizedBox(height: 20),
                    
                    // The original login/register toggle buttons
                    ToggleButtons(
                      isSelected: [!showRegister, showRegister],
                      onPressed: (index) {
                        setState(() => showRegister = index == 1);
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Login'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Register'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // The login or register form based on the state
                    showRegister
                        ? const RegisterCustomer()
                        : const CustomerLoginForm(),
                    
                    // The "Staff?" button is now inside the scrollable view
                    const SizedBox(height: 20),
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
            ),
          ),
        ],
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

          await prefs.setInt('customerId', data['id']);
          await prefs.setString('customerName', data['name']);
          await prefs.setString('customerEmail', data['email']);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustomerView()),
            );
          }
        } else {
          setState(() => errorMsg = 'Unsupported user type.');
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
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
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