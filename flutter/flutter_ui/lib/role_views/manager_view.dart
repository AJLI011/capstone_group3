import 'package:flutter/material.dart';
//import 'package:flutter_ui/role_views/manager_features/expiration_dashboard/expired_stock_page.dart';
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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'manager_features/sales_report/sales_report.dart'; // <--- ADD THIS

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.11:8000/',
);

class ManagerView extends StatefulWidget {
  final int staffId;

  const ManagerView({super.key, required this.staffId});

  @override
  State<ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends State<ManagerView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isMenuOpen = false;
  String? staffName;
  String? staffEmail;
  bool isLoading = true;

  int totalMedicineCount = 0;
  double totalEarned = 0.0;
  int goodStockCount = 0;
  // Holds the total count for the dashboard card
  int totalExpiringSoonCount = 0; 
  // Holds the filtered count for the orange notification badge (expiring AND not promo)
  int unaddressedExpiringCount = 0; 
  int expiredCount = 0;
  List<dynamic> inventoryLogs = [];
  List<dynamic> lowStockItems = [];
  
  // =================================
  // 💡 NEW PROMO EXPIRY STATE VARIABLES
  // =================================
  int expiringPromoCount = 0; // Count of promos ending soon (1 day warning)
  List<dynamic> expiringPromos = []; // List of promos ending soon

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
        http.get(Uri.parse('$API_BASE/api/medicines/total/')), // 0
        http.get(Uri.parse('$API_BASE/api/sales/total-earnings/')), // 1
        http.get(Uri.parse('$API_BASE/api/medicines/good-stock/')), // 2
        // The ORIGINAL call for ALL expiring stock (for dashboard card)
        http.get(Uri.parse('$API_BASE/api/medicines/expiring-soon/')), // 3
        // Only expiring stock that is NOT on promo (for alert badge)
        http.get(Uri.parse('$API_BASE/api/medicines/expiring-soon/unaddressed/')), // 4
        http.get(Uri.parse('$API_BASE/api/medicines/expired/')), // 5
        http.get(Uri.parse('$API_BASE/api/medicines/low-stock/')), // 6
        http.get(Uri.parse('$API_BASE/api/inventory-logs/?limit=3&ordering=-timestamp')), // 7
        // 💡 NEW CALL: Promos ending soon (within 1 day)
        http.get(Uri.parse('$API_BASE/api/promos/ending-soon/')), // 8
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
        
        // Response 3: Unfiltered list -> Used for totalExpiringSoonCount
        if (responses[3].statusCode == 200) {
          totalExpiringSoonCount = json.decode(responses[3].body).length;
        }
        
        // Response 4: Filtered list -> Used for orange notification badge
        if (responses[4].statusCode == 200) {
          unaddressedExpiringCount = json.decode(responses[4].body).length;
        }

        if (responses[5].statusCode == 200) { 
          expiredCount = json.decode(responses[5].body).length;
        }
        if (responses[6].statusCode == 200) { 
          lowStockItems = json.decode(responses[6].body);
        }
        if (responses[7].statusCode == 200) {
          final responseData = json.decode(responses[7].body);
          if (responseData is Map<String, dynamic> && responseData.containsKey('results')) {
            inventoryLogs = responseData['results'] as List<dynamic>;
          } else if (responseData is List<dynamic>) {
            // Fallback for non-paginated responses
            inventoryLogs = responseData;
          }
        }
        
