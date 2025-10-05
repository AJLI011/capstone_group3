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
    String? nextUrl = 'http://10.0.2.2:8000/api/inventory-logs/';
    List<dynamic> allLogs = [];

    try {
      while (nextUrl != null) {
        final response = await http.get(Uri.parse(nextUrl));

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          
          allLogs.addAll(responseData['results']);
          nextUrl = responseData['next'];
        } else {
          print('Failed to load logs. Status code: ${response.statusCode}');
          nextUrl = null; // Stop fetching on failure
        }
      }

      setState(() {
        logs = allLogs;
        isLoading = false;
      });
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
          case 'Add':
          case 'Restock':
            actionIcon = Icons.add_box_rounded;
            iconColor = Colors.green;
            break;
          case 'Delete': // Added 'Delete' case
          case 'removed':
          case 'Sold':
          case 'Expiration Return':
            actionIcon = Icons.remove_circle_rounded;
            iconColor = Colors.red;
            break;
          case 'updated':
          case 'Promo Set':
          case 'Promo Removed':
            actionIcon = Icons.update_rounded;
            iconColor = Colors.blue;
            break;
          default:
            actionIcon = Icons.info_outline;
            iconColor = Colors.grey;
        }

        // Determine the medicine name text based on whether it's null
        String medicineNameText;
        if (log['medicine_name'] == null && log['action_type'] == 'Delete') {
          medicineNameText = 'Medicine: Not available (deleted)';
        } else {
          medicineNameText = 'Medicine: ${log['medicine_name']}';
        }
        
        // --- START: MODIFIED FOR STAFF SNAPSHOT ---
        // Use the new staff snapshot fields from the Django API response
        final String staffName = log['staff_name'] ?? 'Unknown Staff';
        final String staffRole = log['staff_role'] ?? 'N/A';
        // --- END: MODIFIED FOR STAFF SNAPSHOT ---

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
              // MODIFIED LINE: Use the robust staffName snapshot
              '$staffName (${staffRole})',
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
                      medicineNameText, // Use the new variable here
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