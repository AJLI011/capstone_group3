// manager_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_ui/role_views/manager_features/expiration_dashboard/expiry_dashboard_view.dart';
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
import 'manager_features/order_logs/order_logs.dart';
import 'manager_features/instore_sales_transaction_m/instore_transaction.dart';
import 'manager_features/demand_forecasting/demand_forecast.dart';
import 'manager_features/purchase_request/purchase_request_page.dart';
import 'manager_features/sales_report/sales_report.dart'; // <--- ADD THIS
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_ui/services/responsive_scale.dart'; 

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.0.104:8000/',
);



class ManagerView extends StatefulWidget {
  final int staffId;

  const ManagerView({super.key, required this.staffId});

  @override
  State<ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends State<ManagerView>
    with SingleTickerProviderStateMixin, ResponsiveScale {
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
    // Initialize timezone data
    tz.initializeTimeZones();
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
        http.get(Uri.parse('$API_BASE/api/sales/total-earnings/')),
        http.get(Uri.parse('$API_BASE/api/medicines/good-stock/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expiring-soon/')),
        http.get(Uri.parse('$API_BASE/api/medicines/expired/')),
        http.get(Uri.parse('$API_BASE/api/medicines/low-stock/')),
        http.get(Uri.parse('$API_BASE/api/inventory-logs/?limit=3&ordering=-timestamp')),
      ]);

      setState(() {
        if (responses[0].statusCode == 200) {
          totalMedicineCount = json.decode(responses[0].body)['total_count'];
        }
        if (responses[1].statusCode == 200) {
          totalEarned =
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
        if (responses[5].statusCode == 200) {
          lowStockItems = json.decode(responses[5].body);
        }
        if (responses[6].statusCode == 200) {
          final responseData = json.decode(responses[6].body);
          if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
            inventoryLogs = responseData['results'] as List<dynamic>;
          } else if (responseData is List<dynamic>) {
            // Fallback for non-paginated responses
            inventoryLogs = responseData;
          }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog( // Removed const to allow for scale if needed, but keeping it simple
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          // Use a function for TextButton - RESTORED
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
    // --- 1. GET THE SCALE FACTOR ---
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
                title: Text('Manager Dashboard',
                    style: TextStyle(fontSize: 20 * scale)), // SCALED
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
                            'Hello, ${staffName ?? 'Manager'}!',
                            style: TextStyle( // Removed const
                              fontSize: 24 * scale, // SCALED
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5C7C9A),
                            ),
                          ),
                          SizedBox(height: 20 * scale), // SCALED
                          // --- Pass scale to helper methods ---
                          _buildSummaryCards(scale), 
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSectionTitle('Medicine Status', scale), 
                          SizedBox(height: 10 * scale), // SCALED
                          _buildExpirationIndicators(scale),
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSectionTitle('Low Stock Alert', scale),
                          SizedBox(height: 10 * scale), // SCALED
                          _buildLowStockList(scale),
                          SizedBox(height: 20 * scale), // SCALED
                          _buildSectionTitle('Inventory Logs', scale),
                          SizedBox(height: 10 * scale), // SCALED
                          _buildInventoryLogsList(scale),
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
                                  staffName ?? 'Manager Name',
                                  style: TextStyle( // Removed const
                                    fontSize: 20 * scale, // SCALED
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'manager.email@example.com',
                                  style: TextStyle( // Removed const
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
                                // SCALED _drawerItem
                                _drawerItem(Icons.inventory_outlined, 'Inventory', scale,
                                    () => _open(const InventoryGridScreen())),
                                _drawerItem(Icons.shelves, 'Restock', scale,
                                    () => _open(const RestockBarcodeScreen())),
                                _drawerItem(Icons.store, 'In Store Sales Transaction', scale,
                                    () => _open(const InStoreTransactionPage())),
                                _drawerItem(Icons.phone_android_outlined, 'Online Sales Transaction', scale,
                                    () => _open(const OnlineOrdersReportPage())),
                                _drawerItem(Icons.priority_high, 'Expiry', scale,
                                    () => _open(const ExpiryDashboardView())),
                                _drawerItem(Icons.assignment_return, 'Return Medicines', scale,
                                    () => _open(const ReturnMedicinePage())),
                                _drawerItem(Icons.local_offer, 'Promo Medicines', scale,
                                    () => _open(const PromoMedicinePage())),
                                _drawerItem(Icons.analytics, 'Sales Report', scale, // Using a new, general icon
                                    () => _open(const CombinedSalesReportPage())), 
                                _drawerItem(Icons.insights, 'Demand Forecast', scale,
                                    () => _open(const DemandForecastScreen())),
                                _drawerItem(Icons.shopping_cart, 'Purchase Request', scale,
                                    () => _open(const PurchaseRequestPage())),
                                _drawerItem(Icons.list_alt, 'Medicine List', scale,
                                    () => _open(const MedicineListView())),
                                _drawerItem(Icons.history, 'Inventory Logs', scale,
                                    () => _open(const InventoryLogsPage())),
                                _drawerItem(Icons.receipt_long, 'Order Logs', scale,
                                    () => _open(const OrderLogsScreen())),
                                _drawerItem(Icons.person_outline, 'Edit Profile', scale,
                                    () => _open(EditManagerProfilePage(staffId: widget.staffId))),
                                _drawerItem(Icons.vpn_key, 'Change Password', scale,
                                    () => _open(ChangeManagerPasswordPage(staffId: widget.staffId))),
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
                  ),
                );
              },
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
          value: '₱${totalEarned.toStringAsFixed(2)}',
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
        SizedBox(width: 8 * scale), // Added spacing and SCALED
        _buildIndicator(Icons.warning_amber_outlined, 'Expiring Soon', expiringSoonCount, Colors.orange, scale), // PASS SCALE
        SizedBox(width: 8 * scale), // Added spacing and SCALED
        _buildIndicator(Icons.error_outline, 'Expired', expiredCount, Colors.red, scale), // PASS SCALE
      ],
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildIndicator(IconData icon, String title, int count, Color color, double scale) {
    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)), // SCALED
        child: Padding(
          padding: EdgeInsets.all(12.0 * scale), // SCALED (reduced for smaller space)
          child: Column(
            children: [
              Icon(icon, size: 35 * scale, color: Colors.white), // SCALED
              SizedBox(height: 4 * scale), // SCALED
              Text(
                count.toString(),
                style: TextStyle( // Removed const
                  fontSize: 22 * scale, // SCALED
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4 * scale), // SCALED
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle( // Removed const
                  fontSize: 12 * scale, // SCALED
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
      style: TextStyle( // Removed const
        fontSize: 18 * scale, // SCALED
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildLowStockList(double scale) {
    if (lowStockItems.isEmpty) {
      return Text(
        'No low stock items found.',
        style: TextStyle(color: Colors.grey, fontSize: 14 * scale), // SCALED
      );
    }
    return SizedBox(
      height: 200 * scale, // SCALED
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12 * scale), // SCALED
          border: Border.all(color: Colors.red.shade400, width: 1.5 * scale), // SCALED
        ),
        padding: EdgeInsets.all(8.0 * scale), // SCALED
        child: ListView.builder(
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];
            return Card(
              elevation: 2 * scale, // SCALED
              margin: EdgeInsets.only(bottom: 8 * scale), // SCALED
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange, size: 24 * scale), // SCALED
                title: Text(item['name'], style: TextStyle(fontSize: 14 * scale)), // SCALED
                subtitle: Text('Generic: ${item['generic_name'] ?? 'N/A'}', style: TextStyle(fontSize: 12 * scale)), // SCALED
                trailing: Text(
                  'Qty: ${item['total_quantity']}',
                  style: TextStyle( // Removed const
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 14 * scale, // SCALED
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 4 * scale), // SCALED
              ),
            );
          },
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _buildInventoryLogsList(double scale) {
    if (inventoryLogs.isEmpty) {
      return Text('No recent logs.', style: TextStyle(color: Colors.grey, fontSize: 14 * scale)); // SCALED
    }

    final latestLogs = inventoryLogs.length > 3 ? inventoryLogs.sublist(0, 3) : inventoryLogs;

    return SizedBox(
      height: 200 * scale, // SCALED
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5C7C9A),
          borderRadius: BorderRadius.circular(12 * scale), // SCALED
        ),
        padding: EdgeInsets.all(8.0 * scale), // SCALED
        child: SingleChildScrollView(
          child: Column(
            children: latestLogs.map((log) {
              final DateTime utcTimestamp = DateTime.parse(log['timestamp']).toUtc();
              final location = tz.getLocation('Asia/Manila');
              final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);

              return Card(
                elevation: 2 * scale, // SCALED
                margin: EdgeInsets.only(bottom: 8 * scale), // SCALED
                child: ListTile(
                  leading: Icon(Icons.history_outlined, size: 24 * scale), // SCALED
                  title: Text('${log['action_type']} by ${log['user_name']}', style: TextStyle(fontSize: 14 * scale)), // SCALED
                  subtitle: Text(log['description'], style: TextStyle(fontSize: 12 * scale)), // SCALED
                  trailing: Text(DateFormat('hh:mm a').format(manilaTimestamp), style: TextStyle(fontSize: 12 * scale)), // SCALED
                  contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 4 * scale), // SCALED
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- MODIFIED TO ACCEPT SCALE ---
  Widget _drawerItem(IconData icon, String title, double scale, VoidCallback onTap) {
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