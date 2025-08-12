import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart'; // ToggleLoginScreen
import 'cashier_features/edit_profile/edit_cashier_profile.dart'; // Import for the new page
import 'cashier_features/change_password/change_cashier_password.dart'; // Import for the new page
import 'cashier_features/pending_orders/pending_orders.dart'; 
import 'cashier_features/online_orders/online_orders_cashier_page.dart'; // Import for the new page
import 'cashier_features/instore_sales_transaction-c/instore_transaction.dart';

// Import for the new page  
// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

class CashierView extends StatefulWidget {
  final int staffId;

  const CashierView({super.key, required this.staffId});

  @override
  State<CashierView> createState() => _CashierViewState();
}

class _CashierViewState extends State<CashierView> with SingleTickerProviderStateMixin {
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
      staffName = prefs.getString('name') ?? 'Cashier User';
      staffEmail = prefs.getString('email') ?? 'no.email@example.com';
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
        // Non-fatal, but print for debugging in dev
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

      // Try to get staffId from prefs first, otherwise fall back to widget.staffId
      int staffIdToUse;
      final int? prefsStaffId = prefs.getInt('staff_id');
      if (prefsStaffId != null) {
        staffIdToUse = prefsStaffId;
      } else {
        staffIdToUse = widget.staffId;
      }

      // Attempt to send logout log regardless of whether prefs had the id
      try {
        await _postEmployeeLog(staffIdToUse, 'logout');
      } catch (e) {
        // ignore and continue with clearing prefs / navigation
        debugPrint('Error posting logout log: $e');
      }

      // Clear saved session
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ToggleLoginScreen()),
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
        MaterialPageRoute(builder: (_) => const ToggleLoginScreen()),
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
      await _logout();
    }
  }

  // In cashier_view.dart
  void _open(Widget page) async {
    _toggleMenu();
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    // If the popped page sent a 'true' result, it means an update occurred
    if (result == true) {
      _loadStaffInfo(); // Reload staff info from SharedPreferences
    }
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
              body: const Center(child: Text('Welcome, Cashier')),
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
                                  staffName ?? 'User Name',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'user.email@example.com',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const Divider(height: 40),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _drawerItem(Icons.assignment, 'Pending Orders', () => _open(PendingOrdersScreen(cashierId: widget.staffId))),
                                        _drawerItem(Icons.store, 'Online Orders', () => _open (CashierOnlineOrdersPage())),
                                        _drawerItem(Icons.shopping_bag, 'In-store Sales Transaction',
                                            () => _open(const InStoreTransactionPage())),
                                        _drawerItem(Icons.smartphone, 'Online Sales Transaction',
                                            () => {}),
                                        _drawerItem(Icons.edit, 'Edit Profile',
                                            () => _open(EditCashierProfilePage(staffId: widget.staffId))),
                                        _drawerItem(Icons.lock, 'Change Password',
                                            () => _open(ChangeCashierPasswordPage(staffId: widget.staffId))),
                                        
                                      ],
                                    ),
                                  ),
                                ),
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