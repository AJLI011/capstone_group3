import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoodStockPage extends StatefulWidget {
  const GoodStockPage({Key? key}) : super(key: key);

  @override
  State<GoodStockPage> createState() => _GoodStockPageState();
}

class _GoodStockPageState extends State<GoodStockPage> {
  List<dynamic> goodStockList = [];
  bool isLoading = true;

  final String apiUrl = 'http://10.0.2.2:8000/api/medicines/good-stock/';

  @override
  void initState() {
    super.initState();
    fetchGoodStocks();
  }

  Future<void> fetchGoodStocks() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          goodStockList = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("Failed to load good stocks");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching good stocks: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Good Stocks"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: goodStockList.length,
              itemBuilder: (context, index) {
                final item = goodStockList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade100),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        item['medicine_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Quantity: ${item['quantity']}"),
                          Text("Expiration: ${item['expiration_date']}"),
                          Text("ID: ${item['medicine']}"),
                        ],
                      ),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
