import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_function/login_customer.dart';
import 'login_function/login_staff.dart';

import 'role_views/admin_view.dart';
import 'role_views/manager_view.dart'; // Make sure this is the updated ManagerView
import 'role_views/cashier_view.dart';
import 'role_views/staff_view.dart';
import 'role_views/customer_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startScreen = await _getStartScreen();
  runApp(MyApp(startScreen));
}

Future<Widget> _getStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('role');
  final staffId = prefs.getInt('staff_id'); // Correctly retrieving staffId

  print('SharedPref: is_logged_in=$isLoggedIn, role=$role, staff_id=$staffId');

  if (isLoggedIn && role != null) {
    switch (role) {
      case 'admin':
        if (staffId != null) return AdminView(staffId: staffId);
        break;
      case 'manager':
        // Ensure staffId is not null before passing
        if (staffId != null) {
          return ManagerView(staffId: staffId);
        }
        break;
      case 'cashier':
        return const CashierView();
      case 'staff':
        // Updated logic from the group's file: check for staffId before creating the view
        if (staffId != null) return StaffView(staffId: staffId);
        break;
      case 'customer':
        return const CustomerView();
    }
  }

  // If not logged in, or if staffId is missing for admin/manager, go to login
  return const ToggleLoginScreen();
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp(this.startScreen, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capstone App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startScreen,
    );
  }
}

class ToggleLoginScreen extends StatefulWidget {
  const ToggleLoginScreen({super.key});

  @override
  State<ToggleLoginScreen> createState() => _ToggleLoginScreenState();
}

class _ToggleLoginScreenState extends State<ToggleLoginScreen> {
  bool showCustomerLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => showCustomerLogin = true),
                child: const Text('Customer'),
              ),
              TextButton(
                onPressed: () => setState(() => showCustomerLogin = false),
                child: const Text('Staff? Click here'),
              ),
            ],
          ),
          Expanded(
            child: showCustomerLogin ? LoginCustomer() : LoginStaff(),
          ),
        ],
      ),
    );
  }
}
