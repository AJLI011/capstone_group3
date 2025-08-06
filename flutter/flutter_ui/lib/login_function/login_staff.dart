import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../role_views/admin_view.dart';
import '../role_views/manager_view.dart';
import '../role_views/cashier_view.dart';
import '../role_views/staff_view.dart';
import 'forgot_password.dart';

// Use dart-define to change base URL for different environments.
// Example for production build:
// flutter build apk --release --dart-define=API_BASE=https://api.yoursite.com
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginStaff() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    try {
      final url = Uri.parse('$API_BASE/api/login/');
      final response = await http.post(url, body: {
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
      });

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['user_type'] == 'staff') {
          final role = data['role'];
          final int staffId = data['id'];

          // Save session in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('role', role);
          await prefs.setInt('staff_id', staffId);
          await prefs.setString('name', data['name'] ?? '');
          await prefs.setString('email', data['email'] ?? '');

          // Create employee log for login
          _postEmployeeLog(staffId, 'login');

          Widget destination;
          switch (role) {
            case 'admin':
              destination = AdminView(staffId: staffId);
              break;
            case 'manager':
              destination = ManagerView(staffId: staffId);
              break;
            case 'cashier':
              destination = CashierView(staffId: staffId);
              break;
            case 'staff':
              destination = StaffView(staffId: staffId);
              break;
            default:
              setState(() {
                errorMsg = 'Unknown role: $role';
              });
              return;
          }

          if (!mounted) return;
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
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = 'Network error. Please try again.';
      });
      print('Login error: $e');
    }
  }

  Future<void> _postEmployeeLog(int staffId, String action) async {
    try {
      final logUrl = Uri.parse('$API_BASE/api/employee-logs/');
      final logResp = await http.post(
        logUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'staff': staffId, 'action': action}),
      );

      if (logResp.statusCode != 201 && logResp.statusCode != 200) {
        // optional: non-fatal, but print for debugging
        print('Employee log POST failed: ${logResp.statusCode} ${logResp.body}');
      }
    } catch (e) {
      print('Failed to send employee log: $e');
    }
  }

  // Call this from any logout button in your app to record logout and clear session.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? staffId = prefs.getInt('staff_id');

      if (staffId != null) {
        await _postEmployeeLog(staffId, 'logout');
      }

      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginStaff()),
        (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
