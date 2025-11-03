// cashier_view.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_ui/services/responsive_scale.dart'; // <--- 1. IMPORT SCALING UTILITY

import '../login_function/login_customer.dart';
import 'cashier_features/edit_profile/edit_cashier_profile.dart';
import 'cashier_features/change_password/change_cashier_password.dart';
import 'cashier_features/pending_orders/pending_orders.dart';
import 'cashier_features/online_orders/online_orders_cashier_page.dart';


//import 'cashier_features/instore_sales_transaction-c/instore_transaction.dart';
import 'manager_features/instore_sales_transaction_m/instore_transaction.dart';

import 'cashier_features/online_sales_transaction/cashier_online_transaction.dart';
import 'cashier_features/prescription/prescription_cashier.dart';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.21:8000/',
);

class CashierView extends StatefulWidget {
  final int staffId;

  const CashierView({super.key, required this.staffId});

  @override
  State<CashierView> createState() => _CashierViewState();
}

class _CashierViewState extends State<CashierView>
    with SingleTickerProviderStateMixin, ResponsiveScale {
  late AnimationController _ctrl;
  bool _isMenuOpen = false;
  String? staffName;
  String? staffEmail;
  bool isLoading = true;

  int totalMedicineCount = 0;
  double totalEarnings = 0.0;
  int goodStockCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    staffName = prefs.getString('name') ?? 'Cashier User';
    staffEmail = prefs.getString('email') ?? 'no.email@example.com';

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$API_BASE/api/medicines/total/')),
        http.get(Uri.parse('$API_BASE/api/sales/total-earnings/')),
        http.get(Uri.parse('$API_BASE/api/medicines/good-stock/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expiring-soon/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expired/')),
      ]);

      setState(() {
        if (responses[0].statusCode == 200) {
          totalMedicineCount = json.decode(responses[0].body)['total_count'];
        }
        if (responses[1].statusCode == 200) {
          totalEarnings =
              (json.decode(responses[1].body)['total_earnings'] as num)
                  .toDouble();
        }
        if (responses[2].statusCode == 200) {
          goodStockCount = json.decode(responses[2].body).length;
        }
        if (responses[3].statusCode == 200) {
          expiringSoonCount = json.decode(responses[3].body).length;
        }
        if (responses[4].statusCode == 200) {
          expiredCount = json.decode(responses[4].body).length;
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (!_isMenuOpen) {
      _fetchDashboardData();
    }
    setState(() => _isMenuOpen = !_isMenuOpen);
    _isMenuOpen ? _ctrl.forward() : _ctrl.reverse();
  }

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

      int staffIdToUse;
      final int? prefsStaffId = prefs.getInt('staff_id');
      if (prefsStaffId != null) {
        staffIdToUse = prefsStaffId;
      } else {
        staffIdToUse = widget.staffId;
      }

      try {
        await _postEmployeeLog(staffIdToUse, 'logout');
      } catch (e) {
        debugPrint('Error posting logout log: $e');
      }

      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginCustomer()),
        (_) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginCustomer()),
        (_) => false,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final scale = getScaleFactor(context); // SCALED
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Logout', style: TextStyle(fontSize: 20 * scale)), // SCALED
        content: Text('Are you sure you want to logout?', style: TextStyle(fontSize: 16 * scale)), // SCALED
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(fontSize: 14 * scale)), // SCALED
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(fontSize: 14 * scale)), // SCALED
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logout();
    }
  }

  void _open(Widget page) async {
    _toggleMenu();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    // --- 3. GET THE SCALE FACTOR ---
    final scale = getScaleFactor(context);
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
                title: Text('Cashier Dashboard', style: TextStyle(fontSize: 20 * scale)), // SCALED
                backgroundColor: const Color(0xFF5C7C9A),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: Icon(Icons.menu, size: 24 * scale), // SCALED
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              body: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16 * scale), // SCALED
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${staffName ?? 'Cashier'}!',
                            style: TextStyle(
                              fontSize: 24 * scale, // SCALED
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5C7C9A),
                            ),
                          ),
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSummaryCards(scale), // PASS SCALE
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSectionTitle('Medicine Status', scale), // PASS SCALE
                          SizedBox(height: 10 * scale), // SCALED
                          _buildExpirationIndicators(scale), // PASS SCALE
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSectionTitle('Quick Actions', scale), // PASS SCALE
                          SizedBox(height: 10 * scale), // SCALED
                          _buildQuickActions(scale), // PASS SCALE
                        ],
                      ),
                    ),
            ),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = (-screenW) + (_ctrl.value * screenW);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: _buildSideMenu(scale), // PASS SCALE
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildSideMenu(double scale) {
    final screenW = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenW,
      height: double.infinity,
      child: Material(
        color: Colors.white,
        elevation: 16 * scale, // SCALED
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Section
                  Container(
                    color: const Color(0xFF5C7C9A),
                    padding: EdgeInsets.symmetric(vertical: 40 * scale, horizontal: 20 * scale), // SCALED
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40 * scale, // SCALED
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 50 * scale, color: const Color(0xFF5C7C9A)), // SCALED
                        ),
                        SizedBox(height: 10 * scale), // SCALED
                        Text(
                          staffName ?? 'Cashier Name',
                          style: TextStyle(
                            fontSize: 20 * scale, // SCALED
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          staffEmail ?? 'cashier.email@example.com',
                          style: TextStyle(
                            fontSize: 14 * scale, // SCALED
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menu Items List
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _drawerItem(Icons.assignment, 'Instore Sales', scale, // PASS SCALE
                            () => _open(PendingOrdersScreen(cashierId: widget.staffId))),
                        _drawerItem(Icons.store, 'Online Orders', scale, // PASS SCALE
                            () => _open(const CashierOnlineOrdersPage())),
                        _drawerItem(Icons.shopping_bag, 'In-store Sales Transaction', scale, // PASS SCALE
                            () => _open(const InStoreTransactionPage())),
                        _drawerItem(Icons.smartphone, 'Online Sales Transaction', scale, // PASS SCALE
                            () => _open(const OnlineOrdersReportPage())),
                        _drawerItem(Icons.receipt_long, 'Prescriptions', scale, // PASS SCALE
                            () => _open(const PrescriptionsCashier())),
                        _drawerItem(Icons.edit, 'Edit Profile', scale, // PASS SCALE
                            () => _open(EditCashierProfilePage(staffId: widget.staffId))),
                        _drawerItem(Icons.lock, 'Change Password', scale, // PASS SCALE
                            () => _open(ChangeCashierPasswordPage(staffId: widget.staffId))),
                      ],
                    ),
                  ),
                  // Logout Button
                  Padding(
                    padding: EdgeInsets.all(16 * scale), // SCALED
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C7C9A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12 * scale), // SCALED
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8 * scale), // SCALED
                        ),
                      ),
                      onPressed: _confirmLogout,
                      child: Text('Logout',
                          style: TextStyle(fontSize: 16 * scale)), // SCALED
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildSummaryCards(double scale) {
    return Column(
      children: [
        _buildSummaryCard(
          title: 'Total Medicines',
          value: totalMedicineCount.toString(),
          icon: Icons.medication_liquid_outlined,
          color: const Color(0xFF5C7C9A),
          textColor: Colors.white,
          scale: scale, // PASS SCALE
        ),
        SizedBox(height: 16 * scale), // SCALED
        _buildSummaryCard(
          title: 'Total Earnings',
          value: '₱${totalEarnings.toStringAsFixed(2)}',
          icon: Icons.attach_money_outlined,
          color: Colors.green.shade700,
          textColor: Colors.white,
          scale: scale, // PASS SCALE
        ),
      ],
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double scale, // ADDED SCALE
    Color textColor = Colors.black,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)), // SCALED
        child: Padding(
          padding: EdgeInsets.all(16.0 * scale), // SCALED
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14 * scale, // SCALED
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4 * scale), // SCALED
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24 * scale, // SCALED
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 50 * scale, color: textColor), // SCALED
            ],
          ),
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildExpirationIndicators(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIndicator(Icons.check_circle_outline, 'Good Stock', goodStockCount, Colors.green, scale), // PASS SCALE
        SizedBox(width: 8 * scale), // SCALED
        _buildIndicator(Icons.warning_amber_outlined, 'Expiring Soon', expiringSoonCount, Colors.orange, scale), // PASS SCALE
        SizedBox(width: 8 * scale), // SCALED
        _buildIndicator(Icons.error_outline, 'Expired', expiredCount, Colors.red, scale), // PASS SCALE
      ],
    );
  }

  /// **MODIFIED**: Reduced the title font size to prevent "Expiring Soon" from wrapping,
  /// ensuring all indicator cards have the same height.
  Widget _buildIndicator(IconData icon, String title, int count, Color color, double scale) {
    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)), // SCALED
        child: Padding(
          padding: EdgeInsets.all(16.0 * scale), // SCALED
          child: Column(
            // Use mainAxisSize.min to let the Column shrink to fit its contents
            // and mainAxisAlignment.center for vertical alignment.
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(icon, size: 35 * scale, color: Colors.white), // SCALED
              SizedBox(height: 4 * scale), // SCALED
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22 * scale, // SCALED
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4 * scale), // SCALED
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10 * scale, // <--- **THE KEY CHANGE: Reduced from 12 to 10**
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildSectionTitle(String title, double scale) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18 * scale, // SCALED
        fontWeight: FontWeight.bold,
        color: const Color(0xFF5C7C9A),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildQuickActions(double scale) {
    return Card(
      elevation: 4 * scale, // SCALED
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)), // SCALED
      child: Padding(
        padding: EdgeInsets.all(20.0 * scale), // SCALED
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.pending_actions,
              label: 'Pending Orders',
              onTap: () => _open(PendingOrdersScreen(cashierId: widget.staffId)),
              scale: scale, // PASS SCALE
            ),
            _buildActionButton(
              icon: Icons.store,
              label: 'Online Orders',
              onTap: () => _open(const CashierOnlineOrdersPage()),
              scale: scale, // PASS SCALE
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double scale, // ADDED SCALE
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12 * scale), // SCALED
          child: Container(
            padding: EdgeInsets.all(20 * scale), // SCALED
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12 * scale), // SCALED
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2 * scale, // SCALED
                  blurRadius: 5 * scale, // SCALED
                  offset: Offset(0, 3 * scale), // SCALED
                ),
              ],
            ),
            child: Icon(icon, size: 50 * scale, color: Colors.white), // SCALED
          ),
        ),
        SizedBox(height: 12 * scale), // SCALED
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale), // SCALED
        ),
      ],
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _drawerItem(IconData icon, String title, double scale, VoidCallback onTap) { // ADDED SCALE
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey.shade700, size: 24 * scale), // SCALED
          title: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontSize: 16 * scale, // SCALED
            ),
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale), // SCALED
        ),
        Divider(height: 1 * scale, color: Colors.black12), // SCALED
      ],
    );
  }
}