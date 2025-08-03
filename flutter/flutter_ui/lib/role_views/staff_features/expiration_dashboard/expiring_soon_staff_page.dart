import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiringSoonStaffPage extends StatefulWidget {
  const ExpiringSoonStaffPage({Key? key}) : super(key: key);

  @override
  State<ExpiringSoonStaffPage> createState() => _ExpiringSoonStaffPageState();
}

class _ExpiringSoonStaffPageState extends State<ExpiringSoonStaffPage> {
  List<dynamic> expiringSoonStocks = [];

  @override
  void initState() {
    super.initState();
    fetchExpiringSoonStocks();
  }

  Future<void> fetchExpiringSoonStocks() async {
    final String url = 'http://10.0.2.2:8000/api/medicines/expiring-soon/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          expiringSoonStocks = json.decode(response.body);
        });
      } else {
        print('Failed to load expiring soon stocks. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching expiring soon stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expiring Soon')),
      body: expiringSoonStocks.isEmpty
          ? const Center(child: Text('No medicines expiring soon'))
          : ListView.builder(
              itemCount: expiringSoonStocks.length,
              itemBuilder: (context, index) {
                final stock = expiringSoonStocks[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Expires: ${stock['exp_date'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.orange),
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
