import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// This is the main screen widget for the cashier's pending orders.
class PendingOrdersScreen extends StatefulWidget {
  final int cashierId;

  const PendingOrdersScreen({Key? key, required this.cashierId})
      : super(key: key);

  @override
  _PendingOrdersScreenState createState() => _PendingOrdersScreenState();
}

// This is the state class that manages the logic and UI for the PendingOrdersScreen.
class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  static const String _baseUrl = "http://10.0.2.2:8000";

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

  // Handles the initial attempt to approve or reject an order.
  // This function is called when the cashier first taps 'Approve'.
  // It checks for a 202 status code from the backend, which indicates a prescription warning.
  Future<void> _processOrder(int orderId, String status) async {
    _showProcessingDialog();

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
      // Success: The order was processed (approved or rejected) without any warnings.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been $status.'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.grey,
        ),
      );
      _refreshOrders();
    } else if (response.statusCode == 202) {
      // Backend warning: A prescription is required. Use the messages from the online order flow.
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

  // This function is specifically for "forcing" an approval.
  // It is only called after the cashier has seen the warning and chosen to proceed.
  Future<void> _forceProcessOrder(int orderId, String status) async {
    _showProcessingDialog();

    final response = await http.put(
      Uri.parse('$_baseUrl/api/sales/pending-orders/$orderId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'cashier_id': widget.cashierId,
        'force_approve': true, // This flag tells the backend to bypass the prescription check.
      }),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been $status.'),
          backgroundColor: Colors.green,
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

  // Displays the warning pop-up for orders that require a prescription but have no uploaded image.
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
                _showConfirmationDialog(orderId, status); // Show final confirmation
              },
            ),
          ],
        );
      },
    );
  }

  // Displays a more detailed warning pop-up when a prescription image is available.
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
                // Example: Image.network('your_image_url_here')
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
                _showConfirmationDialog(orderId, status); // Show final confirmation
              },
            ),
          ],
        );
      },
    );
  }

  // A helper function to show a simple loading dialog while an order is processing.
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Processing..."),
            ],
          ),
        );
      },
    );
  }

  // Displays a standard confirmation dialog before processing an order.
  void _showConfirmationDialog(int orderId, String status) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'Approve Order' : 'Reject Order'),
          content: Text(
            'Are you sure you want to ${status == 'approved' ? 'approve' : 'reject'} order #$orderId?',),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(status == 'approved' ? 'Confirm' : 'Reject'),
              onPressed: () {
                Navigator.of(context).pop();
                _forceProcessOrder(orderId, status); // Call the force-approve function.
              },
            ),
          ],
        );
      },
    );
  }

  // The main build method for the screen, which displays a loading indicator, error, or the list of orders.
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

  // Builds the visual card for a single order. This is where the prescription reminder is displayed.
  Widget _buildOrderCard(InStoreOrder order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initiated by: ${order.staffName} (Staff)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Conditionally display the prescription warning based on the data from the API.
            if (order.hasPrescriptionRequiredItem)
              Row(
                children: const [
                  Icon(Icons.warning, color: Colors.orange),
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
            const SizedBox(height: 16),
            ...order.items.map((item) => _buildOrderItem(item)).toList(),
            const SizedBox(height: 16),
            _buildTotalsSection(order),
            const SizedBox(height: 16),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  // Helper function to build the row for each item in the order.
  Widget _buildOrderItem(InStoreOrderItem item) {
    double itemSubtotal = item.quantitySold * item.priceAtSale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Promo (Qty)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('x${item.quantitySold}'),
              Text(
                item.freeQuantityGiven > 0 ? '${item.freeQuantityGiven}' : '-',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Text(
            '₱${itemSubtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Helper function to build the totals section of the order card.
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
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        if (order.isPwd)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Discount (20%):',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Text(
                '₱${(order.totalAmountBeforeDiscount - order.totalAmountAfterDiscount).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              '₱${order.totalAmountAfterDiscount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // Helper function to build the action buttons (Approve/Reject).
  Widget _buildActionButtons(InStoreOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _processOrder(order.id, 'approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog(order.id, 'rejected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }
}

// Data model class for an in-store order. This is a crucial part of the code
// that maps the JSON data from the API to a Dart object.
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
      // This field is used to display the "Requires Prescription" reminder on the card.
      hasPrescriptionRequiredItem:
          json['has_prescription_required_item'] ?? false,
    );
  }
}

// Data model class for an item within an in-store order.
class InStoreOrderItem {
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final double priceAtSale;

  InStoreOrderItem({
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.priceAtSale,
  });

  factory InStoreOrderItem.fromJson(Map<String, dynamic> json) {
    return InStoreOrderItem(
      medicineName: json['medicine_name'],
      quantitySold: json['quantity_sold'],
      freeQuantityGiven: json['free_quantity_given'],
      priceAtSale:
          double.tryParse(json['price_at_sale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}