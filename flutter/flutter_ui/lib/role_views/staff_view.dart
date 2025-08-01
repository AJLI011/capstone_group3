import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; // ToggleLoginScreen
import 'staff_features/edit_profile/edit_staff_profile.dart';
import 'staff_features/change_password/change_staff_password.dart';
import 'manager_features/inventory/inventory_grid_screen.dart';

class StaffView extends StatefulWidget {
  final int staffId;

  const StaffView({super.key, required this.staffId});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> with SingleTickerProviderStateMixin {
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
      staffName = prefs.getString('name') ?? 'Staff User';
      staffEmail = prefs.getString('email') ?? 'staff@email.com';
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
    await prefs.clear();

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
              body: const Center(child: Text('Welcome, Staff')),
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
                                        _drawerItem(Icons.inventory_outlined, 'Inventory', () => _open(const InventoryGridScreen())),
                                        _drawerItem(Icons.shelves, 'Restock', () {}),
                                        _drawerItem(Icons.store, 'In Store Sales Transaction', () {}),
                                        _drawerItem(Icons.phone_android_outlined, 'Online Sales Transaction', () {}),
                                        _drawerItem(Icons.priority_high, 'Expiry', () {}),
                                        _drawerItem(Icons.assignment_return, 'Return Medicines', () {}),
                                        _drawerItem(Icons.local_offer, 'Promo Medicines', () {}),
                                        _drawerItem(Icons.point_of_sale, 'In Store Sales Report', () {}),
                                        _drawerItem(Icons.trending_up, 'Online Sales Report', () {}),
                                        _drawerItem(Icons.insights, 'Demand Forecast', () {}),
                                        _drawerItem(Icons.shopping_cart, 'Purchase Request', () {}),
                                        _drawerItem(Icons.list_alt, 'Medicine List', () => {}),
                                        _drawerItem(Icons.history, 'Inventory Logs', () {}),
                                        _drawerItem(Icons.receipt_long, 'Order Logs', () {}),
                                        _drawerItem(Icons.person_outline, 'Edit Profile', () => _open(EditStaffProfilePage(staffId: widget.staffId))), 
                                        _drawerItem(Icons.vpn_key, 'Change Password', () => _open(ChangeStaffPasswordPage(staffId: widget.staffId))),
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