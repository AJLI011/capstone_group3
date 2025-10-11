import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// This is the main screen widget for the cashier's pending orders.
class PendingOrdersScreen extends StatefulWidget {
  final int cashierId;

  const PendingOrdersScreen({super.key, required this.cashierId});

  @override
  _PendingOrdersScreenState createState() => _PendingOrdersScreenState();
}

// This is the state class that manages the logic and UI for the PendingOrdersScreen.
class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  static const String _baseUrl = "http://192.168.0.104:8000";

  // Future to hold the list of pending orders fetched from the API.
  late Future<List<InStoreOrder>> _pendingOrders;

  @override
  void initState() {
    super.initState();
    // Fetch pending orders when the screen first loads.
    _pendingOrders = _fetchPendingOrders();
  }

  // Refreshes the list of orders by re-fetching them from the API.
  Future<void> _refreshOrders() async {
    setState(() {
      _pendingOrders = _fetchPendingOrders();
    });
  }

  // Fetches the list of pending orders from the Django backend.
  Future<List<InStoreOrder>> _fetchPendingOrders() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/sales/pending-orders/'));

    if (response.statusCode == 200) {
      final List<dynamic> ordersJson = json.decode(response.body);
      // Map the JSON data to the InStoreOrder model.
      return ordersJson.map((json) => InStoreOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pending orders');
    }
  }
  
  // =========================================================================
  // NEW: ITEM DELETION LOGIC
  // =========================================================================
  Future<void> _deleteOrderItem(int itemId, int orderId) async {
    _showProcessingDialog(message: "Removing item...");

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/sales/order-items/$itemId/'),
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Close processing dialog

    if (response.statusCode == 204) {
      // 204 No Content is the standard successful DELETE response
      // We also need to close the order details dialog if it's open
      Navigator.of(context).pop(); 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item removed from Order #$orderId. Order recalculated.'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh the entire order list to get the recalculated totals
      _refreshOrders();
    } else {
      // Error: Something went wrong with the request.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete item $itemId: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================================
  // ORDER PROCESSING LOGIC (Approve/Reject)
  // =========================================================================
  Future<void> _processOrder(int orderId, String status) async {
    // For 'rejected', skip the 202 check and go straight to confirmation dialog
    if (status == 'rejected') {
      _showConfirmationDialog(orderId, status);
      return;
    }
    
    // For 'approved', make the initial non-forced API call to trigger 202 check
    _showProcessingDialog(message: "Checking prescription...");

    final response = await http.put(
      Uri.parse('$_baseUrl/api/sales/pending-orders/$orderId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'cashier_id': widget.cashierId,
      }),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (response.statusCode == 200) {
      // Success: Approved without any warnings.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been $status.'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshOrders();
    } else if (response.statusCode == 202) {
      // Backend warning: A prescription is required.
      final Map<String, dynamic> body = json.decode(response.body);
      final bool hasImage = body['has_image'] ?? false;
      
      if (hasImage) {
        const dialogTitle = 'Verify Prescription';
        const dialogContent = 'A prescription has been uploaded. Please verify the image before finalizing this order.';
        _showImageDialog(orderId, status, dialogTitle, dialogContent);
      } else {
        const dialogTitle = 'Prescription Required';
        const dialogContent = 'No prescription image has been uploaded. Do you want to proceed anyway?';
        _showWarningDialog(orderId, status, dialogTitle, dialogContent);
      }
    } else {
      // Error: Something went wrong with the request.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $status order $orderId: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Final processing function (used after confirmation or force-approval).
  Future<void> _forceProcessOrder(int orderId, String status) async {
    _showProcessingDialog(message: "Finalizing order...");

    final response = await http.put(
      Uri.parse('$_baseUrl/api/sales/pending-orders/$orderId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'cashier_id': widget.cashierId,
        'force_approve': status == 'approved' ? true : false, // Only set true for approval
      }),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been $status.'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.grey,
        ),
      );
      _refreshOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $status order $orderId: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // =========================================================================
  // DIALOGS
  // =========================================================================
  void _showProcessingDialog({String message = "Processing..."}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _showWarningDialog(int orderId, String status, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Approve Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                // Show final confirmation after the warning
                _showConfirmationDialog(orderId, status, isForceApproval: true); 
              },
            ),
          ],
        );
      },
    );
  }

  void _showImageDialog(int orderId, String status, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(content),
                const SizedBox(height: 16),
                // TODO: Placeholder for prescription image display
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Approve Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                // Show final confirmation after image review
                _showConfirmationDialog(orderId, status, isForceApproval: true); 
              },
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog(int orderId, String status, {bool isForceApproval = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Correct title and content based on status
        final dialogTitle = status == 'approved' ? 'Final Approve Order' : 'Reject Order';
        final dialogContent = isForceApproval 
            ? 'WARNING: You are about to force-approve order #$orderId, overriding the prescription requirement. Confirm this action?'
            : 'Are you sure you want to ${status == 'approved' ? 'approve' : 'reject'} order #$orderId?';
            
        final confirmText = status == 'approved' ? 'Confirm Approve' : 'Confirm Reject';
            
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(confirmText),
              onPressed: () {
                Navigator.of(context).pop();
                _forceProcessOrder(orderId, status); // Call the final processing function.
              },
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ORDER DETAILS DIALOG (Item-level actions, including delete)
  // =========================================================================
  void _showOrderDetailsDialog(InStoreOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order #${order.id} Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staff: ${order.staffName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (order.isPwd) const Text('PWD Discount Applied', style: TextStyle(color: Colors.blue)),
                const Divider(),
                const Text('Items (Valid for fulfillment):', style: TextStyle(fontWeight: FontWeight.bold)),
                // Show list of items with delete button
                ...order.items.map((item) => _buildItemDetailRow(item, order)),
                const Divider(),
                _buildTotalsSection(order),
                const SizedBox(height: 16),
                const Text('Note: Invalid items are filtered out by the system.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper for the detail dialog to show individual item info with a delete button
  Widget _buildItemDetailRow(InStoreOrderItem item, InStoreOrder order) {
    double itemSubtotal = item.quantitySold * item.priceAtSale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicineName),
                Text('Qty: ${item.quantitySold} (+${item.freeQuantityGiven} free)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text('₱${itemSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          // ADDED: DELETE BUTTON FOR THE ITEM
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: () => _deleteOrderItem(item.id, order.id), 
          )
        ],
      ),
    );
  }
  
  // =========================================================================
  // MAIN BUILD & CARD WIDGETS
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<InStoreOrder>>(
        future: _pendingOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending orders found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final order = snapshot.data![index];
                return _buildOrderCard(order);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(InStoreOrder order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell( // Use InkWell to allow tapping the card for details
        onTap: () => _showOrderDetailsDialog(order),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ORDER # ${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    order.isPwd ? 'PWD Sale' : 'Regular Sale',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: order.isPwd ? Colors.blue : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                'Initiated by: ${order.staffName}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),

              if (order.hasPrescriptionRequiredItem)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Requires Prescription',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),
              
              if (order.items.isNotEmpty)
                _buildOrderItemSummary(order.items.first, order.items.length),
                
              const SizedBox(height: 16),
              _buildTotalsSection(order),
              const SizedBox(height: 16),
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItemSummary(InStoreOrderItem firstItem, int itemCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${firstItem.medicineName} x ${firstItem.quantitySold}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        if (itemCount > 1)
          Text(
            'and ${itemCount - 1} other item${itemCount > 2 ? 's' : ''}. Tap for details.',
            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildTotalsSection(InStoreOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Text(
                '₱${order.totalAmountBeforeDiscount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Discount (20%):',
                  style: TextStyle(color: Colors.red)),
              const SizedBox(width: 8),
              Text(
                '-₱${(order.totalAmountBeforeDiscount - order.totalAmountAfterDiscount).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Total Payable:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              '₱${order.totalAmountAfterDiscount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(InStoreOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: ElevatedButton(
            // Initial call handles the 202 check or proceeds to confirmation
            onPressed: () => _processOrder(order.id, 'approved'), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Approve', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            // Rejection goes straight to confirmation
            onPressed: () => _processOrder(order.id, 'rejected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// DATA MODELS
// =========================================================================
class InStoreOrder {
  final int id;
  final String staffName;
  final bool isPwd;
  final double totalAmountBeforeDiscount;
  final double totalAmountAfterDiscount;
  final List<InStoreOrderItem> items;
  final bool hasPrescriptionRequiredItem;

  InStoreOrder({
    required this.id,
    required this.staffName,
    required this.isPwd,
    required this.totalAmountBeforeDiscount,
    required this.totalAmountAfterDiscount,
    required this.items,
    required this.hasPrescriptionRequiredItem,
  });

  factory InStoreOrder.fromJson(Map<String, dynamic> json) {
    return InStoreOrder(
      id: json['id'],
      staffName: json['staff_name'],
      isPwd: json['is_pwd'],
      totalAmountBeforeDiscount: double.tryParse(
              json['total_amount_before_discount']?.toString() ?? '0.0') ??
          0.0,
      totalAmountAfterDiscount: double.tryParse(
              json['total_amount_after_discount']?.toString() ?? '0.0') ??
          0.0,
      items: (json['items'] as List? ?? [])
          .map((itemJson) => InStoreOrderItem.fromJson(itemJson))
          .toList(),
      hasPrescriptionRequiredItem:
          json['has_prescription_required_item'] ?? false,
    );
  }
}

class InStoreOrderItem {
  // ADDED: ID is required for the DELETE request to the backend
  final int id; 
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final double priceAtSale;

  InStoreOrderItem({
    required this.id, // ADDED
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.priceAtSale,
  });

  factory InStoreOrderItem.fromJson(Map<String, dynamic> json) {
    return InStoreOrderItem(
      id: json['id'], // Mapped from the serializer
      medicineName: json['medicine_name'] ?? 'N/A',
      quantitySold: json['quantity_sold'] ?? 0, 
      freeQuantityGiven: json['free_quantity_given'] ?? 0, 
      priceAtSale:
          double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}