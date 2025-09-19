// order_summary.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'sales_barcode.dart';
import 'package:flutter_ui/role_views/staff_view.dart';

// Define the API_BASE constant
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000/',
);

class OrderSummaryPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int? staffId;

  const OrderSummaryPage({
    super.key,
    required this.cartItems,
    this.staffId,
  });

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  List<Map<String, dynamic>> items = [];
  String customerType = 'Regular';
  int? staffId;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.cartItems);
    _loadStaffId();
  }

  Future<void> _loadStaffId() async {
    if (widget.staffId != null) {
      staffId = widget.staffId;
    } else {
      final prefs = await SharedPreferences.getInstance();
      staffId = prefs.getInt('staff_id');
    }
    setState(() {});
  }

  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  double getSubtotal() {
    return items.fold(0.0, (sum, item) {
      final price = double.tryParse(item['price'].toString()) ?? 0.0;
      return sum + (price * (item['quantity_sold'] ?? 0));
    });
  }

  double getDiscount() {
    return customerType == 'Discounted (20%)' ? getSubtotal() * 0.20 : 0.0;
  }

  double getTotal() {
    return getSubtotal() - getDiscount();
  }

  // New method for item removal confirmation
  Future<void> _showRemoveConfirmationDialog(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item?'),
        content: const Text('Are you sure you want to remove this item from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeItem(index);
    }
  }

  Future<void> _showProcessConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Sale'),
        content: const Text('Are you sure you want to process this sale?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) await _processSale();
  }

  Future<void> _processSale() async {
    if (items.isEmpty || staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid staff or empty cart')),
      );
      return;
    }

    _showProcessingDialog();

    try {
      final payload = {
        'staff': staffId,
        'is_pwd': customerType == 'Discounted (20%)',
        'items': items.map((item) {
          final isPromo = item['is_promo'] == true || item['is_promo'] == 1;

          return {
            'inventory_id': item['inventory_id'],
            'medicine_id': item['medicine_id'], // This line was added
            'quantity_sold': item['quantity_sold'],
            'free_quantity_given': isPromo ? (item['free_quantity_given'] ?? 0) : 0,
          };
        }).toList(),
      };

      // Use the API_BASE constant to build the URL
      final response = await http.post(
        Uri.parse('${API_BASE}api/sales/process/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (response.statusCode == 201) {
        _showResultDialog('Success', 'Order processed successfully.');
      } else {
        final body = json.decode(response.body);
        String errorMessage;
        if (body['error'] is Map) {
          errorMessage = body['error'].values.map((v) => v.join(' ')).join('\n');
        } else {
          errorMessage = body['error']?.toString() ?? 'Unknown error occurred.';
        }
        _showResultDialog('Error', errorMessage);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showResultDialog('Error', 'An error occurred: $e');
      }
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Processing...')]),
      ),
    );
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              if (title == 'Success' && staffId != null) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => StaffView(staffId: staffId!)),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showBackConfirmationDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Order?'),
        content: const Text('Going back will discard the current cart. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
        ],
      ),
    );

    if (confirm == true && staffId != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => StaffView(staffId: staffId!)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Summary'),
          backgroundColor: const Color(0xFF5C7C9A), // Updated color
          foregroundColor: Colors.white, // Updated color for font and icon

          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _showBackConfirmationDialog),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesBarcodeScreen(
                      staffId: staffId,
                      cartItems: items,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final price = double.tryParse(item['price'].toString()) ?? 0.0;
                    final qty = item['quantity_sold'] ?? 0;
                    final promo = item['free_quantity_given'] ?? 0;
                    final amount = price * qty;

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        title: Text(item['name'] ?? 'No name'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sold: $qty'),
                            Text('Promo: $promo'),
                            Text('Price: ₱${price.toStringAsFixed(2)}'),
                            Text('Amount: ₱${amount.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _showRemoveConfirmationDialog(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: customerType,
                items: const [
                  DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                  DropdownMenuItem(value: 'Discounted (20%)', child: Text('Discounted (20%)')),
                ],
                onChanged: (value) => setState(() => customerType = value!),
                decoration: const InputDecoration(
                  labelText: 'Customer Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    summaryRow('Subtotal', getSubtotal()),
                    summaryRow('Discount', getDiscount(), isNegative: true),
                    const Divider(thickness: 1),
                    summaryRow('Total', getTotal(), isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: items.isNotEmpty ? _showProcessConfirmationDialog : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Process Sale'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget summaryRow(String label, double amount, {bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        Text(
          '${isNegative ? '-' : ''}₱${amount.toStringAsFixed(2)}',
          style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      ],
    );
  }
}