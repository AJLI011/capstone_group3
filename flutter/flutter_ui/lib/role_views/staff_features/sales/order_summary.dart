import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'sales_barcode.dart';
import 'package:flutter_ui/role_views/staff_view.dart';

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
      setState(() {
        staffId = widget.staffId;
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        staffId = prefs.getInt('staff_id');
      });
    }
  }

  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  double getSubtotal() {
    return items.fold(
      0.0,
      (sum, item) => sum +
          (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0) *
              (item['quantity_sold'] as int? ?? 0),
    );
  }

  double getDiscount() {
    if (customerType == 'Discounted (20%)') {
      return getSubtotal() * 0.20;
    }
    return 0.0;
  }

  double getTotal() {
    return getSubtotal() - getDiscount();
  }

  // New function to show the confirmation dialog for processing the sale
Future<void> _showProcessConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sale'),
          content: const Text('Are you sure you want to process this sale?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // User cancels
              },
            ),
            //  Changed ElevatedButton to TextButton for a simpler look
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(true); // User confirms
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await processSale(); // Only proceed if the user confirmed
    }
  }

  Future<void> processSale() async {
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot process an empty order.')),
        );
      }
      return;
    }

    _showProcessingDialog();

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStaffId = staffId ?? prefs.getInt('staff_id');

      if (currentStaffId == null) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          _showResultDialog('Error', 'Staff ID not found. Please login again.');
        }
        return;
      }

      final isPwd = customerType == 'Discounted (20%)';

      final orderItems = items.map((item) {
        final isPromo = item['is_promo'] as bool? ?? false;
        final int quantitySold = item['quantity_sold'] as int? ?? 0;
        final int freeQuantityGiven = isPromo ? (item['free_quantity_given'] as int? ?? 0) : 0;

        return {
          'inventory_id': item['inventory_id'],
          'quantity_sold': quantitySold,
          'free_quantity_given': freeQuantityGiven,
        };
      }).toList();

      final payload = {
        'staff': currentStaffId,
        'is_pwd': isPwd,
        'items': orderItems,
      };

      print('Sending payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/sales/process/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (context.mounted) Navigator.of(context).pop();

      if (response.statusCode == 201) {
        if (context.mounted) {
          _showResultDialog('Success!', 'The order has been processed successfully.');
        }
      } else {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final responseBody = json.decode(response.body);
          String errorMessage = 'Unknown error';
          if (responseBody is Map) {
            errorMessage = responseBody['error']?.toString() ??
                responseBody['detail']?.toString() ??
                responseBody.toString();
          } else {
            errorMessage = responseBody.toString();
          }
          if (context.mounted) {
            _showResultDialog('Error', 'Failed to process order: $errorMessage');
          }
        } else {
          if (context.mounted) {
            _showResultDialog(
              'Server Error',
              'The server returned an unexpected response. This usually means there is a problem on the server-side. '
                  'Response status: ${response.statusCode}',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        _showResultDialog('Error', 'An error occurred: $e');
      }
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('Processing Sale...'),
            ],
          ),
        );
      },
    );
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                if (title == 'Success!') {
                  if (staffId != null && context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => StaffView(staffId: staffId!),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Order?'),
          content: const Text(
              'Are you sure you want to go back? The current order will be lost.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Proceed'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (staffId != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => StaffView(staffId: staffId!),
          ),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Summary'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _showBackConfirmationDialog();
            },
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SalesBarcodeScreen(cartItems: items),
                  ),
                );
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final int quantitySold = item['quantity_sold'] as int? ?? 0;
                    final int freeQuantity = item['free_quantity_given'] as int? ?? 0;
                    final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
                    final double amount = price * quantitySold;

                    return Card(
                      elevation: 3,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        title: Text('${item['name']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sold (Qty): $quantitySold'),
                            Text('Free (Qty): $freeQuantity'),
                            Text('Price: ₱${price.toStringAsFixed(2)}'),
                            Text(
                              'Amount: ₱${amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => removeItem(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Customer Type',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: customerType,
                items: const [
                  DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                  DropdownMenuItem(
                      value: 'Discounted (20%)',
                      child: Text('Discounted (20%)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      customerType = value;
                    });
                  }
                },
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    summaryRow('Subtotal', getSubtotal()),
                    summaryRow('Discount', getDiscount(), isNegative: true),
                    const Divider(thickness: 1),
                    summaryRow('Total Amount', getTotal(), isBold: true),
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
                    minimumSize: const Size(double.infinity, 50),
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

  Widget summaryRow(String label, double amount,
      {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '${isNegative ? '-' : ''}₱${amount.toStringAsFixed(2)}',
            style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}