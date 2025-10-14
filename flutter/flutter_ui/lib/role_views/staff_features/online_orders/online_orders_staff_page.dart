import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffOrdersPage extends StatefulWidget {
  const StaffOrdersPage({super.key});

  @override
  _StaffOrdersPageState createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends State<StaffOrdersPage> with SingleTickerProviderStateMixin {
  // --- UI ENHANCEMENT: Defined Color Palette ---
  static const Color _primaryColor = Color(0xFF5C7C9A);
  static const Color _accentColor = Color(0xFFB5D33D);
  static const Color _successColor = Color(0xFF4CAF50);
  static const Color _warningColor = Color(0xFFFF9800);
  static const Color _errorColor = Color(0xFFF44336);
  static const Color _textColor = Color(0xFF333333);

  late Future<List<dynamic>> _ordersFuture;
  late TabController _tabController;
  final String _baseUrl = 'http://192.168.0.100:8000';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ordersFuture = _fetchStaffOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchStaffOrders();
    });
  }

  Future<List<dynamic>> _fetchStaffOrders() async {
    final url = '$_baseUrl/api/staff/online-orders/';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff orders');
    }
  }

  Future<void> _confirmOrder(int orderId) async {
    print('I/flutter (UI): Tapped "Confirm Order" button for Order #$orderId.');

    final url = '$_baseUrl/api/staff/confirm-online-order/$orderId/';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      print('I/flutter (UI): Error - Staff ID is missing from SharedPreferences.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Staff ID is missing.')),
      );
      return;
    }

    final body = jsonEncode({
      'staff_id': staffId,
    });

    print('I/flutter (UI): Sending PUT request to API with body: $body');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      
      print('I/flutter (UI): API Response Status Code: ${response.statusCode}');
      print('I/flutter (UI): API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('I/flutter (UI): ✅ Order confirmed successfully via API.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order confirmed successfully.')),
        );
        _refreshOrders();
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? 'Failed to confirm order.';
        print('I/flutter (UI): ❌ Failed to confirm order. Error: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print('I/flutter (UI): ❌ Failed to connect to the server. Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to the server: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Orders'),
        backgroundColor: _primaryColor, // UI ENHANCEMENT: Use defined primary color
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // UI ENHANCEMENT: White label for better contrast
          unselectedLabelColor: Colors.white70,
          indicatorColor: _accentColor, // UI ENHANCEMENT: Use accent color for indicator
          indicatorWeight: 4.0,
          tabs: const [
            Tab(text: 'Pending Orders'),
            Tab(text: 'Ready for Pickup'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No online orders to display.'));
          } else {
            final orders = snapshot.data!;
            final pendingOrders = orders.where((order) => order['status'] == 'pending').toList();
            
            List<dynamic> readyForPickupOrders = orders.where((order) => order['status'] == 'ready for pickup').toList();
            if (_selectedDate != null) {
              readyForPickupOrders = readyForPickupOrders.where((order) {
                final pickupDate = DateTime.parse(order['pickup_schedule']).toLocal();
                return pickupDate.year == _selectedDate!.year &&
                       pickupDate.month == _selectedDate!.month &&
                       pickupDate.day == _selectedDate!.day;
              }).toList();
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(pendingOrders, isPending: true),
                _buildReadyForPickupTab(readyForPickupOrders),
              ],
            );
          }
        },
      ),
    );
  }

  // --- UI ENHANCEMENT: Enhanced Date Picker Design ---
  Widget _buildReadyForPickupTab(List<dynamic> orders) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.date_range, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDate == null 
                              ? 'Select Pickup Date' 
                              : DateFormat('MMMM d, yyyy').format(_selectedDate!),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        // Clear Date Button
                        if (_selectedDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          )
                        else
                          const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildOrderList(orders, isPending: false),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {required bool isPending}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(isPending
            ? 'No pending orders.'
            : 'No orders ready for pickup for this date.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], isPending: isPending);
        },
      ),
    );
  }

