import 'package:flutter/material.dart';
import 'package:flutter_ui/role_views/manager_features/expiration_dashboard/expiry_dashboard_view.dart';
import 'package:flutter_ui/role_views/manager_features/online_sales_report/online_sales_report_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_function/login_customer.dart';
import 'manager_features/medicines_list/medicines_list_view.dart';
import 'manager_features/restock/restock_barcode.dart';
import 'manager_features/change_password/change_manager_password.dart';
import 'manager_features/edit_profile/edit_manager_profile.dart';
import 'manager_features/inventory/inventory_grid_screen.dart';
import 'manager_features/return_medicines/return_page.dart';
import 'manager_features/promo_medicines/promo_page.dart';
import 'manager_features/inventory_logs/inventory_logs_page.dart';
import 'manager_features/online_sales_transaction/online_transaction.dart';
import 'manager_features/instore_sales_report/in_store_sales_report_page.dart';
import 'manager_features/order_logs/order_logs.dart';
import 'manager_features/instore_sales_transaction_m/instore_transaction.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://aaron.pythonanywhere.com',
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

  int totalMedicineCount = 0;
  double totalEarned = 0.0;
  int goodStockCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;
  List<dynamic> inventoryLogs = [];
  List<dynamic> lowStockItems = [];

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
    staffName = prefs.getString('name') ?? 'Manager User';
    staffEmail = prefs.getString('email') ?? 'manager.email@example.com';

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$API_BASE/api/medicines/total/')),
        // --- START OF CHANGE ---
        // Calling the new combined endpoint for total earnings
        http.get(Uri.parse('$API_BASE/api/sales/total-earnings/')),
        // --- END OF CHANGE ---
        http.get(Uri.parse('$API_BASE/api/medicines/good-stock/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expiring-soon/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expired/')),
        http.get(Uri.parse('$API_BASE/api/medicines/low-stock/')),
        http.get(Uri.parse('$API_BASE/api/inventory-logs/')),
      ]);

      setState(() {
        if (responses[0].statusCode == 200) {
          totalMedicineCount = json.decode(responses[0].body)['total_count'];
        }
        if (responses[1].statusCode == 200) {
          // The new endpoint returns 'total_earnings' instead of 'total_revenue'
          totalEarned = (json.decode(responses[1].body)['total_earnings'] as num).toDouble();
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
        if (responses[5].statusCode == 200) {
          lowStockItems = json.decode(responses[5].body);
        }
        if (responses[6].statusCode == 200) {
          inventoryLogs = json.decode(responses[6].body);
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
    _fetchDashboardData();
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
                title: const Text('Manager Dashboard'),
                backgroundColor: const Color(0xFF5C7C9A),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              body: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${staffName ?? 'Manager'}!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSummaryCards(),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Medicine Status'),
                          const SizedBox(height: 10),
                          _buildExpirationIndicators(),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Low Stock Alert'),
                          const SizedBox(height: 10),
                          _buildLowStockList(),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Inventory Logs'),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Color(0xFF5C7C9A)),
                                onPressed: _fetchDashboardData,
                                tooltip: 'Refresh logs',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInventoryLogsList(),
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
                  child: SizedBox(
                    width: screenW,
                    height: double.infinity,
                    child: Material(
                      color: Colors.white,
                      elevation: 16,
                      child: Column(
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

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _buildSummaryCard(
          title: 'Total Medicines',
          value: totalMedicineCount.toString(),
          icon: Icons.medication_liquid_outlined,
          color: const Color(0xFF5C7C9A),
          textColor: Colors.white,
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          title: 'Total Earnings',
          value: '₱${totalEarned.toStringAsFixed(2)}',
          icon: Icons.attach_money_outlined,
          color: Colors.green.shade700,
          textColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Color textColor = Colors.black,
  }) {
    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: textColor),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpirationIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIndicator(
            Icons.check_circle_outline, goodStockCount, Colors.green),
        _buildIndicator(
            Icons.warning_amber_outlined, expiringSoonCount, Colors.orange),
        _buildIndicator(Icons.error_outline, expiredCount, Colors.red),
      ],
    );
  }

  Widget _buildIndicator(IconData icon, int count, Color color) {
    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 35, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 22,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLowStockList() {
    if (lowStockItems.isEmpty) {
      return const Text('No low stock items found.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: lowStockItems.map((item) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.medication_outlined, color: Colors.red),
            title: Text(item['name']),
            trailing: Text('Quantity: ${item['quantity']}'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryLogsList() {
    if (inventoryLogs.isEmpty) {
      return const Text('No recent logs.', style: TextStyle(color: Colors.grey));
    }
    return SizedBox(
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5C7C9A),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            children: inventoryLogs.take(5).map((log) {
              final timestamp = DateTime.parse(log['timestamp']);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text('${log['action_type']} by ${log['user_name']}'),
                  subtitle: Text(log['description']),
                  trailing: Text(DateFormat('hh:mm a').format(timestamp)),
                ),
              );
            }).toList(),
          ),
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