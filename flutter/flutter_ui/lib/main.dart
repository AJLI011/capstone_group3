import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'login_function/login_customer.dart';
import 'login_function/login_staff.dart';

import 'role_views/admin_view.dart';
import 'role_views/manager_view.dart';
import 'role_views/cashier_view.dart';
import 'role_views/staff_view.dart';
import 'role_views/customer_view.dart';
import 'role_views/customer_features/cart_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startScreen = await _getStartScreen();

  runApp(
    ChangeNotifierProvider(
      create: (context) => CartService(),
      child: MyApp(startScreen),
    ),
  );
}

Future<Widget> _getStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('role');
  final staffId = prefs.getInt('staff_id');
  final customerId = prefs.getInt('customerId');

  print('SharedPref: is_logged_in=$isLoggedIn, role=$role, staff_id=$staffId, customerId=$customerId');

  if (isLoggedIn && role != null) {
    switch (role) {
      case 'admin':
        if (staffId != null) return AdminView(staffId: staffId);
        break;
      case 'manager':
        if (staffId != null) {
          return ManagerView(staffId: staffId);
        }
        break;
      case 'cashier':
        if (staffId != null) {
          return CashierView(staffId: staffId);
        }
        break;
      case 'staff':
        if (staffId != null) return StaffView(staffId: staffId);
        break;
      case 'customer':
        return const CustomerView();
    }
  }

  // If not logged in, or if session data is incomplete, default to the customer login screen.
  return const LoginCustomer();
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

// REMOVED: The ToggleLoginScreen widget is no longer needed.
// The LoginCustomer and LoginStaff screens now handle the navigation between them.