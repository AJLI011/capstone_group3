import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiredStockPage extends StatefulWidget {
  const ExpiredStockPage({Key? key}) : super(key: key);

  @override
  State<ExpiredStockPage> createState() => _ExpiredStockPageState();
}

class _ExpiredStockPageState extends State<ExpiredStockPage> {
  // Original list of all expired stocks fetched from the API
  List<dynamic> allExpiredStocks = [];
  // List to display in the UI, filtered by the search query
  List<dynamic> filteredExpiredStocks = [];
  // Controller for the search bar
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchExpiredStocks();
    // Add a listener to the search controller to filter the list as the user types
    searchController.addListener(filterExpiredStocks);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    searchController.dispose();
    super.dispose();
  }

  // Method to filter the list based on the search query
  void filterExpiredStocks() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredExpiredStocks = allExpiredStocks.where((stock) {
        final medicineName = stock['medicine_name']?.toLowerCase() ?? '';
        final genericName = stock['generic_name']?.toLowerCase() ?? '';
        return medicineName.contains(query) || genericName.contains(query);
      }).toList();
    });
  }

  Future<void> fetchExpiredStocks() async {
    final String url = 'http://10.0.2.2:8000/api/medicines/expired/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedData = json.decode(response.body);

        // Apply FEFO sorting here (oldest expired first)
        fetchedData.sort((a, b) {
          final dateA = a['exp_date'] != null ? DateTime.tryParse(a['exp_date']) : null;
          final dateB = b['exp_date'] != null ? DateTime.tryParse(b['exp_date']) : null;
          
          if (dateA != null && dateB != null) {
            return dateA.compareTo(dateB);
          }
          if (dateA == null && dateB != null) {
            return 1;
          }
          if (dateA != null && dateB == null) {
            return -1;
          }
          return 0;
        });

        setState(() {
          // Store the sorted data in both lists
          allExpiredStocks = fetchedData;
          filteredExpiredStocks = fetchedData;
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
      appBar: AppBar(
        title: const Text('Expired Stocks'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search expired medicine...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: filteredExpiredStocks.isEmpty
                ? const Center(child: Text('No expired medicines'))
                : ListView.builder(
                    itemCount: filteredExpiredStocks.length,
                    itemBuilder: (context, index) {
                      final stock = filteredExpiredStocks[index];
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
                                  'Expired on: ${stock['exp_date'] ?? 'N/A'}',
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
          ),
        ],
      ),
    );
  }
}