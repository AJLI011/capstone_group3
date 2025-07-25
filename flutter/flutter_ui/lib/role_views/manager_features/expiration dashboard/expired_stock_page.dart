import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiredStockPage extends StatefulWidget {
  const ExpiredStockPage({Key? key}) : super(key: key);

  @override
  State<ExpiredStockPage> createState() => _ExpiredStockPageState();
}

class _ExpiredStockPageState extends State<ExpiredStockPage> {
  List<dynamic> expiredList = [];
  bool isLoading = true;

  final String apiUrl = 'http://10.0.2.2:8000/api/medicines/expired/';

  @override
  void initState() {
    super.initState();
    fetchExpiredStocks();
  }

  Future<void> fetchExpiredStocks() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          expiredList = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("Failed to load expired stocks");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching expired stocks: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expired Stocks"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : expiredList.isEmpty
              ? const Center(child: Text("No expired medicines found."))
              : ListView.builder(
                  itemCount: expiredList.length,
                  itemBuilder: (context, index) {
                    final item = expiredList[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.shade300),
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
                          trailing: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
