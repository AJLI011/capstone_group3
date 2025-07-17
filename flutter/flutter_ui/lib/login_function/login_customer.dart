import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forgot_password.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../role_views/customer_view.dart';
import 'register_customer.dart';

class LoginCustomer extends StatefulWidget {
  const LoginCustomer({super.key});
  @override
  State<LoginCustomer> createState() => _LoginCustomerState();
}

class _LoginCustomerState extends State<LoginCustomer> {
  bool showRegister = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final role = prefs.getString('role');

    if (isLoggedIn && role == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerView()),
      );
    }
  }

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
        Expanded(
          child: showRegister
              ? const RegisterCustomer()
              : const CustomerLoginForm(),
        ),
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

Future<void> loginCustomer() async {
  setState(() {
    isLoading = true;
    errorMsg = '';
  });

  final url = Uri.parse('http://10.0.2.2:8000/api/login/');
  final response = await http.post(url, body: {
    'email': emailController.text.trim(),
    'password': passwordController.text.trim(),
  });

  setState(() => isLoading = false);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['user_type'] == 'customer') {
      // ✅ Save login state and role
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('role', 'customer');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerView()),
      );
    }
  } else {
    setState(() => errorMsg = 'Invalid email or password');
  }
}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
