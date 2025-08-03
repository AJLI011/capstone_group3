import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InventoryLogsPage extends StatefulWidget {
  const InventoryLogsPage({Key? key}) : super(key: key);

  @override
  State<InventoryLogsPage> createState() => _InventoryLogsPageState();
}

class _InventoryLogsPageState extends State<InventoryLogsPage> {
  List<dynamic> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInventoryLogs();
  }

  Future<void> fetchInventoryLogs() async {
    const url = 'http://10.0.2.2:8000/api/inventory-logs/';
    
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          logs = data;
          isLoading = false;
        });
      } else {
        print('Failed to load logs. Status code: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching logs: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Logs'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? const Center(child: Text('No logs available.'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Colors.teal),
                        title: Text(
                          log['description'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User: ${log['user_name']}'),
                            Text('Medicine: ${log['medicine_name']}'),
                            Text('Action: ${log['action_type']}'),
                            Text('Time: ${log['timestamp']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
