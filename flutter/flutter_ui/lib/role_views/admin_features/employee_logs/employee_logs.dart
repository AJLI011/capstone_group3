import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz; // NEW: Timezone data import
import 'package:timezone/timezone.dart' as tz; // NEW: Timezone functionality import

// -------------------------------------------------------------------
// Constants and Model
// -------------------------------------------------------------------

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.0.100:8000',
);

// Define the primary color for consistency
const Color _primaryColor = Color(0xFF5C7C9A);

class EmployeeLog {
  final int id;
  // These fields are correctly defined to receive the snapshot data
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
      id: json['id'] as int,
      // Mapping the snapshot fields from the API response
      staffName: json['staff_name'] as String?,
      staffRole: json['staff_role'] as String?,
      action: json['action'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

// -------------------------------------------------------------------
// Employee Logs Page
// -------------------------------------------------------------------

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
  final List<EmployeeLog> _logs = [];
  final ScrollController _scrollController = ScrollController();

  // --- Lifecycle & Initialization ---

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // NEW: Initialize timezone data
    _fetchLogs();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // NEW: Helper function to convert UTC string to Asia/Manila time
  tz.TZDateTime _convertToManilaTime(String timestamp) {
    // 1. Parse the string and convert it to UTC (assuming backend timestamps are UTC or naive)
    final DateTime utcTimestamp = DateTime.parse(timestamp).toUtc();
    // 2. Get the target timezone location
    final location = tz.getLocation('Asia/Manila');
    // 3. Convert the UTC timestamp to the Manila timezone
    return tz.TZDateTime.from(utcTimestamp, location);
  }

  // --- Handlers ---

  /// Listener for infinite scrolling.
  void _scrollListener() {
    // Check if the user is at the bottom of the list
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoading) {
      _fetchLogs();
    }
  }

  /// Fetches logs from the API with pagination.
  Future<void> _fetchLogs({bool isRefresh = false}) async {
    if (_isLoading || (!_hasMore && !isRefresh)) return;

    if (isRefresh) {
      // Reset for a full refresh
      _page = 1;
      _logs.clear();
      _hasMore = true;
    }

    // Use a temporary state for `isRefresh` to avoid hiding existing data while refreshing
    setState(() {
      _isLoading = true;
      if (isRefresh) _error = null;
    });

    try {
      final url =
          Uri.parse('$API_BASE/api/employee-logs/?page=$_page&page_size=$_pageSize');
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final fetched = data.map((e) => EmployeeLog.fromJson(e)).toList();

        if (mounted) {
          setState(() {
            _logs.addAll(fetched);
            _page++;
            _hasMore = fetched.length == _pageSize;
          });
        }
      } else {
        if (mounted) {
          setState(() => _error = 'Failed to load logs: ${resp.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Network error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Formats the ISO 8601 timestamp string into a readable Asia/Manila date/time.
  // MODIFIED: Uses the new timezone helper function
  String _formatTimestamp(String isoString) {
    try {
      final manilaTime = _convertToManilaTime(isoString);
      return DateFormat('MMM d, yyyy h:mm a').format(manilaTime);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  /// Capitalizes the first letter of the role.
  String _prettyRole(String? role) {
    // Correctly uses the snapshot field
    if (role == null || role.isEmpty) return 'N/A';
    return role[0].toUpperCase() + role.substring(1);
  }

  /// Capitalizes the first letter of the action.
  String _prettyAction(String action) {
    if (action.isEmpty) return 'N/A';
    return action[0].toUpperCase() + action.substring(1);
  }

  // --- UI Builder Methods ---

  /// Builds the sticky header row for the log table.
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08), // Slightly tinted background
        border: const Border(bottom: BorderSide(color: Color(0xFFDCDCDC), width: 1.5)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text('STAFF NAME',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _primaryColor)),
          ),
          Expanded(
            flex: 2,
            child: Text('ROLE',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _primaryColor)),
          ),
          Expanded(
            flex: 2,
            child: Text('ACTION',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _primaryColor)),
          ),
          Expanded(
            flex: 3,
            child: Text('DATE & TIME',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  /// Builds a single data row for an employee log entry.
  Widget _buildRow(EmployeeLog log) {
    // Style the action text for visual emphasis
    TextStyle actionStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: (log.action == 'login') ? Colors.green.shade700 : Colors.red.shade700,
    );
    
    // Determine the row color based on index for professional striping
    final isEven = _logs.indexOf(log) % 2 == 0;
    final rowColor = isEven ? Colors.white : const Color(0xFFF7F7F7); // Light striping

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: rowColor,
      child: Row(
        children: [
          Expanded(
            // Correctly uses the staffName snapshot field
              flex: 3,
              child: Text(log.staffName ?? 'Unknown Staff',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500))),
          Expanded(
            // Correctly uses the staffRole snapshot field
              flex: 2,
              child: Text(_prettyRole(log.staffRole),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Expanded(
              flex: 2,
              child: Text(_prettyAction(log.action), style: actionStyle)),
          Expanded(
              flex: 3,
              // MODIFIED: Calls the new timezone-aware format function
              child: Text(_formatTimestamp(log.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        ],
      ),
    );
  }

  /// Builds the list view content, including state handling.
  Widget _buildLogList() {
    if (_logs.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_error != null && _logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _fetchLogs(isRefresh: true),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_logs.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('No employee logs available.',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      ));
    }

    // Actual Log List with infinite scrolling and loading indicator
    return ListView.builder(
      controller: _scrollController,
      itemCount: _logs.length + (_hasMore ? 1 : 0), // +1 for the indicator
      itemBuilder: (context, i) {
        if (i == _logs.length) {
          // The loading indicator at the end of the list
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _primaryColor))),
          );
        }
        return _buildRow(_logs[i]);
      },
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Employee Access Logs',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4, // Added elevation for a formal look
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header (Now built into its own method for better styling)
            _buildHeaderRow(),
            
            // Log List (Wrapped in RefreshIndicator)
            Expanded(
              child: RefreshIndicator(
                color: _primaryColor,
                onRefresh: () => _fetchLogs(isRefresh: true),
                child: _buildLogList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}