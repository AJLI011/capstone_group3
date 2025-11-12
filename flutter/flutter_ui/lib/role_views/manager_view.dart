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
import 'manager_features/online_sales_transaction/online_transaction.dart';
import 'manager_features/instore_sales_transaction_m/instore_transaction.dart';
import 'manager_features/demand_forecasting/demand_forecast.dart';
import 'manager_features/purchase_request/purchase_request_page.dart';
import 'manager_features/sales_report/sales_report.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_ui/services/responsive_scale.dart'; 
import 'manager_features/daily_reports/daily_reports.dart';
import 'manager_features/return_medicines/return_view.dart';
import 'manager_features/restock/restock_menu_screen.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.12:8000/',
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

  // EXISTING: Dialog for Expiring stock NOT on promo
  Future<void> _showWarningDialog() async {
    // Only show the dialog if there's unaddressed stock
    if (unaddressedExpiringCount == 0) return; 

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange), 
              SizedBox(width: 9),
              Expanded( 
                child: Text(
                  'Action: Set Promo',
                  softWrap: true,
                ),
              ),
            ],
          ),
          content: Text(
            // Use the unaddressed count here
            'You have $unaddressedExpiringCount medicine batches expiring soon that have not yet been assigned a promo. This stock is eligible for promo pricing.',
          ),
          actions: <Widget>[
            TextButton(
              // THIS REDIRECTS TO PromoMedicinePage
              child: const Text('View & Set Promo'),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _open(const PromoMedicinePage()); 
              },
            ),
            TextButton(
              child: const Text('Close'),
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
  Future<void> _showExpiringPromoDialog() async {
    if (expiringPromoCount == 0) return; 

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
            return AlertDialog(
                title: Row(
                    children: [
                        const Icon(Icons.access_time_filled, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Expanded( 
                            child: Text(
                                'Promo(s) Ending Soon ($expiringPromoCount)', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                leading: const Icon(Icons.label_off, color: Colors.deepPurple),
                                title: Text(medicineName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Ends: $formattedDate', style: const TextStyle(color: Colors.red)),
                            );
                        }).toList(),
                    ),
                ),
                actions: <Widget>[
                    TextButton(
                        child: const Text('Close'),
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
                // 💡 UPDATED ACTIONS LIST TO INCLUDE BOTH WARNINGS
                actions: [
                  // 1. Promo Expiry Alert (Blue/Purple Badge)
                  if (expiringPromoCount > 0)
                    IconButton(
                      onPressed: _showExpiringPromoDialog,
                      icon: Stack(
                        children: [
                          // Icon for Promos/Sales
                          const Icon(Icons.access_time_filled, color: Colors.lightBlueAccent), 
                          // Notification badge
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple, // Different color for distinction
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                              child: Text(
                                '$expiringPromoCount',
                                style: const TextStyle(color: Colors.white, fontSize: 8),
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
                      onPressed: _showWarningDialog, 
                      icon: Stack(
                        children: [
                          // The primary warning icon
                          const Icon(Icons.warning_amber_outlined, color: Colors.yellow),
                          // The small red notification badge
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  // Existing Menu Button
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
                              color: Color(0xFF5C7C9A),
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
                          _buildSectionTitle('Inventory Logs'),
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
                          // Profile Section
                          Container(
                            color: const Color(0xFF5C7C9A),
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person, size: 50, color: Color(0xFF5C7C9A)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  staffName ?? 'Manager Name',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'manager.email@example.com',
                                  style: const TextStyle(
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
                                _drawerItem(Icons.inventory_outlined, 'Inventory', 
                                    () => _open(const InventoryGridScreen())),
                                _drawerItem(Icons.shelves, 'Restock', 
                                    () => _open(const RestockMenuScreen())),
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
                                _drawerItem(Icons.analytics, 'Sales Report', // Using a new, general icon
                                    () => _open(const CombinedSalesReportPage())), 
                                _drawerItem(Icons.insights, 'Demand Forecast', 
                                    () => _open(const DemandForecastScreen())),
                                _drawerItem(Icons.shopping_cart, 'Purchase Request', 
                                    () => _open(const PurchaseRequestPage())),
                                _drawerItem(Icons.list_alt, 'Medicine List', 
                                    () => _open(const MedicineListView())),
                                _drawerItem(Icons.receipt_long, 'Daily Reports', 
                                    () => _open(DailyReportsPage())),
                                _drawerItem(Icons.person_outline, 'Edit Profile', 
                                    () => _open(EditManagerProfilePage(staffId: widget.staffId))),
                                _drawerItem(Icons.vpn_key, 'Change Password',
                                    () => _open(ChangeManagerPasswordPage(staffId: widget.staffId))),
                              ],
                            ),
                          ),
                          // Logout Button
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C7C9A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _confirmLogout,
                              child: const Text('Logout'),
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
    return Column(
      children: [
        _buildSummaryCard(
          title: 'Total Medicines',
          value: totalMedicineCount.toString(),
          icon: Icons.medication_liquid_outlined,
          color: const Color(0xFF5C7C9A),
          textColor: Colors.white,
        ),
        const SizedBox(height: 16),
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
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              Icon(icon, size: 50, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  // Uses totalExpiringSoonCount for the dashboard card
  Widget _buildExpirationIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIndicator(Icons.check_circle_outline, 'Good Stock', goodStockCount, Colors.green),
        _buildIndicator(Icons.warning_amber_outlined, 'Expiring Soon', totalExpiringSoonCount, Colors.orange),
        _buildIndicator(Icons.error_outline, 'Expired', expiredCount, Colors.red),
      ],
    );
  }

  // MODIFIED TO USE SMALLER SIZES
  Widget _buildIndicator(IconData icon, String title, int count, Color color) {
    // Sizes optimized for smaller screens
    const double countFontSize = 20; 
    const double iconSize = 30; 
    const double cardPadding = 10.0; 
    // REDUCED TITLE FONT SIZE to help longer titles fit on one line
    const double titleFontSize = 10; 

    return Expanded(
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(cardPadding),
          child: Column(
            // Ensure content is packed tightly to save vertical space
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: countFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: titleFontSize, // <--- THE CHANGE IS HERE
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

  // FIX APPLIED HERE
  Widget _buildLowStockList() {
    if (lowStockItems.isEmpty) {
      return const Text(
        'No low stock items found.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return SizedBox(
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade400, width: 1.5),
        ),
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];

            // ⭐ THE CONFIRMED FIX: Use 'name' key from the LowStockSerializer output.
            final medicineName = item['name']?.toString() ?? 'N/A'; 
            
            // CONFIRMED KEY: 'generic_name'
            final genericName = item['generic_name']?.toString() ?? 'N/A';
              
            // CONFIRMED KEY: 'total_quantity'
            final totalQuantity = item['total_quantity']?.toString() ?? '0';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(medicineName), 
                subtitle: Text('Generic: $genericName'),
                trailing: Text(
                  'Qty: $totalQuantity',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInventoryLogsList() {
    if (inventoryLogs.isEmpty) {
      return const Text('No recent logs.', style: TextStyle(color: Colors.grey));
    }

    final latestLogs = inventoryLogs.length > 3 ? inventoryLogs.sublist(0, 3) : inventoryLogs;

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
            children: latestLogs.map((log) {
              final DateTime utcTimestamp = DateTime.parse(log['timestamp']).toUtc();
              final location = tz.getLocation('Asia/Manila');
              final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text('${log['action_type']} by ${log['user_name']}'),
                  subtitle: Text(log['description']),
                  trailing: Text(DateFormat('hh:mm a').format(manilaTimestamp)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey.shade700),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontSize: 16,
            ),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        ),
        const Divider(height: 1, color: Colors.black12),
      ],
    );
  }
}