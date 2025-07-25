import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiringSoonPage extends StatefulWidget {
  const ExpiringSoonPage({Key? key}) : super(key: key);

  @override
  State<ExpiringSoonPage> createState() => _ExpiringSoonPageState();
}

class _ExpiringSoonPageState extends State<ExpiringSoonPage> {
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
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: expiringSoonStocks.length,
              itemBuilder: (context, index) {
                final stock = expiringSoonStocks[index];
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
