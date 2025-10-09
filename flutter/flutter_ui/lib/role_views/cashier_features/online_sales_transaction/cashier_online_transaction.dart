import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.0.104:8000',
);

class OnlineOrdersReportPage extends StatefulWidget {
  const OnlineOrdersReportPage({super.key});

  @override
  State<OnlineOrdersReportPage> createState() => _OnlineOrdersReportPageState();
}

class _OnlineOrdersReportPageState extends State<OnlineOrdersReportPage> {
  late Future<List<dynamic>> _transactionsFuture;
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _transactionsFuture = Future.value([]); // Initialize with an empty list
  }

  Future<List<dynamic>> _fetchCompletedOrders({DateTime? date}) async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    String url = '$API_BASE/api/manager/completed-online-orders/';
    if (date != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      url += '?date=$formattedDate';
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load completed orders. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load completed orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _transactionsFuture = _fetchCompletedOrders(date: date);
    });
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
      _transactionsFuture = _fetchCompletedOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Sales Transaction'),
        centerTitle: false,
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null && pickedDate != _selectedDate) {
                _onDateSelected(pickedDate);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _selectedDate != null
            ? Text(
              'Transactions on: ${DateFormat('MMMM d, y').format(_selectedDate!)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )
            : const Text(
              'Select a Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchCompletedOrders(date: _selectedDate),
              child: FutureBuilder<List<dynamic>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                 if (_selectedDate == null) {
                  return const Center(
                    child: Text('Please select a date to view transactions.',
                    style: TextStyle(fontSize: 16),
                    ),
                  );
                } else if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                  child: Text('No transactions found for this date.'));
                }

                  final completedOrders = snapshot.data!;

                  return ListView.builder(
                    itemCount: completedOrders.length,
                    itemBuilder: (context, index) {
                      final order = completedOrders[index];
                      final orderId = order['order_id'];
                      final customerType = order['customer_type'];
                      final initiatedByName = order['initiated_by_name'] ?? 'N/A';
                      final initiatedByRole = order['initiated_by_role'] ?? 'N/A';
                      final approvedByName = order['approved_by_name'] ?? 'N/A';
                      final approvedByRole = order['approved_by_role'] ?? 'N/A';
                      final totalAmount = order['total_amount'];
                      final subtotalAmount = order['subtotal_amount'] ?? 0.0;
                      final discountAmount = order['discount_amount'] ?? 0.0;
                      final fulfilledTimestampString = order['fulfilled_timestamp'] ?? 'N/A';
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

                      String formattedTimestamp = 'N/A';
                      if (fulfilledTimestampString != 'N/A') {
                        try {
                          final DateTime utcTimestamp = DateTime.parse(fulfilledTimestampString);
                          final location = tz.getLocation('Asia/Manila');
                          final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);
                          formattedTimestamp = DateFormat('yyyy-MM-dd hh:mm a').format(manilaTimestamp);
                        } catch (e) {
                          debugPrint('Error parsing timestamp: $e');
                        }
                      }

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
                                    formattedTimestamp,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Customer Type: $customerType'),
                              Text('Initiated by: $initiatedByName ($initiatedByRole)'),
                              Text('Approved by: $approvedByName ($approvedByRole)'),
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
                              }),
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
                                  Text('-$formattedDiscount', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}