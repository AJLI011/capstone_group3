import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// New widget to display a confirmation dialog. This replaces standard alerts.
Future<bool?> showConfirmationDialog(BuildContext context, String title, String content) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // User must tap a button to dismiss
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(false); // Dismiss dialog, return false
            },
          ),
          TextButton(
            child: const Text('Confirm'),
            onPressed: () {
              Navigator.of(context).pop(true); // Dismiss dialog, return true
            },
          ),
        ],
      );
    },
  );
}

// This is the new, separate widget for each order card.
// We make it a StatefulWidget so it can manage its own checkbox state.
class CashierOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(int) onCancel;
  final Function(int) onFinalize;
  final Function(int, int) onRemoveItem;
  final Function(int, bool) onUpdateDiscount;
  final String baseUrl;

  const CashierOrderCard({
    super.key,
    required this.order,
    required this.onCancel,
    required this.onFinalize,
    required this.onRemoveItem,
    required this.onUpdateDiscount,
    required this.baseUrl,
  });

  @override
  _CashierOrderCardState createState() => _CashierOrderCardState();
}

class _CashierOrderCardState extends State<CashierOrderCard> {
  late Map<String, dynamic> _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  // This method is called from the parent widget to update the local state
  // when a change occurs (e.g., after an API call to update the discount).
  @override
  void didUpdateWidget(covariant CashierOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      setState(() {
        _currentOrder = widget.order;
      });
    }
  }

  // Function to handle the PWD checkbox logic.
  // It calls the parent's function to trigger the API call.
  void _onPwdCheckboxChanged(bool? newValue) {
    // Safely get the order ID, providing a default of 0 if null.
    final orderId = widget.order['id'] as int? ?? 0;
    widget.onUpdateDiscount(orderId, newValue ?? false);
  }

  void _onRemoveItem(int orderId, int itemId) async {
    bool? confirmed = await showConfirmationDialog(
      context,
      'Remove Item?',
      'Are you sure you want to remove this item from the order?'
    );
    if (confirmed == true) {
      widget.onRemoveItem(orderId, itemId);
    }
  }

  // A helper function to build the list of items inside the order card
  List<Widget> _buildOrderItems(List<dynamic> items) {
    // Safely get the order ID, using tryParse for robustness
    final orderId = int.tryParse(widget.order['id'].toString());

    return items.map((item) {
      // Safely get the item ID
      final itemId = int.tryParse(item['id'].toString());

      // Safely parse the quantity and price, defaulting to 0 if null or invalid
      final quantitySold = int.tryParse(item['quantity_sold'].toString()) ?? 0;
      final freeQuantity = int.tryParse(item['free_quantity_given'].toString()) ?? 0;
      final priceAtSale = double.tryParse(item['price_at_sale'].toString()) ?? 0.0;
      final itemTotal = priceAtSale * quantitySold;
      
      // ⭐ UPDATED LOGIC: Determine if the item is considered deleted/unavailable.
      // We assume a total of 0.0 means the item or its price was removed by the system.
      final isDeleted = itemTotal == 0.0 && quantitySold > 0;
      const deletedMessage = 'This item is no longer available';

      final medicine = item['medicine'] as Map<String, dynamic>;
      final medicineName = medicine['name'] ?? 'N/A';
      final genericName = medicine['generic_name'] ?? 'N/A';
      
      // Only use the image URL if the item is NOT deleted
      final imageUrl = isDeleted ? '' : (medicine['image'] ?? ''); 
      final requiresPrescription = medicine['requires_prescription'] ?? false;
      
      String fullImageUrl = imageUrl.isNotEmpty && !imageUrl.startsWith('http')
          ? '${widget.baseUrl}$imageUrl'
          : imageUrl;

      // Debugging print statement to check if IDs are present
      print('Building item card. Order ID: $orderId, Item ID: $itemId');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UPDATED: Image loading logic with a fallback
            if (fullImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  fullImageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.medication, size: 60),
                ),
              )
            else
              const Icon(Icons.medication, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  
                  // ⭐ ADDED LOGIC: Display the deleted message if applicable
                  if (isDeleted)
                    const Text(
                      deletedMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  
                  // Show item details only if NOT deleted
                  if (!isDeleted) ...[ 
                    Text(
                      genericName,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                    if (requiresPrescription)
                      const Text(
                        'Prescription Required',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (freeQuantity > 0)
                      Text(
                        'Quantity: $quantitySold, Promo: $freeQuantity',
                        style: const TextStyle(fontSize: 14),
                      )
                    else
                      Text(
                        'Quantity: $quantitySold',
                        style: const TextStyle(fontSize: 14),
                      ),
                  ]
                ],
              ),
            ),
            
            // ⭐ ADDED LOGIC: Hide delete button and price if item is deleted/unavailable
            if (!isDeleted)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                // Enable the button only if both orderId and itemId are not null
                onPressed: (orderId != null && itemId != null)
                    ? () => _onRemoveItem(orderId, itemId)
                    : null, // Disable the button if IDs are null
              ),
            
            if (!isDeleted)
              Text(
                '₱${itemTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              )
            else 
              // Add spacing for alignment when price/delete icon are hidden
              const SizedBox(width: 48), 
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // The total amount for the UI is now directly from the order data
    final totalAmount = double.tryParse(_currentOrder['total_amount_after_discount'].toString()) ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Text('Order #${_currentOrder['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_currentOrder['customer_name'] ?? 'N/A'}'),
            Text('Status: ${_currentOrder['status'].toString().toUpperCase()}'),
            if (_currentOrder.containsKey('pickup_schedule') && _currentOrder['pickup_schedule'] != null)
              Text(
                'Pickup: ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.parse(_currentOrder['pickup_schedule']).toLocal())}',
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                // Use the order data for the UI
                ..._buildOrderItems(_currentOrder['items']),
                const SizedBox(height: 16),
                // PWD checkbox for ready for pickup orders
                Row(
                  children: [
                    // The checkbox's value is taken directly from the current order data
                    Checkbox(
                      value: _currentOrder['is_pwd'] ?? false,
                      // When the checkbox is tapped, this function is called.
                      onChanged: _onPwdCheckboxChanged,
                    ),
                    const Text('Apply PWD/Senior Citizen Discount'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                              final bool? confirm = await showConfirmationDialog(
                                context,
                                'Cancel Order?',
                                'Are you sure you want to cancel this entire order? This cannot be undone.'
                              );
                              if (confirm == true) {
                                widget.onCancel(_currentOrder['id'] as int);
                              }
                            },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel Order'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                              final bool? confirm = await showConfirmationDialog(
                                context,
                                'Finalize Order?',
                                'Are you sure the customer has picked up this order? This will deduct from the inventory.'
                              );
                              if (confirm == true) {
                                widget.onFinalize(_currentOrder['id'] as int);
                              }
                            },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Picked Up'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CashierOnlineOrdersPage extends StatefulWidget {
  const CashierOnlineOrdersPage({super.key});

  @override
  _CashierOnlineOrdersPageState createState() => _CashierOnlineOrdersPageState();
}

class _CashierOnlineOrdersPageState extends State<CashierOnlineOrdersPage> {
  final String _baseUrl = 'http://10.0.2.2:8000';
  DateTime? _selectedDate;
  List<dynamic> _allOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCashierOrders();
  }

  Future<void> _fetchCashierOrders() async {
    setState(() {
      _isLoading = true;
    });
    final url = '$_baseUrl/api/cashier/online-orders/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          // Filter orders directly after fetching to only show 'ready for pickup'
          _allOrders = jsonDecode(response.body)
              .where((order) => order['status'] == 'ready for pickup')
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load cashier orders');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching orders: $e')),
      );
    }
  }

  // UPDATED: This function now checks the status of the order before updating.
  void _updateOrderInList(Map<String, dynamic> updatedOrder) {
    setState(() {
      final orderIndex = _allOrders.indexWhere((order) => order['id'] == updatedOrder['id']);
      if (orderIndex != -1) {
        // Check if the order status has changed to 'cancelled'
        if (updatedOrder['status'] == 'cancelled') {
          // If the order is cancelled, remove it from the list entirely
          _allOrders.removeAt(orderIndex);
        } else {
          // Otherwise, just update the order data
          _allOrders[orderIndex] = updatedOrder;
        }
      }
    });
  }

  Future<void> _cancelOrder(int orderId) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/cancel/';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Staff ID is missing.')),
      );
      return;
    }

    final body = jsonEncode({
      'staff_id': staffId,
    });

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
        _fetchCashierOrders();
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? 'Failed to cancel order.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to the server: $e')),
      );
    }
  }

  Future<void> _finalizeOrder(int orderId) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/finalize/';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Staff ID is missing.')),
      );
      return;
    }

    final body = jsonEncode({
      'staff_id': staffId,
    });

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order finalized successfully.')),
        );
        _fetchCashierOrders();
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? 'Failed to finalize order.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to the server: $e')),
      );
    }
  }

  // UPDATED: This function now parses the API response to see if the order was
  // cancelled. If so, it removes the order from the list. Otherwise, it updates
  // the order card with the new data.
  Future<void> _removeOrderItem(int orderId, int itemId) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/items/$itemId/';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode == 200) {
      // Decode the response to get the updated order data
      final responseData = jsonDecode(response.body);

      // Check if the order was cancelled because it became empty
      if (responseData['detail'] != null && responseData['detail'].contains('cancelled')) {
        // Since the order is cancelled, we need to remove it from the list
        _allOrders.removeWhere((order) => order['id'] == orderId);
        setState(() {}); // Trigger a rebuild to remove the entire order card
      } else {
        // If the order is not empty, use the returned data to update the specific order card
        _updateOrderInList(responseData['order']);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed successfully.')),
      );
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['detail'] ?? 'Failed to remove item.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // The function that is called by the child widget (CashierOrderCard)
  // to initiate the API call for the discount.
  Future<void> _updateOrderDiscount(int orderId, bool isPwd) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/update-discount/';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_pwd': isPwd}),
    );

    if (response.statusCode == 200) {
      // If the API call is successful, update the specific order in our local list.
      final responseData = jsonDecode(response.body);
      _updateOrderInList(responseData['order']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PWD discount updated successfully.')),
      );
    } else {
      // If the API call fails, show an error message.
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['detail'] ?? 'Failed to update discount.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
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
    List<dynamic> readyForPickupOrders = _allOrders.where((order) => order['status'] == 'ready for pickup').toList();
    if (_selectedDate != null) {
      readyForPickupOrders = readyForPickupOrders.where((order) {
        // Check for null or invalid pickup_schedule before parsing
        final pickupScheduleString = order['pickup_schedule']?.toString();
        if (pickupScheduleString == null || pickupScheduleString.isEmpty) {
          return false; // Skip orders with no pickup schedule
        }
        
        DateTime? pickupDate;
        try {
          pickupDate = DateTime.parse(pickupScheduleString).toLocal();
        } catch (e) {
          // Handle parsing errors gracefully by skipping the order
          print('Error parsing date for order ${order['id']}: $e');
          return false;
        }

        return pickupDate!.year == _selectedDate!.year &&
               pickupDate.month == _selectedDate!.month &&
               pickupDate.day == _selectedDate!.day;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Orders'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCashierOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReadyForPickupTab(readyForPickupOrders),
    );
  }

  Widget _buildReadyForPickupTab(List<dynamic> orders) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null ? 'Select Pickup Date' : DateFormat('MMMM d, yyyy').format(_selectedDate!),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
          child: _buildOrderList(orders),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Text(_selectedDate == null
            ? 'No ready for pickup orders.'
            : 'No orders ready for pickup for this date.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCashierOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return CashierOrderCard(
            order: orders[index],
            onCancel: _cancelOrder,
            onFinalize: _finalizeOrder,
            onRemoveItem: _removeOrderItem,
            onUpdateDiscount: _updateOrderDiscount,
            baseUrl: _baseUrl,
          );
        },
      ),
    );
  }
}