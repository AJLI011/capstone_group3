import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
    tz.initializeTimeZones();
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
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
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

        final DateTime utcTimestamp = DateTime.parse(log['timestamp']).toUtc();
        final location = tz.getLocation('Asia/Manila');
        final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);
        
        // Determine the icon and color based on the action type
        IconData actionIcon;
        Color iconColor;
        switch (log['action_type']) {
          case 'added':
            actionIcon = Icons.add_box_rounded;
            iconColor = Colors.green;
            break;
          case 'removed':
            actionIcon = Icons.remove_circle_rounded;
            iconColor = Colors.red;
            break;
          case 'updated':
            actionIcon = Icons.update_rounded;
            iconColor = Colors.blue;
            break;
          default:
            actionIcon = Icons.info_outline;
            iconColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ExpansionTile(
            leading: Icon(
              actionIcon,
              color: iconColor,
              size: 30,
            ),
            title: Text(
              '${log['action_type']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            subtitle: Text(
              '${log['user_name']}',
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MM-dd-yyyy').format(manilaTimestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(manilaTimestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            children: <Widget>[
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine: ${log['medicine_name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Description: ${log['description']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
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