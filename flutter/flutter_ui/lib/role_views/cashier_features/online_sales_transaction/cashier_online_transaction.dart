import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://jallybee.pythonanywhere.com',
);

class CashierOnlineTransactionPage extends StatefulWidget {
  const CashierOnlineTransactionPage({super.key});

  @override
  State<CashierOnlineTransactionPage> createState() => _CashierOnlineTransactionPageState();
}

class _CashierOnlineTransactionPageState extends State<CashierOnlineTransactionPage> {
  List<dynamic> completedOrders = [];
  bool isLoading = true;
  String? errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Fetch orders for the current date when the page first loads.
    _fetchCompletedOrdersForSelectedDate();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Fetch orders for the newly selected date.
      _fetchCompletedOrdersForSelectedDate();
    }
  }

  Future<void> _fetchCompletedOrdersForSelectedDate() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final uri = Uri.parse('$API_BASE/api/manager/completed-online-orders/').replace(
        queryParameters: {'date': formattedDate},
      );
      
      debugPrint('Fetching: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          completedOrders = data;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load completed orders. Status code: ${response.statusCode}';
          debugPrint('API Error: ${response.body}');
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect to the server. Please check your network.';
        debugPrint('Network Error: $e');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Sales Transaction'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Transactions on: ${DateFormat('MMMM d, y').format(_selectedDate)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // This is the code block that handles the message when no orders are found.
        if (completedOrders.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No completed online orders found for this date.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: completedOrders.length,
              itemBuilder: (context, index) {
                final order = completedOrders[index];
                final orderId = order['order_id'];
                final customerType = order['customer_type'];
                
                // ---- START OF CHANGES ----
                // Retrieve the new fields from the updated Django API response
                final initiatedByName = order['initiated_by_name'] ?? 'N/A';
                final initiatedByRole = order['initiated_by_role'] ?? 'N/A';
                final approvedByName = order['approved_by_name'] ?? 'N/A';
                final approvedByRole = order['approved_by_role'] ?? 'N/A';
                // ---- END OF CHANGES ----

                final totalAmount = order['total_amount'];
                final subtotalAmount = order['subtotal_amount'] ?? 0.0;
                final discountAmount = order['discount_amount'] ?? 0.0;
                final fulfilledTimestamp = order['fulfilled_timestamp'] ?? 'N/A';
                final items = order['medicines_ordered'] as List<dynamic>;

                final formattedTotal = NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                  decimalDigits: 2,
                ).format(totalAmount);

                final formattedSubtotal = NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                  decimalDigits: 2,
                ).format(subtotalAmount);

                final formattedDiscount = NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                  decimalDigits: 2,
                ).format(discountAmount);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #$orderId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              fulfilledTimestamp,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text('Customer Type: $customerType'),
                        
                        // ---- START OF CHANGES ----
                        // Display the name and role from the new fields
                        Text('Initiated by: $initiatedByName ($initiatedByRole)'),
                        Text('Approved by: $approvedByName ($approvedByRole)'),
                        // ---- END OF CHANGES ----
                        
                        const Divider(height: 20),

                        ...items.map((item) {
                          final medicineName = item['medicine_name'];
                          final promoQuantity = item['promo_quantity'];
                          final itemTotal = NumberFormat.currency(
                            locale: 'en_PH',
                            symbol: '₱',
                            decimalDigits: 2,
                          ).format(item['item_total'] ?? 0.0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$medicineName',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        promoQuantity > 0 ? 'Promo (Qty: $promoQuantity)' : 'Regular Sale',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text('x${item['quantity_ordered']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        itemTotal,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(formattedSubtotal, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount (20%):', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('-$formattedDiscount', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              formattedTotal,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}