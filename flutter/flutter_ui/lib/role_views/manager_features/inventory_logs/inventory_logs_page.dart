import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? const Center(child: Text('No logs available.'))
              : _buildInventoryLogsList(logs),
    );
  }

  Widget _buildInventoryLogsList(List<dynamic> logs) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final timestamp = DateTime.parse(log['timestamp']);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ExpansionTile(
            title: Text(
              '${log['action_type']} by ${log['user_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('MM-dd-yyyy hh:mm a').format(timestamp)),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description: ${log['description']}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Medicine: ${log['medicine_name']}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}