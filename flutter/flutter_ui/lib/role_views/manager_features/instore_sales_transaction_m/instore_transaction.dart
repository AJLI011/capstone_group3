import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  final String staff;
  final String cashier;
  final String status;
  final double subtotal;
  final double totalAmount;
  final List<TransactionItem> items;
  final double discountAmount;

  InStoreTransaction({
    required this.id,
    required this.dateCreated,
    required this.staff,
    required this.cashier,
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

    return InStoreTransaction(
      id: json['id'],
      dateCreated: DateTime.parse(json['date_created']),
      staff: json['staff'] ?? 'N/A',
      cashier: json['cashier'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0.0,
      totalAmount: double.tryParse(json['total_amount_after_discount'].toString()) ?? 0.0,
      items: parsedItems,
      discountAmount: double.tryParse(json['discount_amount'].toString()) ?? 0.0,
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
  final String _apiUrl = 'https://aaron.pythonanywhere.com/api/in-store-transactions/';

  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _fetchTransactions();
  }

  Future<List<InStoreTransaction>> _fetchTransactions({DateTime? date}) async {
    setState(() {
      _isLoading = true;
    });

    String url = _apiUrl;
    if (date != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      url += '?date=$formattedDate';
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => InStoreTransaction.fromJson(json)).toList();
      } else {
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
      _transactionsFuture = _fetchTransactions();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('In-store Order Transactions'),
          centerTitle: false,
          backgroundColor: const Color(0xFF5C7C9A), // Updated color
          foregroundColor: Colors.white, // Updated color for font and icon
        ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'Select a Date'
                          : 'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: _clearFilter,
                    ),
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
                ],
              ),
            ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  // If a date is selected, refresh with the same date
                  // Otherwise, refresh with no date (all transactions)
                  return _fetchTransactions(date: _selectedDate);
                },
                child: FutureBuilder<List<InStoreTransaction>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (_isLoading && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No transactions found.'));
                    }
            
                    final transactions = snapshot.data!;
            
                    return ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return ExpandableTransactionCard(transaction: transaction);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpandableTransactionCard extends StatefulWidget {
  final InStoreTransaction transaction;

  const ExpandableTransactionCard({
    super.key,
    required this.transaction,
  });

  @override
  State<ExpandableTransactionCard> createState() => _ExpandableTransactionCardState();
}

class _ExpandableTransactionCardState extends State<ExpandableTransactionCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotation = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${widget.transaction.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(widget.transaction.dateCreated),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Text('₱${widget.transaction.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        widget.transaction.status.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(widget.transaction.status),
                        ),
                      ),
                      RotationTransition(
                        turns: _rotation,
                        child: const Icon(Icons.expand_more, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Staff: ${widget.transaction.staff}'),
                    Text('Cashier: ${widget.transaction.cashier}'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...widget.transaction.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(child: Text('   ${item.medicineName}')),
                        Text('x${item.quantitySold}'),
                        if (item.freeQuantityGiven > 0)
                          Text(' +${item.freeQuantityGiven} free'),
                        const SizedBox(width: 8),
                        Text('₱${item.pricePerItem.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('₱${widget.transaction.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                if (widget.transaction.discountAmount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount:'),
                      Text('-₱${widget.transaction.discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '₱${widget.transaction.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}