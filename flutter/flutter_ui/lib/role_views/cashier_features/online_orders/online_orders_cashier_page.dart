import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// **UI CONSTANTS**
const Color _primaryColor = Color(0xFF5C7C9A); // Corporate Blue
const Color _secondaryColor = Color(0xFFC4D5E0); // Light Blue/Grey
const Color _successColor = Color(0xFF4CAF50); // Added for clarity

// The updated confirmation dialog function to allow for custom button text.
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // User must tap a button to dismiss
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(color: _primaryColor)),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
            onPressed: () {
              Navigator.of(context).pop(false); // Dismiss dialog, return false
            },
          ),
          TextButton(
            child: Text(confirmText, style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
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
    // The API call will then fail gracefully with a 404.
    final orderId = widget.order['id'] as int? ?? 0;
    widget.onUpdateDiscount(orderId, newValue ?? false);
  }

  void _onRemoveItem(int orderId, int itemId) async {
    bool? confirmed = await showConfirmationDialog(
      context: context,
      title: 'Remove Item?',
      content: 'Are you sure you want to remove this item from the order?'
    );
    if (confirmed == true) {
      widget.onRemoveItem(orderId, itemId);
    }
  }

  // A helper function to build the list of items inside the order card
  List<Widget> _buildOrderItems(List<dynamic> items) {
    // The backend now filters out the "ghost" items (inventory_id__isnull=False).
    final itemsToDisplay = items;

    // Safely get the order ID, using tryParse for robustness
    final orderId = int.tryParse(widget.order['id'].toString());

    final List<Widget> itemWidgets = [];
    
    // Iterate and build each item row
    for (int i = 0; i < itemsToDisplay.length; i++) {
      final item = itemsToDisplay[i];
      // Safely get the item ID
      final itemId = int.tryParse(item['id'].toString());
      
      final medicine = item['medicine'] as Map<String, dynamic>?; 
      if (medicine == null) {
        // Fallback for safety
        continue; 
      }

      // Safely parse the quantity and price, defaulting to 0 if null or invalid
      final quantitySold = int.tryParse(item['quantity_sold'].toString()) ?? 0;
      final freeQuantity = int.tryParse(item['free_quantity_given'].toString()) ?? 0;
      final price = double.tryParse(item['price_at_sale'].toString()) ?? 0.0;
      final itemTotal = price * quantitySold;
      
      final medicineName = medicine['name'] ?? 'N/A';
      final genericName = medicine['generic_name'] ?? 'N/A';
      final imageUrl = medicine['image'] ?? '';
      final requiresPrescription = medicine['requires_prescription'] ?? false;
      
      String fullImageUrl = imageUrl.isNotEmpty && !imageUrl.startsWith('http')
          ? '${widget.baseUrl}$imageUrl'
          : imageUrl;

      itemWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fullImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    fullImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.medication, size: 60, color: _primaryColor),
                  ),
                )
              else
                const Icon(Icons.medication, size: 60, color: _primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
                          fontWeight: FontWeight.bold,
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: (orderId != null && itemId != null)
                    ? () => _onRemoveItem(orderId, itemId)
                    : null, // Disable the button if IDs are null
              ),
              Text(
                '₱${itemTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      // --- FIX: Add a Divider after each item EXCEPT the last one. ---
      if (i < itemsToDisplay.length - 1) {
        itemWidgets.add(const Divider(height: 1, thickness: 1));
      }
      // -------------------------------------------------------------
    }

    return itemWidgets;
  }

  // Helper Widget for the Sale Badge - Extracted for cleaner build method
  Widget _buildSaleBadge(bool isPwd) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPwd ? _secondaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          isPwd ? 'DISCOUNTED SALE' : 'REGULAR SALE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isPwd ? _primaryColor : Colors.black87,
          ),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    final totalAmount = double.tryParse(_currentOrder['total_amount_after_discount'].toString()) ?? 0.0;
    final isPwd = _currentOrder['is_pwd'] ?? false;
    
    return Card(
      elevation: 4, // Added elevation
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), // Rounded corners
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(10.0),
        trailing: const SizedBox.shrink(),
        
        // --- MODIFICATION: TITLE ONLY CONTAINS ORDER ID ---
        title: Text(
          'ORDER # ${_currentOrder['id']}',
          style: const TextStyle(
            fontWeight: FontWeight.w900, // Thicker font
            fontSize: 18,
            color: _primaryColor, // Use primary color for main ID
          ),
        ),
        
        // --- MODIFICATION: SUBTITLE NOW STARTS WITH THE SALE BADGE ---
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // NEW: Place the sale badge here, right below the title (Order ID)
            _buildSaleBadge(isPwd),
            
            const SizedBox(height: 8), // Add space before the next info rows
            
            Text('Customer: ${_currentOrder['customer_name'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700])),
            Text('Status: ${_currentOrder['status'].toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            if (_currentOrder.containsKey('pickup_schedule') && _currentOrder['pickup_schedule'] != null)
              Text(
                'Pickup: ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.parse(_currentOrder['pickup_schedule']).toLocal())}',
                style: const TextStyle(fontSize: 14, color: _primaryColor, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        // ---------------------------------------------------------------
        
        children: [
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                // This call now includes Dividers between items
                ..._buildOrderItems(_currentOrder['items']),
                const SizedBox(height: 16),
                // === PWD Checkbox Section ===
                Row(
                  children: [
                    Checkbox(
                      value: _currentOrder['is_pwd'] ?? false,
                      onChanged: _onPwdCheckboxChanged,
                      activeColor: _primaryColor,
                    ),
                    const Expanded( // Use Expanded to constrain the text width
                      child: Text('Apply PWD/Senior Citizen Discount', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                // ================================
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _successColor),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // === PICKED UP (FINALIZE) BUTTON ===
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onFinalize(_currentOrder['id'] as int);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600, // Darker green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: const Text('Picked Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // === CANCEL BUTTON ===
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final bool? confirm = await showConfirmationDialog(
                              context: context,
                              title: 'Cancel Order?',
                              content: 'Are you sure you want to cancel this entire order? This cannot be undone.',
                              confirmText: 'Confirm Cancel',
                            );
                            if (confirm == true) {
                              widget.onCancel(_currentOrder['id'] as int);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600, // Darker red
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final String _baseUrl = 'http://192.168.1.5:8000';
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
          // Note: This filters the full list to show only 'ready for pickup' orders.
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

  void _updateOrderInList(Map<String, dynamic> updatedOrder) {
    setState(() {
      final orderIndex = _allOrders.indexWhere((order) => order['id'] == updatedOrder['id']);
      if (orderIndex != -1) {
        if (updatedOrder['status'] == 'cancelled' || updatedOrder['status'] == 'finalized') {
          _allOrders.removeAt(orderIndex);
        } else {
          // Update the order in the list, ensuring it maintains the 'ready for pickup' filter
          if (updatedOrder['status'] == 'ready for pickup') {
            _allOrders[orderIndex] = updatedOrder;
          }
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

    // Step 1: Send a check request to the backend. The backend will determine if a prescription is required
    // OR if it needs a simple confirmation dialog for regular items (using 200 OK).
    Future<http.Response> checkRequest(bool forceApprove) {
      return http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'staff_id': staffId,
          // Only send force_approve if it's the final step
          if (forceApprove) 'force_approve': true, 
        }),
      );
    }

    try {
      // 1. Initial request to trigger the backend's check
      http.Response response = await checkRequest(false);

      // Case A: The order requires a prescription (backend returns 202).
      if (response.statusCode == 202) {
        final warningBody = jsonDecode(response.body);
        final bool hasImage = warningBody['has_image'] ?? false;
        
        String dialogTitle;
        String dialogContent;
        
        if (hasImage) {
          dialogTitle = 'Verify Prescription';
          dialogContent = 'A prescription has been uploaded. Please verify the image before finalizing this order.';
        } else {
          dialogTitle = 'Prescription Required';
          dialogContent = 'No prescription image has been uploaded. Do you want to proceed anyway?';
        }
        
        final bool? firstConfirm = await showConfirmationDialog(
          context: context,
          title: dialogTitle,
          content: dialogContent,
          confirmText: 'Approve Anyway',
        );

        if (firstConfirm == true) {
          final bool? finalConfirm = await showConfirmationDialog(
            context: context,
            title: 'Finalize Order',
            content: 'Are you sure you want to finalize this order? This will deduct from the inventory.',
          );
          
          if (finalConfirm == true) {
            // Send the final request with the `force_approve` flag.
            final finalResponse = await checkRequest(true); // Send with force_approve: true

            if (finalResponse.statusCode == 200) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order finalized successfully.')),
              );
              // Remove order from the list instantly
              setState(() {
                _allOrders.removeWhere((order) => order['id'] == orderId);
              });
            } else {
              final errorBody = jsonDecode(finalResponse.body);
              final errorMessage = errorBody['detail'] ?? errorBody['error'] ?? 'Failed to finalize order.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMessage)),
              );
            }
          }
        }
        return; // Exit the function after the prescription workflow is handled.
      } 
      
      // Case B: The order does NOT require a prescription (backend returns 200 to show dialog).
      else if (response.statusCode == 200) {
        // Show a simple, single confirmation dialog.
        final bool? confirm = await showConfirmationDialog(
          context: context,
          title: 'Finalize Order?',
          content: 'Are you sure the customer has picked up this order? This will deduct from the inventory.',
          confirmText: 'Confirm Picked Up',
        );

        if (confirm == true) {
          // CRITICAL FIX: Send the SECOND request with force_approve: true
          final finalResponse = await checkRequest(true); 

          if (finalResponse.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order finalized successfully.')),
            );
            // Remove order from the list instantly
            setState(() {
              _allOrders.removeWhere((order) => order['id'] == orderId);
            });
          } else {
            // Handle error from the final request
            final errorBody = jsonDecode(finalResponse.body);
            final errorMessage = errorBody['detail'] ?? errorBody['error'] ?? 'Failed to finalize order.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
        return; // Exit the function.
      }
      
      // Case C: The initial request failed for other reasons (e.g., 404, 400).
      else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? 'Online order not found or is not ready for pickup.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );

        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to connect to the server: $e')),
      );
    }
  }

  Future<void> _removeOrderItem(int orderId, int itemId) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/items/$itemId/';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['detail'] != null && responseData['detail'].contains('cancelled')) {
        // Order was auto-cancelled because all items were removed
        _allOrders.removeWhere((order) => order['id'] == orderId);
        setState(() {});
      } else {
        // Order was updated, and we get the new order object back
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

  Future<void> _updateOrderDiscount(int orderId, bool isPwd) async {
    final url = '$_baseUrl/api/cashier/online-orders/$orderId/update-discount/';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_pwd': isPwd}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      _updateOrderInList(responseData['order']);
    } else {
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
      builder: (context, child) { // Customizing the date picker theme
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: _primaryColor,
            colorScheme: const ColorScheme.light(primary: _primaryColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
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
        // Safely check for pickup_schedule before parsing
        if (order['pickup_schedule'] == null) return false; 
        
        final pickupDate = DateTime.parse(order['pickup_schedule']).toLocal();
        return pickupDate.year == _selectedDate!.year &&
               pickupDate.month == _selectedDate!.month &&
               pickupDate.day == _selectedDate!.day;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Orders'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCashierOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
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
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null ? 'Select Pickup Date' : DateFormat('MMMM d, yyyy').format(_selectedDate!),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.calendar_month, color: Colors.white),
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
      color: _primaryColor,
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