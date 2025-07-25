import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExpiringSoonPage extends StatefulWidget {
  const ExpiringSoonPage({Key? key}) : super(key: key);

  @override
  State<ExpiringSoonPage> createState() => _ExpiringSoonPageState();
}

class _ExpiringSoonPageState extends State<ExpiringSoonPage> {
  List<dynamic> expiringList = [];
  bool isLoading = true;

  final String apiUrl = 'http://10.0.2.2:8000/api/medecines/expiring-soon/';

  @override
  void initState() {
    super.initState();
    fetchExpiringSoon();
  }

  Future<void> fetchExpiringSoon() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          expiringList = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("Failed to load expiring soon data");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching expiring soon: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expiring Soon"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : expiringList.isEmpty
              ? const Center(child: Text("No expiring medicines found."))
              : ListView.builder(
                  itemCount: expiringList.length,
                  itemBuilder: (context, index) {
                    final item = expiringList[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.yellow.shade300),
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
                          trailing: const Icon(Icons.warning_amber, color: Colors.orange),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