// Helper widget for clean subtitle rows (Icons and Spaces Removed)
  Widget _buildInfoRow({required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align text at the start if it wraps
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13, 
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

// --- UI ENHANCEMENT: Enhanced Order Card Design (Title, Subtitle, Card Styling) ---
 Widget _buildOrderCard(Map<String, dynamic> order, {required bool isPending}) {
   final totalAmount = double.tryParse(order['total_amount_after_discount'].toString()) ?? 0.0;
   final isPwd = order['is_pwd'] ?? false;
   
   // Status/Discount specific colors (assuming _primaryColor, _textColor, etc., are defined)
   final primaryCardColor = isPwd ? _primaryColor : _textColor; 
   final secondaryCardColor = isPwd ? const Color(0xFFD9E3EF) : Colors.grey.shade200;

   // Helper function for the Sale Badge (moved outside the main build method for cleanliness)
   Widget _buildSaleBadge() {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
       decoration: BoxDecoration(
         color: secondaryCardColor,
         borderRadius: BorderRadius.circular(6),
       ),
       child: Text(
         isPwd ? 'DISCOUNTED SALE' : 'REGULAR SALE',
         style: TextStyle(
           fontWeight: FontWeight.bold,
           fontSize: 11,
           color: primaryCardColor,
         ),
       ),
     );
   }

   return Card(
     elevation: 4, // Added elevation for depth
     margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(10.0),
       // Add a subtle border based on status
       side: BorderSide(
         color: isPending ? _warningColor.withOpacity(0.5) : _successColor.withOpacity(0.5),
         width: 2,
       ),
     ),
     child: ExpansionTile(
       // Arrow REMOVED by setting trailing to a zero-size box
       trailing: const SizedBox.shrink(), 
       tilePadding: const EdgeInsets.all(16.0),
       
       // MODIFICATION: Title is now just the Order Number
       title: Text(
         'ORDER #${order['id']}',
         style: TextStyle(
           fontWeight: FontWeight.w800,
           fontSize: 18,
           color: primaryCardColor,
         ),
       ),
       
       // MODIFICATION: Subtitle now contains the Sale Badge above other information
       subtitle: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const SizedBox(height: 4), 
           // NEW: The Sale Badge is placed here, right below the title
           _buildSaleBadge(),

           const SizedBox(height: 8), 
           _buildInfoRow( // Icon parameter removed
             label: 'Customer',
             value: order['customer_name'] ?? 'N/A',
             color: _textColor,
           ),
           _buildInfoRow( // Icon parameter removed
             label: 'Status',
             value: order['status'].toString().toUpperCase(),
             color: isPending ? _warningColor : _successColor,
           ),
           if (order.containsKey('pickup_schedule') && order['pickup_schedule'] != null)
             _buildInfoRow( // Icon parameter removed
               label: 'Pickup',
               value: DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.parse(order['pickup_schedule']).toLocal()),
               color: Colors.blueGrey.shade700,
             ),
         ],
       ),
       children: [
         Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text('Items in Order:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _textColor)),
               const Divider(height: 16, thickness: 1), // Divider for separation
               // Assuming _buildOrderItems is defined elsewhere
               ..._buildOrderItems(order['items']), 
               const SizedBox(height: 16),
               const Divider(height: 16, thickness: 1),
               // Total Amount Row
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text(
                     'TOTAL AMOUNT:',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                   ),
                   Text(
                     '₱${totalAmount.toStringAsFixed(2)}',
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                   ),
                 ],
               ),
               if (isPending)
                 Padding(
                   padding: const EdgeInsets.only(top: 16.0),
                   child: ElevatedButton(
                     onPressed: () => _confirmOrder(order['id']), // Assuming _confirmOrder is defined elsewhere
                     style: ElevatedButton.styleFrom(
                       backgroundColor: _successColor, // Use defined success color
                       foregroundColor: Colors.white,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       minimumSize: const Size(double.infinity, 50),
                       elevation: 5,
                     ),
                     child: const Text('CONFIRM ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   ),
                 ),
             ],
           ),
         ),
       ],
     ),
   );
 }

  // Helper for status/promo chips
  Widget _buildChip({required String text, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }

  // --- UI ENHANCEMENT: Enhanced Item Display with Chips and Statuses ---
  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map((item) {
      final quantitySold = int.tryParse(item['quantity_sold'].toString()) ?? 0;
      final freeQuantity = int.tryParse(item['free_quantity_given'].toString()) ?? 0;
      final price = double.tryParse(item['price_at_sale'].toString()) ?? 0.0;
      final itemTotal = price * quantitySold;
      
      final medicine = item['medicine'] as Map<String, dynamic>;
      final medicineName = medicine['name'] ?? 'N/A';
      final genericName = medicine['generic_name'] ?? 'N/A';
      final imageUrl = medicine['image'] ?? '';
      final requiresPrescription = medicine['requires_prescription'] ?? false;
      
      final isDeleted = medicine['is_deleted'] ?? false; 
      
      String fullImageUrl = imageUrl.isNotEmpty && !imageUrl.startsWith('http')
          ? '$_baseUrl$imageUrl'
          : imageUrl;

      // Card/Container for each item for better separation
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isDeleted ? _errorColor.withOpacity(0.1) : Colors.grey.shade50, // Light red background for deleted items
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isDeleted ? _errorColor : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/Placeholder
            SizedBox(
              width: 50,
              height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: fullImageUrl.isNotEmpty && !isDeleted 
                    ? Image.network(
                        fullImageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.medication, color: Colors.grey, size: 40),
                      )
                    : Icon(
                        isDeleted ? Icons.delete_forever : Icons.medication, 
                        color: isDeleted ? _errorColor : Colors.grey.shade600, 
                        size: 40
                      ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name
                  Text(
                    medicineName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDeleted ? _errorColor : _textColor,
                      decoration: isDeleted ? TextDecoration.lineThrough : null, // Strikethrough for deleted name
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Generic Name
                  Text(
                    genericName,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDeleted ? _errorColor.withOpacity(0.7) : Colors.grey),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Status/Badges Row (Prescription & Promo)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      // Prescription Badge
                      if (requiresPrescription)
                        _buildChip(
                          text: 'Prescription Required',
                          color: _errorColor,
                          icon: Icons.warning_amber_rounded,
                        ),
                      // Promo/Free Quantity Badge
                      if (freeQuantity > 0)
                        _buildChip(
                          text: 'PROMO: +$freeQuantity Free',
                          color: _accentColor,
                          icon: Icons.star,
                        ),
                      // Deleted Item Message (if deleted)
                      if (isDeleted)
                        _buildChip(
                          text: 'ITEM NO LONGER AVAILABLE',
                          color: _errorColor,
                          icon: Icons.cancel,
                        ),
                    ],
                  ),

                  // Quantity Display
                  const SizedBox(height: 6),
                  Text(
                    'Quantity: $quantitySold',
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Price/Item Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isDeleted ? '---' : '₱${itemTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}