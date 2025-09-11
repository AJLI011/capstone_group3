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
  // Paging variables
  int _page = 1;
  static const int _pageSize = 10;
  bool _isLoading = false;
  bool _hasMore = true; // Indicates if there are more logs to load
  String? _error;
  List<EmployeeLog> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollController.addListener(() {
      // Check if the user is at the bottom of the list
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _fetchLogs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({bool isRefresh = false}) async {
    if (_isLoading || !_hasMore && !isRefresh) return;

    if (isRefresh) {
      // Reset for a full refresh
      _page = 1;
      _logs.clear();
      _hasMore = true;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$API_BASE/api/employee-logs/?page=$_page&page_size=$_pageSize');
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final fetched = data.map((e) => EmployeeLog.fromJson(e)).toList();
        
        setState(() {
          _logs.addAll(fetched);
          _page++;
          _hasMore = fetched.length == _pageSize;
        });
      } else {
        setState(() => _error = 'Failed to load logs: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isLoading = false);
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
          onRefresh: () => _fetchLogs(isRefresh: true),
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
              Expanded(
                child: _logs.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: () => _fetchLogs(isRefresh: true), child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _logs.isEmpty
                            ? const Center(child: Text('No logs yet'))
                            : ListView.separated(
                                controller: _scrollController,
                                itemCount: _logs.length + (_hasMore ? 1 : 0), // Add 1 for the loading indicator
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFEFEF)),
                                itemBuilder: (context, i) {
                                  // Check if it's the last item and we're still loading/have more
                                  if (i == _logs.length && _hasMore) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  return _buildRow(_logs[i]);
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