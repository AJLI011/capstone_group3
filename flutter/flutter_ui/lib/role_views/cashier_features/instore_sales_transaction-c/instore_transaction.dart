import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final String _baseUrl = 'http://192.168.0.100:8000';

// Model for individual items within a transaction
class TransactionItem {
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final bool isPromo;
  final double pricePerItem;

  TransactionItem({
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.isPromo,
    required this.pricePerItem,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      medicineName: json['medicine_name'] ?? 'N/A',
      quantitySold: json['quantity_sold'] ?? 0,
      freeQuantityGiven: json['free_quantity_given'] ?? 0,
      isPromo: json['is_promo'] ?? false,
      pricePerItem: double.tryParse(json['price_per_item'].toString()) ?? 0.0,
    );
  }
}

// Main model for the in-store transaction
class InStoreTransaction {
  final int id;
  final DateTime dateCreated;
  final String staffName;
  final String? cashierName;
  final String status;
  final double subtotal;
  final double totalAmount;
  final List<TransactionItem> items;
  final double discountAmount;

  InStoreTransaction({
    required this.id,
    required this.dateCreated,
    required this.staffName,
    this.cashierName,
    required this.status,
    required this.subtotal,
    required this.totalAmount,
    required this.items,
    required this.discountAmount,
  });

  factory InStoreTransaction.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<TransactionItem> parsedItems = itemsList
        .map((itemJson) => TransactionItem.fromJson(itemJson))
        .toList();

    // The backend now sends staff and cashier names as direct strings (or null/empty)
    final staffName = json['staff'] as String? ?? 'N/A';
    // --- START CLEANUP CHANGE ---
    // Use String? cast to correctly handle null from the backend
    final cashierName = json['cashier'] as String?;
    // --- END CLEANUP CHANGE ---

    // Parse the new fields from the backend
    double subtotal = double.tryParse(json['subtotal'].toString()) ?? 0.0;
    double totalAmount = double.tryParse(json['total_amount_after_discount'].toString()) ?? 0.0;
    double discountAmount = double.tryParse(json['discount_amount'].toString()) ?? 0.0;
    
    // Safely parse the 'id' as an integer
    final int id = int.tryParse(json['id'].toString()) ?? 0;

    return InStoreTransaction(
      id: id,
      dateCreated: DateTime.parse(json['date_created']),
      staffName: staffName,
      cashierName: cashierName,
      status: json['status'] ?? 'N/A',
      subtotal: subtotal,
      totalAmount: totalAmount,
      items: parsedItems,
      discountAmount: discountAmount,
    );
  }
}

class InStoreTransactionPage extends StatefulWidget {
  const InStoreTransactionPage({super.key});

  @override
  State<InStoreTransactionPage> createState() => _InStoreTransactionPageState();
}

class _InStoreTransactionPageState extends State<InStoreTransactionPage> {
  late Future<List<InStoreTransaction>> _transactionsFuture;
  final url = '$_baseUrl/api/in-store-transactions/';

  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _transactionsFuture = Future.value([]); // We initialize it with an empty list
  }

  Future<List<InStoreTransaction>> _fetchTransactions({DateTime? date}) async {
    setState(() {
      _isLoading = true;
    });

    String fullUrl = '$_baseUrl/api/in-store-transactions/';
    if (date != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      fullUrl += '?date=$formattedDate';
    }

    try {
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => InStoreTransaction.fromJson(json)).toList();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load transactions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _transactionsFuture = _fetchTransactions(date: date);
    });
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
      _transactionsFuture = Future.value([]); // Set to empty list and rebuild
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-store Order Transactions'),
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
                firstDate: DateTime(2000),
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
              onRefresh: () {
                return _fetchTransactions(date: _selectedDate);
              },
              child: FutureBuilder<List<InStoreTransaction>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (_selectedDate == null) {
                    return const Center(
                      child: Text(
                        'Please select a date to view transactions.',
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

                  final transactions = snapshot.data!;

                  return ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return InStoreTransactionCard(transaction: transaction);
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

class InStoreTransactionCard extends StatelessWidget {
  final InStoreTransaction transaction;

  const InStoreTransactionCard({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTotal = NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(transaction.totalAmount);

    final formattedSubtotal = NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(transaction.subtotal);

    final formattedDiscount = NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(transaction.discountAmount);

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
                  'Order #${transaction.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd hh:mm a').format(
                    tz.TZDateTime.from(
                      transaction.dateCreated,
                      tz.getLocation('Asia/Manila'),
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Staff: ${transaction.staffName}'),
            Text('Cashier: ${transaction.cashierName ?? 'N/A'}'),
            const Divider(height: 20),
            ...transaction.items.map((item) {
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
                            item.medicineName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (item.isPromo)
                            const Text(
                              'Promo',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            )
                          else
                            const Text(
                              'Regular Sale',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          if (item.freeQuantityGiven > 0)
                            Text(
                              'Free: ${item.freeQuantityGiven}',
                              style: const TextStyle(color: Colors.green, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text('x${item.quantitySold}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            NumberFormat.currency(
                              locale: 'en_PH',
                              symbol: '₱',
                              decimalDigits: 2,
                            ).format(item.pricePerItem * item.quantitySold),
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
            if (transaction.discountAmount > 0)
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
  }
}