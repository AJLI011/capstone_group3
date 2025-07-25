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
                return ListTile(
                  title: Text(stock['medicine_name']),
                  subtitle: Text('Batch: ${stock['batch_num']} | Qty: ${stock['quantity']}'),
                  trailing: Text('Expired: ${stock['exp_date']}'),
                  tileColor: Colors.red[50],
                );
              },
            ),
    );
  }
}
