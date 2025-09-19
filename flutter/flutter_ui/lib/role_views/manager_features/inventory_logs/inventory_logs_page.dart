// lib/role_views/manager_features/inventory_logs.dart
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
  bool _isFetchingMore = false; // Prevents multiple simultaneous requests
  int _page = 1; // Tracks the current page number
  bool _hasMoreData = true; // Tracks if there are more pages to load

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _fetchInventoryLogs(isInitial: true);

    // Listen for scroll events
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        // User has scrolled to the bottom
        _loadMoreLogs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  // Renamed the function to be more descriptive and accept a page number
  Future<void> _fetchInventoryLogs({bool isInitial = false}) async {
    if (_isFetchingMore || !_hasMoreData) return;

    if (!isInitial) {
      setState(() {
        _isFetchingMore = true; // Show a loading indicator at the bottom
      });
    }

    final url = 'http://10.0.2.2:8000/api/inventory-logs/?page=$_page';
    
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedLogs = data['results'];
        
        setState(() {
          logs.addAll(fetchedLogs); // Append new logs to the existing list
          _page++; // Increment the page counter
          _hasMoreData = data['next'] != null; // Check if there's a next page
          isLoading = false;
          _isFetchingMore = false;
        });
      } else {
        print('Failed to load logs. Status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      print('Error fetching logs: $e');
      setState(() {
        isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  // A dedicated method to handle loading more data
  void _loadMoreLogs() {
    if (!_isFetchingMore && _hasMoreData) {
      _fetchInventoryLogs();
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
      controller: _scrollController,
      itemCount: logs.length + (_hasMoreData ? 1 : 0), // Add 1 for the loading indicator
      itemBuilder: (context, index) {
        if (index == logs.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final log = logs[index];
        final DateTime utcTimestamp = DateTime.parse(log['timestamp']).toUtc();
        final location = tz.getLocation('Asia/Manila');
        final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, location);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ExpansionTile(
            title: Text(
              '${log['action_type']} by ${log['user_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('MM-dd-yyyy hh:mm a').format(manilaTimestamp)),
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