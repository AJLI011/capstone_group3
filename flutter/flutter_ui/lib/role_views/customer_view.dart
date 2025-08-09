import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'customer_features/promo_grid_view.dart';
import 'customer_features/medicine_view.dart';
import 'customer_features/edit_profile/edit_customer_profile.dart';
import 'customer_features/change_password/change_customer_password.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({Key? key}) : super(key: key);

  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _customerName = '';
  String _customerEmail = '';
  int _customerId = 0; // Changed to non-nullable and initialized

  late AnimationController _ctrl;
  bool _isMenuOpen = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadCustomerData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customerName = prefs.getString('customerName') ?? 'Customer';
      _customerEmail = prefs.getString('customerEmail') ?? 'email@example.com';
      // Provide a fallback value for _customerId to handle null
      _customerId = prefs.getInt('customerId') ?? 0;
      isLoading = false;
    });
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    _isMenuOpen ? _ctrl.forward() : _ctrl.reverse();
    if (!_isMenuOpen) {
      _loadCustomerData();
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) return;
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ToggleLoginScreen()),
      (route) => false,
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
      await _logout();
    }
  }

  void _open(Widget page) async {
    _toggleMenu();
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (result == true) {
      _loadCustomerData();
    }
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      hoverColor: Colors.blue.shade50,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BlueWhite Pharmacy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: _toggleMenu,
              tooltip: 'Menu',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome,\n$_customerName!',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.search),
              hintText: 'Search',
              suffixIcon: Icon(Icons.tune),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final List<Widget> _views = [
      const MedicineView(),
      const PromoView(),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_isMenuOpen) {
          _toggleMenu();
          return false;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                if (_currentIndex == 0)
                  Container(
                    padding: const EdgeInsets.only(
                        top: 50, left: 20, right: 20, bottom: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF003B8D), Color(0xFF0050C8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: _buildHeader(),
                  ),
                Expanded(child: _views[_currentIndex]),
              ],
            ),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = screenW - (_ctrl.value * screenW);
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
                                  _customerName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _customerEmail,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const Divider(height: 40),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _drawerItem(
                                            Icons.shopping_bag_outlined,
                                            'My Orders',
                                            () => _open(
                                                _placeholderPage('My Orders'))),
                                        _drawerItem(
                                            Icons.assignment_outlined,
                                            'Medicine Order Agreement',
                                            () => _open(
                                                _placeholderPage('Medicine Order Agreement'))),
                                        _drawerItem(
                                            Icons.edit,
                                            'Edit Profile',
                                            () => _open(EditCustomerProfilePage(customerId: _customerId))),
                                        _drawerItem(
                                            Icons.lock,
                                            'Change Password',
                                            () => _open(ChangeCustomerPasswordPage(customerId: _customerId))),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
        bottomNavigationBar: _isMenuOpen
            ? null
            : BottomNavigationBar(
                backgroundColor: const Color(0xFF002B64),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white70,
                currentIndex: _currentIndex,
                onTap: _onItemTapped,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.medication),
                    label: 'Medicines',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.local_offer),
                    label: 'Promos',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart),
                    label: 'Check Out',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _placeholderPage(String title) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}