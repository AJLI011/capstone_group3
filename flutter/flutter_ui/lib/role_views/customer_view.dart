import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login_function/login_customer.dart';
import 'customer_features/promo_grid_view.dart';
import 'customer_features/medicine_view.dart';
import 'customer_features/edit_profile/edit_customer_profile.dart';
import 'customer_features/change_password/change_customer_password.dart';
import 'customer_features/checkout_page.dart';
import 'customer_features/medicine_order_agreement_form/medicine_order_agreement_page.dart';
import 'customer_features/my_orders_page.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({Key? key}) : super(key: key);

  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _customerName = '';
  String _customerEmail = '';
  int _customerId = 0;
  String _searchQuery = '';

  late AnimationController _ctrl;
  bool _isMenuOpen = false;
  bool isLoading = true;

  String _selectedCategory = 'all';

  final List<Map<String, String>> _categoryChoices = [
    {'value': 'all', 'label': 'All'},
    {'value': 'analgesics', 'label': 'Analgesics'},
    {'value': 'antibiotics', 'label': 'Antibiotics'},
    {'value': 'antivirals', 'label': 'Antivirals'},
    {'value': 'antihypertensives', 'label': 'Antihypertensives'},
    {'value': 'antidiabetics', 'label': 'Antidiabetics'},
    {'value': 'gastrointestinal_medicines', 'label': 'Gastrointestinal Medicines'},
    {'value': 'antihistamines', 'label': 'Antihistamines'},
    {'value': 'cough_and_cold_medicines', 'label': 'Cough and Cold Medicines'},
    {'value': 'vitamins_and_supplements', 'label': 'Vitamins and Supplements'},
    {'value': 'cardiovascular_medicines', 'label': 'Cardiovascular Medicines'},
    {'value': 'anti_asthma_and_respiratory_medicines', 'label': 'Anti-asthma and Respiratory Medicines'},
    {'value': 'antimalarials', 'label': 'Antimalarials'},
    {'value': 'antiparasitics', 'label': 'Antiparasitics'},
  ];

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
    if (_isMenuOpen) {
      _toggleMenu();
    }
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
      MaterialPageRoute(builder: (context) => const LoginCustomer()),
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

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Category'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  children: _categoryChoices.map((category) {
                    final categoryValue = category['value']!;
                    final categoryLabel = category['label']!;
                    final isSelected = _selectedCategory == categoryValue;

                    return ActionChip(
                      label: Text(categoryLabel),
                      onPressed: () {
                        this.setState(() {
                          _selectedCategory = categoryValue;
                        });
                        Navigator.pop(context);
                      },
                      backgroundColor: isSelected ? Colors.blue.shade700 : Colors.blue.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.blue.shade900,
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
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
        _currentIndex == 0
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: const Icon(Icons.search),
              hintText: 'Search',
              suffixIcon: IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showCategoryFilterDialog,
                tooltip: 'Filter by Category',
              ),
            ),
          ),
        )
            : Container(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    final List<Widget> _views = [
      MedicineView(
        customerId: _customerId,
        selectedCategory: _selectedCategory,
        searchQuery: _searchQuery,
      ),
      PromoView(customerId: _customerId),
      CheckoutPage(customerId: _customerId),
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
                          Container(
                            color: const Color.fromARGB(255, 10, 84, 182),
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
                                  _customerName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _customerEmail,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _drawerItem(
                                  Icons.shopping_bag_outlined,
                                  'My Orders',
                                      () => _open(
                                    MyOrdersPage(customerId: _customerId),
                                  ),
                                ),
                                _drawerItem(
                                  Icons.assignment_outlined,
                                  'Medicine Order Agreement',
                                      () => _open(const MedicineOrderAgreementPage()),
                                ),
                                _drawerItem(
                                  Icons.edit,
                                  'Edit Profile',
                                      () => _open(EditCustomerProfilePage(customerId: _customerId)),
                                ),
                                _drawerItem(
                                  Icons.lock,
                                  'Change Password',
                                      () => _open(ChangeCustomerPasswordPage(customerId: _customerId)),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 10, 84, 182),
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
        bottomNavigationBar: _isMenuOpen
            ? null
            : BottomNavigationBar(
          backgroundColor: const Color(0xFF002B64),
          elevation: 0.0,
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
}