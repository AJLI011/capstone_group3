// login_staff.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../role_views/admin_view.dart';
import '../role_views/manager_view.dart';
import '../role_views/cashier_view.dart';
import '../role_views/staff_view.dart';
import 'forgot_password.dart';
import 'login_customer.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

const String API_BASE = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.21:8000/',
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

  Future<void> _sendTokenToBackend(String token, int staffId) async {
    print('Attempting to send FCM token to backend for staff...');
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/save-staff-fcm-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': token,
          'staff_id': staffId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ FCM token successfully sent and saved on backend for staff.');
      } else {
        print('❌ Failed to save FCM token for staff. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error during HTTP request to save FCM token for staff: $e');
    }
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

          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            print('🔑 FCM Token obtained for staff: $fcmToken');
            await _sendTokenToBackend(fcmToken, staffId);
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('role', role);
          await prefs.setInt('staff_id', staffId);
          await prefs.setString('name', data['name'] ?? '');
          await prefs.setString('email', data['email'] ?? '');

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
        final errorData = json.decode(response.body);
        setState(() => errorMsg = errorData['error'] ?? 'Invalid email or password');
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
        print('Employee log POST failed: ${logResp.statusCode} ${logResp.body}');
      }
    } catch (e) {
      print('Failed to send employee log: $e');
    }
  }

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
    return Scaffold(
      body: SizedBox.expand(
        child: SingleChildScrollView( // Changed from Stack to SingleChildScrollView
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Stack( // Use a Stack to layer the background
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
                                'Staff Login',
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

                        // Email
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

                        // Password
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

                        // Forgot password
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

                        // Login button
                        ElevatedButton(
                          onPressed: isLoading ? null : loginStaff,
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

                        // Error message
                        if (errorMsg.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              errorMsg,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Switch to customer login
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginCustomer(),
                              ),
                            );
                          },
                          child: const Text(
                            'Customer? Click here',
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