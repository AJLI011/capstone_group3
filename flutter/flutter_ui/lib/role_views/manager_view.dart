import 'package:flutter/material.dart';
import 'package:flutter_ui/role_views/manager_features/expiration_dashboard/expiry_dashboard_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // ToggleLoginScreen

// You'll need to create these placeholder pages for ManagerView features later
import 'manager_features/medicines_list/medicines_list_view.dart';
import 'manager_features/restock/restock_barcode.dart';
import 'manager_features/return_medicines/return_page.dart';
import 'manager_features/promo_medicines/promo_page.dart';

class ManagerView extends StatefulWidget {
  final int staffId; // Manager also needs staffId, similar to Admin

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
      staffName = prefs.getString('name') ?? 'Manager User'; // Default for manager
      staffEmail = prefs.getString('email') ?? 'manager.email@example.com'; // Default for manager
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all stored data

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ToggleLoginScreen()),
      (_) => false,
    );
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

  // This method will be used to open new pages.
  // Currently, it navigates to empty placeholder pages using `Container()`.
  // You'll replace `Container()` with your actual feature pages later.
  void _open(Widget page) async {
    _toggleMenu();
    // No need to await result or reload staff info for simple placeholders
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        if (_isMenuOpen) {
          _toggleMenu();
          return false; // Prevent back button from closing app if menu is open
        }
        return false; // Prevent back button from closing app normally
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Main content of the Manager View
            Scaffold(
              appBar: AppBar(
                title: const Text(''), // You can put 'Manager Dashboard' or similar here
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              body: const Center(child: Text('Welcome, Manager')),
            ),

            // Sliding side panel (Drawer)
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
                                // User Info Section
                                const SizedBox(height: 60),
                                const CircleAvatar(
                                  radius: 40,
                                  child: Icon(Icons.person, size: 50),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  staffName ?? 'Manager Name', // Display manager name
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  staffEmail ?? 'manager.email@example.com', // Display manager email
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const Divider(height: 40),

                                // Scrollable List of Manager Features
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _drawerItem(Icons.inventory_outlined, 'Inventory', () {}),
                                        _drawerItem(Icons.shelves, 'Restock', () => _open(const RestockBarcodeScreen())),
                                        _drawerItem(Icons.store, 'In Store Sales Transaction', () {}),
                                        _drawerItem(Icons.phone_android_outlined, 'Online Sales Transaction', () {}),
                                        _drawerItem(Icons.priority_high, 'Expiry',
                                          () => _open(const ExpiryDashboardView())),
                                        _drawerItem(Icons.assignment_return, 'Return Medicines', 
                                          () => _open(const ReturnMedicinePage())),
                                        _drawerItem(Icons.local_offer, 'Promo Medicines', 
                                        () => _open(const PromoMedicinePage())),
                                        _drawerItem(Icons.point_of_sale, 'In Store Sales Report', () {}),
                                        _drawerItem(Icons.trending_up, 'Online Sales Report', () {}),
                                        _drawerItem(Icons.insights, 'Demand Forecast', () {}),
                                        _drawerItem(Icons.shopping_cart, 'Purchase Request', () {}),
                                        _drawerItem(Icons.list_alt, 'Medicine List', 
                                          () => _open(const MedicineListView())),
                                        _drawerItem(Icons.history, 'Inventory Logs', () {}),
                                        _drawerItem(Icons.receipt_long, 'Order Logs', () {}),
                                        _drawerItem(Icons.person_outline, 'Edit Profile', () {}),
                                        _drawerItem(Icons.vpn_key, 'Change Password', () {}),

                                      ],
                                    ),
                                  ),
                                ),

                                // Logout Button
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

  // Reused _drawerItem widget
  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      hoverColor: Colors.blue.shade50,
    );
  }
}

// A simple placeholder page for demonstration
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