        // ==================================================
        // 💡 NEW: Handle Response 8 for Promos Ending Soon
        // ==================================================
        if (responses[8].statusCode == 200) {
            expiringPromos = json.decode(responses[8].body);
            expiringPromoCount = expiringPromos.length;
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

  Future<void> _confirmLogout(double scale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Logout', style: TextStyle(fontSize: 20 * scale)),
        content: Text('Are you sure you want to logout?', style: TextStyle(fontSize: 14 * scale)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(fontSize: 14 * scale)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(fontSize: 14 * scale)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _logout();
    }
  }

  // EXISTING: Dialog for Expiring stock NOT on promo
  Future<void> _showWarningDialog(double scale) async {
    // Only show the dialog if there's unaddressed stock
    if (unaddressedExpiringCount == 0) return; 

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 24 * scale), 
              SizedBox(width: 9 * scale),
              Expanded( 
                child: Text(
                  'Action: Set Promo',
                  style: TextStyle(fontSize: 20 * scale),
                  softWrap: true,
                ),
              ),
            ],
          ),
          content: Text(
            // Use the unaddressed count here
            'You have $unaddressedExpiringCount medicine batches expiring soon that have not yet been assigned a promo. This stock is eligible for promo pricing.',
            style: TextStyle(fontSize: 14 * scale)
          ),
          actions: <Widget>[
            TextButton(
              // THIS REDIRECTS TO PromoMedicinePage
              child: Text('View & Set Promo', style: TextStyle(fontSize: 14 * scale)),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _open(const PromoMedicinePage()); 
              },
            ),
            TextButton(
              child: Text('Close', style: TextStyle(fontSize: 14 * scale)),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // ==================================================
  // 💡 NEW: Dialog for Promos that are about to END
  // ==================================================
  Future<void> _showExpiringPromoDialog(double scale) async {
    if (expiringPromoCount == 0) return; 

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
            return AlertDialog(
                title: Row(
                    children: [
                        Icon(Icons.access_time_filled, color: Colors.blueAccent, size: 24 * scale),
                        SizedBox(width: 8 * scale),
                        Expanded( 
                            child: Text(
                                'Promo(s) Ending Soon ($expiringPromoCount)', 
                                style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold),
                                softWrap: true,
                            ),
                        ),
                    ],
                ),
                content: SingleChildScrollView(
                    child: ListBody(
                        children: expiringPromos.map((promo) {
                            // Extract relevant data, assuming promo object includes inventory/medicine details
                            final medicineName = promo['inventory_id']?['medicine_name'] ?? 'N/A';
                            // Format the date to be more readable
                            final endDateStr = promo['end_date'];
                            String formattedDate = 'N/A';
                            if (endDateStr != null) {
                                try {
                                    // Parse only the date part
                                    final endDate = DateTime.parse(endDateStr.split('T')[0]); 
                                    formattedDate = DateFormat('MMM d, yyyy').format(endDate);
                                } catch (e) {
                                    formattedDate = endDateStr; // Fallback to raw string
                                }
                            }
                            
                            return ListTile(
                                leading: Icon(Icons.label_off, color: Colors.deepPurple, size: 24 * scale),
                                title: Text(medicineName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16 * scale)),
                                subtitle: Text('Ends: $formattedDate', style: TextStyle(color: Colors.red, fontSize: 14 * scale)),
                            );
                        }).toList(),
                    ),
                ),
                actions: <Widget>[
                    TextButton(
                        child: Text('Close', style: TextStyle(fontSize: 14 * scale)),
                        onPressed: () => Navigator.pop(context),
                    ),
                ],
            );
        },
    );
  }

  void _open(Widget page) async {
    _toggleMenu();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    // Refresh data when returning to dashboard
    _fetchDashboardData(); 
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Base width for scaling (e.g., a standard phone width like Nexus 5X)
    const double baseScreenWidth = 411.4; 
    final double scale = screenW / baseScreenWidth;

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
                title: Text('Manager Dashboard', style: TextStyle(fontSize: 20 * scale)),
                backgroundColor: const Color(0xFF5C7C9A),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                // 💡 UPDATED ACTIONS LIST TO INCLUDE BOTH WARNINGS
                actions: [
                  // 1. Promo Expiry Alert (Blue/Purple Badge)
                  if (expiringPromoCount > 0)
                    IconButton(
                      onPressed: () => _showExpiringPromoDialog(scale),
                      icon: Stack(
                        children: [
                          // Icon for Promos/Sales
                          Icon(Icons.access_time_filled, color: Colors.lightBlueAccent, size: 24 * scale), 
                          // Notification badge
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(2 * scale),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple, // Different color for distinction
                                borderRadius: BorderRadius.circular(6 * scale),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 12 * scale,
                                minHeight: 12 * scale,
                              ),
                              child: Text(
                                '$expiringPromoCount',
                                style: TextStyle(color: Colors.white, fontSize: 8 * scale),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                  // 2. Unaddressed Expiring Stock Alert (Orange/Red Badge)
                  if (unaddressedExpiringCount > 0)
                    IconButton(
                      onPressed: () => _showWarningDialog(scale), 
                      icon: Stack(
                        children: [
                          // The primary warning icon
                          Icon(Icons.warning_amber_outlined, color: Colors.yellow, size: 24 * scale),
                          // The small red notification badge
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(2 * scale),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6 * scale),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 12 * scale,
                                minHeight: 12 * scale,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  // Existing Menu Button
                  IconButton(
                    icon: Icon(Icons.menu, size: 24 * scale),
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              body: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${staffName ?? 'Manager'}!',
                            style: TextStyle(
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5C7C9A),
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          _buildSummaryCards(scale),
                          SizedBox(height: 20 * scale),
                          _buildSectionTitle('Medicine Status', scale),
                          SizedBox(height: 10 * scale),
                          _buildExpirationIndicators(scale),
                          SizedBox(height: 20 * scale),
                          _buildSectionTitle('Low Stock Alert', scale),
                          SizedBox(height: 10 * scale),
                          _buildLowStockList(scale),
                          SizedBox(height: 20 * scale),
                          _buildSectionTitle('Inventory Logs', scale),
                          SizedBox(height: 10 * scale),
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
                            padding: EdgeInsets.symmetric(vertical: 40 * scale, horizontal: 20 * scale),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40 * scale,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person, size: 50 * scale, color: const Color(0xFF5C7C9A)),
                                ),
                                SizedBox(height: 10 * scale),
                                Text(
                                  staffName ?? 'Manager Name',
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'manager.email@example.com',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14 * scale,
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
                                _drawerItem(Icons.inventory_outlined, 'Inventory',
                                    () => _open(const InventoryGridScreen()), scale),
                                _drawerItem(Icons.shelves, 'Restock',
                                    () => _open(const RestockBarcodeScreen()), scale),
                                _drawerItem(Icons.store, 'In Store Sales Transaction',
                                    () => _open(const InStoreTransactionPage()), scale),
                                _drawerItem(Icons.phone_android_outlined, 'Online Sales Transaction',
                                    () => _open(const OnlineOrdersReportPage()), scale),
                                _drawerItem(Icons.priority_high, 'Expiry',
                                    () => _open(const ExpiryDashboardView()), scale),
                                _drawerItem(Icons.assignment_return, 'Return Medicines',
                                    () => _open(const ReturnMedicinePage()), scale),
                                _drawerItem(Icons.local_offer, 'Promo Medicines',
                                    () => _open(const PromoMedicinePage()), scale),
                                _drawerItem(Icons.analytics, 'Sales Report', // Using a new, general icon
                                    () => _open(const CombinedSalesReportPage()), scale), 
                                _drawerItem(Icons.insights, 'Demand Forecast',
                                    () => _open(const DemandForecastScreen()), scale),
                                _drawerItem(Icons.shopping_cart, 'Purchase Request',
                                    () => _open(const PurchaseRequestPage()), scale),
                                _drawerItem(Icons.list_alt, 'Medicine List',
                                    () => _open(const MedicineListView()), scale),
                                _drawerItem(Icons.history, 'Inventory Logs',
                                    () => _open(const InventoryLogsPage()), scale),
                                _drawerItem(Icons.receipt_long, 'Order Logs',
                                    () => _open(const OrderLogsScreen()), scale),
                                _drawerItem(Icons.person_outline, 'Edit Profile',
                                    () => _open(EditManagerProfilePage(staffId: widget.staffId)), scale),
                                _drawerItem(Icons.vpn_key, 'Change Password',
                                    () => _open(ChangeManagerPasswordPage(staffId: widget.staffId)), scale),
                              ],
                            ),
                          ),
                          // Logout Button
                          Padding(
                            padding: EdgeInsets.all(16 * scale),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7C9A),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12 * scale),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8 * scale),
                                ),
                              ),
                              onPressed: () => _confirmLogout(scale),
                              child: Text('Logout', style: TextStyle(fontSize: 16 * scale)),
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

  Widget _buildSummaryCards(double scale) {
    return Column(
      children: [
        _buildSummaryCard(
          scale: scale,
          title: 'Total Medicines',
          value: totalMedicineCount.toString(),
          icon: Icons.medication_liquid_outlined,
          color: const Color(0xFF5C7C9A),
          textColor: Colors.white,
        ),
        SizedBox(height: 16 * scale),
        _buildSummaryCard(
          scale: scale,
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
    required double scale,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Color textColor = Colors.black,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
        child: Padding(
          padding: EdgeInsets.all(16.0 * scale),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 50 * scale, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  // Uses totalExpiringSoonCount for the dashboard card
  Widget _buildExpirationIndicators(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIndicator(Icons.check_circle_outline, 'Good Stock', goodStockCount, Colors.green, scale),
        _buildIndicator(Icons.warning_amber_outlined, 'Expiring Soon', totalExpiringSoonCount, Colors.orange, scale),
        _buildIndicator(Icons.error_outline, 'Expired', expiredCount, Colors.red, scale),
      ],
    );
  }

  Widget _buildIndicator(IconData icon, String title, int count, Color color, double scale) {
    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
        child: Padding(
          padding: EdgeInsets.all(16.0 * scale),
          child: Column(
            children: [
              Icon(icon, size: 35 * scale, color: Colors.white),
              SizedBox(height: 4 * scale),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12 * scale,
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

  Widget _buildSectionTitle(String title, double scale) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18 * scale,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLowStockList(double scale) {
    if (lowStockItems.isEmpty) {
      return Text(
        'No low stock items found.',
        style: TextStyle(color: Colors.grey, fontSize: 14 * scale),
      );
    }
    return SizedBox(
      height: 200 * scale,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: Colors.red.shade400, width: 1.5 * scale),
        ),
        padding: EdgeInsets.all(8.0 * scale),
        child: ListView.builder(
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];
            return Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 8 * scale),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange, size: 24 * scale),
                title: Text(item['medicine_name'], style: TextStyle(fontSize: 16 * scale)),
                subtitle: Text('Generic: ${item['generic_name'] ?? 'N/A'}', style: TextStyle(fontSize: 14 * scale)),
                trailing: Text(
                  'Qty: ${item['total_quantity']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16 * scale,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInventoryLogsList(double scale) {
    if (inventoryLogs.isEmpty) {
      return Text('No recent logs.', style: TextStyle(color: Colors.grey, fontSize: 14 * scale));
    }

    final latestLogs = inventoryLogs.length > 3 ? inventoryLogs.sublist(0, 3) : inventoryLogs;

    return SizedBox(
      height: 200 * scale,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5C7C9A),
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        padding: EdgeInsets.all(8.0 * scale),
        child: SingleChildScrollView(
          child: Column(
            children: latestLogs.map((log) {
              final DateTime utcTimestamp = DateTime.parse(log['timestamp']).toUtc();
              final location = tz.getLocation('Asia/Manila');
              final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);

              return Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 8 * scale),
                child: ListTile(
                  leading: Icon(Icons.history_outlined, size: 24 * scale),
                  title: Text('${log['action_type']} by ${log['user_name']}', style: TextStyle(fontSize: 16 * scale)),
                  subtitle: Text(log['description'], style: TextStyle(fontSize: 14 * scale)),
                  trailing: Text(DateFormat('hh:mm a').format(manilaTimestamp), style: TextStyle(fontSize: 14 * scale)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, double scale) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey.shade700, size: 24 * scale),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontSize: 16 * scale,
            ),
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
        ),
        const Divider(height: 1, color: Colors.black12),
      ],
    );
  }
}