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
  static const String _baseUrl = "http://192.168.1.8:8000";
  // **UI CONSTANTS**
  static const Color _primaryColor = Color(0xFF5C7C9A); // Corporate Blue
  static const Color _secondaryColor = Color(0xFFC4D5E0); // Light Blue/Grey

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
        const dialogContent =
            'A prescription has been uploaded. Please verify the image before finalizing this order.';
        _showImageDialog(orderId, status, dialogTitle, dialogContent);
      } else {
        const dialogTitle = 'Prescription Required';
        const dialogContent =
            'No prescription image has been uploaded. Do you want to proceed anyway?';
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
        'force_approve':
            status == 'approved' ? true : false, // Only set true for approval
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
              const CircularProgressIndicator(color: _primaryColor),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _showWarningDialog(
      int orderId, String status, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: _primaryColor)),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child:
                  const Text('Approve Anyway', style: TextStyle(color: Colors.red)),
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

  void _showImageDialog(
      int orderId, String status, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: _primaryColor)),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child:
                  const Text('Approve Anyway', style: TextStyle(color: Colors.red)),
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

  void _showConfirmationDialog(int orderId, String status,
      {bool isForceApproval = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Correct title and content based on status
        final dialogTitle =
            status == 'approved' ? 'Finalize Order' : 'Reject Order';
        final dialogContent = isForceApproval
            ? 'Are you sure you want to finalize #$orderId? This will deduct from the inventory.'
            : 'Are you sure you want to ${status == 'approved' ? 'approve' : 'reject'} order #$orderId?';

        final confirmText =
            status == 'approved' ? 'Confirm Approve' : 'Confirm Reject';
        final confirmColor = status == 'approved' ? Colors.green : Colors.red;

        return AlertDialog(
          title: Text(dialogTitle, style: const TextStyle(color: _primaryColor)),
          content: Text(dialogContent),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(confirmText,
                  style:
                      TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _forceProcessOrder(
                    orderId, status); // Call the final processing function.
              },
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ORDER DETAILS DIALOG (Item-level display, no actions)
  // =========================================================================
  void _showOrderDetailsDialog(InStoreOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order #${order.id} Details',
              style: const TextStyle(color: _primaryColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staff: ${order.staffName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (order.isPwd)
                  const Text('PWD Discount Applied',
                      style: TextStyle(color: Colors.blue)),
                const Divider(),
                const Text('Items (Valid for fulfillment):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                // Show list of items (NO DELETE BUTTON)
                ...order.items.map((item) => _buildItemDetailRow(item)),
                const Divider(),
                _buildTotalsSection(order),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: _primaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper for the detail dialog to show individual item info (Delete button REMOVED)
  Widget _buildItemDetailRow(InStoreOrderItem item) {
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
                Text(item.medicineName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('Qty: ${item.quantitySold} (+${item.freeQuantityGiven} free)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text('₱${itemSubtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          // DELETE BUTTON WAS REMOVED HERE
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
        backgroundColor: _primaryColor,
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
            return const Center(
                child: CircularProgressIndicator(color: _primaryColor));
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending orders found.'));
          } else {
            return RefreshIndicator(
              // Added RefreshIndicator
              onRefresh: _refreshOrders,
              color: _primaryColor,
              child: ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final order = snapshot.data![index];
                  return _buildOrderCard(order);
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(InStoreOrder order) {
    // Extracted the label widget for re-use and clarity
    final saleLabel = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: order.isPwd ? _secondaryColor : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        order.isPwd ? 'DISCOUNTED SALE' : 'REGULAR SALE',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: order.isPwd ? _primaryColor : Colors.black87,
        ),
      ),
    );

    return Card(
      elevation: 4, // Added elevation for a modern look
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0)), // Rounded corners
      child: InkWell(
        // Use InkWell to allow tapping the card for details
        onTap: () => _showOrderDetailsDialog(order),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Order ID Header
              Text(
                'ORDER # ${order.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900, // Thicker font
                  fontSize: 18,
                  color: _primaryColor, // Use primary color for main ID
                ),
              ),
              const SizedBox(height: 4),

              // 2. DISCOUNT/REGULAR SALE Label (Moved here)
              saleLabel,
              const SizedBox(height: 8),

              // 3. Initiated by Staff
              Text(
                'Initiated by: ${order.staffName}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),

              // 4. Prescription Warning
              if (order.hasPrescriptionRequiredItem)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Requires Prescription',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),

              // 5. Item Summary
              if (order.items.isNotEmpty)
                _buildOrderItemSummary(order.items.first, order.items.length),

              const SizedBox(height: 16),
              // 6. Totals Section
              _buildTotalsSection(order),
              const SizedBox(height: 16),
              // 7. Action Buttons
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
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        if (itemCount > 1)
          Text(
            'and ${itemCount - 1} other item${itemCount > 2 ? 's' : ''}. Tap for details.',
            style: TextStyle(
                color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 13),
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
                style: const TextStyle(
                    color: Colors.grey, decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Discount (20%):', style: TextStyle(color: Colors.red)),
              const SizedBox(width: 8),
              Text(
                '-₱${(order.totalAmountBeforeDiscount - order.totalAmountAfterDiscount).toStringAsFixed(2)}',
                style:
                    const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              '₱${order.totalAmountAfterDiscount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
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
              backgroundColor: Colors.green.shade600, // Darker green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            child: const Text('Approve',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            // Rejection goes straight to confirmation
            onPressed: () => _processOrder(order.id, 'rejected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, // Darker red
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            child: const Text('Reject',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final int id;
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final double priceAtSale;

  InStoreOrderItem({
    required this.id,
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.priceAtSale,
  });

  factory InStoreOrderItem.fromJson(Map<String, dynamic> json) {
    return InStoreOrderItem(
      id: json['id'],
      medicineName: json['medicine_name'] ?? 'N/A',
      quantitySold: json['quantity_sold'] ?? 0,
      freeQuantityGiven: json['free_quantity_given'] ?? 0,
      priceAtSale:
          double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}