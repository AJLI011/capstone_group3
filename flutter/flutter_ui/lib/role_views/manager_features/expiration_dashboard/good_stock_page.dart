import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoodStockPage extends StatefulWidget {
  const GoodStockPage({Key? key}) : super(key: key);

  @override
  State<GoodStockPage> createState() => _GoodStockPageState();
}

class _GoodStockPageState extends State<GoodStockPage> {
  List<dynamic> goodStocks = [];

  @override
  void initState() {
    super.initState();
    fetchGoodStocks();
  }

  Future<void> fetchGoodStocks() async {
    final String url = 'http://10.0.2.2:8000/api/medicines/good-stock/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          goodStocks = json.decode(response.body);
        });
      } else {
        print('Failed to load good stocks. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching good stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Good Stocks')),
      body: goodStocks.isEmpty
          ? const Center(child: Text('No good stock medicines'))
          : ListView.builder(
              itemCount: goodStocks.length,
              itemBuilder: (context, index) {
                final stock = goodStocks[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
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
                            style: const TextStyle(color: Colors.green),
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
