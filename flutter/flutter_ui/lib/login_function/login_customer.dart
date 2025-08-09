import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forgot_password.dart';

import '../role_views/customer_view.dart';
import 'register_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Column(
      children: [
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
        const SizedBox(height: 10),
        // Removed the Expanded widget here
        showRegister
            ? const RegisterCustomer()
            : const CustomerLoginForm(),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        // The key change to align the fields at the top
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isLoading ? null : loginCustomer,
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Login'),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: const Text('Forgot Password?'),
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
      ),
    );
  }
}