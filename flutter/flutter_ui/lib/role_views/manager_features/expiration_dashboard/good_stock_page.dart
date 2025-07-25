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
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: goodStocks.length,
              itemBuilder: (context, index) {
                final stock = goodStocks[index];
                return ListTile(
                  title: Text(stock['medicine_name']),
                  subtitle: Text('Batch: ${stock['batch_num']} | Qty: ${stock['quantity']}'),
                  trailing: Text('Expires: ${stock['exp_date']}'),
                );
              },
            ),
    );
  }
}
