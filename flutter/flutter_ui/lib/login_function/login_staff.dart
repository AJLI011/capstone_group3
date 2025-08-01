import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../role_views/admin_view.dart';
import '../role_views/manager_view.dart'; // Make sure this is the updated ManagerView
import '../role_views/cashier_view.dart';
import '../role_views/staff_view.dart';
import 'forgot_password.dart'; // Make sure this file exists and is correctly linked

class LoginStaff extends StatefulWidget {
  const LoginStaff({super.key});

  @override
  State<LoginStaff> createState() => _LoginStaffState();
}

class _LoginStaffState extends State<LoginStaff> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String errorMsg = '';

  Future<void> loginStaff() async {
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

      if (data['user_type'] == 'staff') {
        final role = data['role'];
        final int staffId = data['id']; // This is correct, you're getting the ID

        // Save session in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('role', role);
        await prefs.setInt('staff_id', staffId);
        await prefs.setString('name', data['name'] ?? '');
        await prefs.setString('email', data['email'] ?? '');

        print("Saved email: ${data['email']}");

        Widget destination;
        switch (role) {
          case 'admin':
            destination = AdminView(staffId: staffId);
            break;
          case 'manager':
            // --- FIX IS HERE ---
            destination = ManagerView(staffId: staffId); // Pass staffId to ManagerView
            break;
          case 'cashier':
            destination = const CashierView(); // Assuming CashierView doesn't need staffId yet
            break;
          case 'staff':
            destination = StaffView(staffId: staffId); // Assuming StaffView doesn't need staffId yet
            break;
          default:
            setState(() {
              errorMsg = 'Unknown role: $role';
            });
            return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      } else {
        setState(() {
          errorMsg = 'Not a staff account';
        });
      }
    } else {
      setState(() => errorMsg = 'Invalid email or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Staff Email'),
          ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isLoading ? null : loginStaff,
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