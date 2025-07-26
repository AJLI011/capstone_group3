import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiredStockPage extends StatefulWidget {
  const ExpiredStockPage({Key? key}) : super(key: key);

  @override
  State<ExpiredStockPage> createState() => _ExpiredStockPageState();
}

class _ExpiredStockPageState extends State<ExpiredStockPage> {
  List<dynamic> expiredStocks = [];

  @override
  void initState() {
    super.initState();
    fetchExpiredStocks();
  }

  Future<void> fetchExpiredStocks() async {
    final String url = 'http://10.0.2.2:8000/api/medicines/expired/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          expiredStocks = json.decode(response.body);
        });
      } else {
        print('Failed to load expired stocks. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching expired stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expired Stocks')),
      body: expiredStocks.isEmpty
          ? const Center(child: Text('No expired medicines'))
          : ListView.builder(
              itemCount: expiredStocks.length,
              itemBuilder: (context, index) {
                final stock = expiredStocks[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock['medicine_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Generic: ${stock['generic_name'] ?? 'N/A'}'),
                            Text('Batch: ${stock['batch_num'] ?? 'N/A'}'),
                            Text('Quantity: ${stock['quantity'] ?? '0'}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Right side info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Expires: ${stock['exp_date'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          Text('Supplier: ${stock['supplier_name'] ?? 'N/A'}'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}