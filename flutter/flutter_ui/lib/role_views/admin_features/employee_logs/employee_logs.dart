import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

class EmployeeLogsPage extends StatefulWidget {
  const EmployeeLogsPage({super.key});

  @override
  State<EmployeeLogsPage> createState() => _EmployeeLogsPageState();
}

class _EmployeeLogsPageState extends State<EmployeeLogsPage> {
  bool isLoading = false;
  String? error;
  List<EmployeeLog> logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final url = Uri.parse('$API_BASE/api/employee-logs/');
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final fetched = data.map((e) => EmployeeLog.fromJson(e)).toList();
        setState(() => logs = fetched);
      } else {
        setState(() => error = 'Failed to load logs: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => error = 'Network error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MM/dd/yyyy hh:mm a').format(dt);
    } catch (e) {
      return isoString;
    }
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Access Logs', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRow(EmployeeLog log) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(log.staffName ?? 'Unknown', style: const TextStyle(fontSize: 14))),
          Expanded(flex: 2, child: Text(_prettyRole(log.staffRole), style: const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(flex: 2, child: Text(_prettyAction(log.action), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 3, child: Text(_formatTimestamp(log.timestamp), style: const TextStyle(fontSize: 12, color: Colors.black54))),
        ],
      ),
    );
  }

  String _prettyRole(String? role) {
    if (role == null) return 'Unknown';
    return role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : role;
  }

  String _prettyAction(String action) {
    return action.isNotEmpty ? '${action[0].toUpperCase()}${action.substring(1)}' : action;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Employees Logs'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLogs,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                child: _buildHeaderRow(),
              ),
              const SizedBox(height: 8),
              Expanded( // This is the key change to make the list scrollable
                child: isLoading && logs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _fetchLogs, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : logs.isEmpty
                            ? const Center(child: Text('No logs yet'))
                            : ListView.separated(
                                // Removed shrinkWrap and physics
                                itemCount: logs.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFEFEF)),
                                itemBuilder: (context, i) {
                                  return _buildRow(logs[i]);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeLog {
  final int id;
  final String? staffName;
  final String? staffRole;
  final String action;
  final String timestamp;

  EmployeeLog({
    required this.id,
    this.staffName,
    this.staffRole,
    required this.action,
    required this.timestamp,
  });

  factory EmployeeLog.fromJson(Map<String, dynamic> json) {
    return EmployeeLog(
      id: json['id'],
      staffName: json['staff_name'],
      staffRole: json['staff_role'],
      action: json['action'],
      timestamp: json['timestamp'],
    );
  }
}