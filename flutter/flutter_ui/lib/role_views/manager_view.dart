import 'package:flutter/material.dart';
import 'package:flutter_ui/role_views/manager_features/expiration_dashboard/expiry_dashboard_view.dart';
import 'package:flutter_ui/role_views/manager_features/online_sales_report/online_sales_report_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_function/login_customer.dart'; // UPDATED: Changed import to LoginCustomer

// You'll need to create these placeholder pages for ManagerView features later
import 'manager_features/medicines_list/medicines_list_view.dart';
import 'manager_features/restock/restock_barcode.dart';
import 'manager_features/change_password/change_manager_password.dart'; // change pw
import 'manager_features/edit_profile/edit_manager_profile.dart'; // edit profile
import 'manager_features/inventory/inventory_grid_screen.dart'; // inventory

import 'manager_features/return_medicines/return_page.dart';
import 'manager_features/promo_medicines/promo_page.dart';
import 'manager_features/inventory_logs/inventory_logs_page.dart';
import 'manager_features/online_sales_transaction/online_transaction.dart';
import 'manager_features/instore_sales_report/in_store_sales_report_page.dart';

// NEW IMPORT FOR ORDER LOGS
import 'manager_features/order_logs/order_logs.dart';
import 'manager_features/instore_sales_transaction_m/instore_transaction.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://juliaally.pythonanywhere.com',
);


class ManagerView extends StatefulWidget {
  final int staffId;

  const ManagerView({super.key, required this.staffId});

  @override
  State<ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends State<ManagerView> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isMenuOpen = false;
  String? staffName;
  String? staffEmail;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadStaffInfo();
  }

  Future<void> _loadStaffInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      staffName = prefs.getString('name') ?? 'Manager User';
      staffEmail = prefs.getString('email') ?? 'manager.email@example.com';
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    _isMenuOpen ? _ctrl.forward() : _ctrl.reverse();
  }

      // Helper to POST an employee log (login/logout)
  Future<void> _postEmployeeLog(int staffId, String action) async {
      try {
        final url = Uri.parse('$API_BASE/api/employee-logs/');
        final resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'staff': staffId, 'action': action}),
        );

        if (resp.statusCode != 201 && resp.statusCode != 200) {
          if (!mounted) return;
          debugPrint('Employee log POST failed: ${resp.statusCode} ${resp.body}');
        }
      } catch (e) {
        debugPrint('Failed to send employee log: $e');
      }
    }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get staff id from prefs if present, otherwise fall back to widget.staffId
      int staffIdToUse;
      final int? prefsStaffId = prefs.getInt('staff_id');
      if (prefsStaffId != null) {
        staffIdToUse = prefsStaffId;
      } else {
        staffIdToUse = widget.staffId;
      }

      // Try to send logout log, do not block navigation if it fails
      try {
        await _postEmployeeLog(staffIdToUse, 'logout');
      } catch (e) {
        debugPrint('Error posting logout log: $e');
      }

      // Clear saved session
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginCustomer()), // Corrected widget
        (_) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      // still attempt to clear prefs and navigate away
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginCustomer()), // Corrected widget
        (_) => false,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _logout();
    }
  }

  void _open(Widget page) async {
    _toggleMenu();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadStaffInfo();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        if (_isMenuOpen) {
          _toggleMenu();
          return false;
        }
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text(''),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              body: const Center(child: Text('Welcome, Manager')),
            ),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = (-screenW) + (_ctrl.value * screenW);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: SizedBox(
                    width: screenW,
                    height: double.infinity,
                    child: Material(
                      color: Colors.white,
                      elevation: 16,
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 60),
                                const CircleAvatar(
                                  radius: 40,
                                  child: Icon(Icons.person, size: 50),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  staffName ?? 'Manager Name',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'manager.email@example.com',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const Divider(height: 40),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _drawerItem(Icons.inventory_outlined, 'Inventory',
                                            () => _open(const InventoryGridScreen())),
                                        _drawerItem(Icons.shelves, 'Restock',
                                            () => _open(const RestockBarcodeScreen())),
                                        _drawerItem(Icons.store, 'In Store Sales Transaction',
                                           () => _open(const InStoreTransactionPage())),
                                        _drawerItem(Icons.phone_android_outlined, 'Online Sales Transaction',
                                        () => _open(const OnlineOrdersReportPage())),
                                        _drawerItem(Icons.priority_high, 'Expiry',
                                            () => _open(const ExpiryDashboardView())),
                                        _drawerItem(Icons.assignment_return, 'Return Medicines',
                                            () => _open(const ReturnMedicinePage())),
                                        _drawerItem(Icons.local_offer, 'Promo Medicines',
                                            () => _open(const PromoMedicinePage())),



                                        _drawerItem(Icons.point_of_sale, 'In Store Sales Report',
                                            () => _open(const InStoreSalesReportPage())),
                                        _drawerItem(Icons.trending_up, 'Online Sales Report',
                                            () => _open(const OnlineSalesReportPage())),
                                        _drawerItem(Icons.insights, 'Demand Forecast', () {}),
                                        _drawerItem(Icons.shopping_cart, 'Purchase Request', () {}),
                                        _drawerItem(Icons.list_alt, 'Medicine List',
                                            () => _open(const MedicineListView())),
                                        _drawerItem(Icons.history, 'Inventory Logs',
                                            () => _open(const InventoryLogsPage())),
                                        _drawerItem(Icons.receipt_long, 'Order Logs',
                                            () => _open(const OrderLogsScreen())),
                                        _drawerItem(Icons.person_outline, 'Edit Profile',
                                            () => _open(EditManagerProfilePage(staffId: widget.staffId))),
                                        _drawerItem(Icons.vpn_key, 'Change Password',
                                            () => _open(ChangeManagerPasswordPage(staffId: widget.staffId))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                    ),
                                    onPressed: _confirmLogout,
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      hoverColor: Colors.blue.shade50,
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text('This is the $title page.'),
      ),
    );
  }
}