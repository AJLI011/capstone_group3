import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:developer';

const String _baseUrl = 'http://10.0.2.2:8000';

// The helper function _parseMedicineName is removed as it was only used by the removed item models.

// OnlineOrderItem class is removed (as it is no longer used by OnlineOrderDetails)
// InStoreOrderItem class is removed (as it is no longer used by InStoreOrderDetails)

class OnlineOrderDetails {
  final int id;
  final String customerName;
  final String customerEmail;

  OnlineOrderDetails({
    required this.id,
    required this.customerName,
    required this.customerEmail,
  });

  factory OnlineOrderDetails.fromJson(Map<String, dynamic> json) {
    return OnlineOrderDetails(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? 'Unknown',
      customerEmail: json['customer_email'] ?? 'Unknown',
    );
  }
}

class InStoreOrderDetails {
  final int id;
  final String staffName;

  InStoreOrderDetails({
    required this.id,
    required this.staffName,
  });

  factory InStoreOrderDetails.fromJson(Map<String, dynamic> json) {
    return InStoreOrderDetails(
      id: json['id'] ?? 0,
      staffName: json['staff_name'] ?? 'Unknown',
    );
  }
}

class OrderLog {
  final int id;
  final String staffName;
  final String staffRole;
  final String actionType;
  final String description;
  final DateTime timestamp;
  final dynamic orderDetails;

  OrderLog({
    required this.id,
    required this.staffName,
    required this.staffRole,
    required this.actionType,
    required this.description,
    required this.timestamp,
    this.orderDetails,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    dynamic parsedDetails;
    if (json['order_details'] != null) {
      if (json['order_details'].containsKey('customer_name')) {
        parsedDetails = OnlineOrderDetails.fromJson(json['order_details']);
      } else if (json['order_details'].containsKey('staff_name')) {
        parsedDetails = InStoreOrderDetails.fromJson(json['order_details']);
      }
    }

    return OrderLog(
      id: json['id'] ?? 0,
      staffName: json['staff_name'] ?? 'Unknown',
      staffRole: json['staff_role'] ?? 'Unknown',
      actionType: json['action_type'] ?? 'Unknown',
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      orderDetails: parsedDetails,
    );
  }
}


class OrderLogsScreen extends StatefulWidget {
  const OrderLogsScreen({super.key});

  @override
  _OrderLogsScreenState createState() => _OrderLogsScreenState();
}

class _OrderLogsScreenState extends State<OrderLogsScreen> {
  List<OrderLog> _orderLogs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _pageSize = 10;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchInitialOrderLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialOrderLogs() async {
    try {
      final logs = await _fetchOrderLogs(page: 1, pageSize: _pageSize);
      setState(() {
        _orderLogs = logs;
        _isLoading = false;
        _hasMoreData = logs.length == _pageSize;
      });
    } catch (e) {
      log('Error fetching initial logs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreOrderLogs() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final logs = await _fetchOrderLogs(page: _currentPage + 1, pageSize: _pageSize);
      setState(() {
        _orderLogs.addAll(logs);
        _currentPage++;
        _isLoadingMore = false;
        _hasMoreData = logs.length == _pageSize;
      });
    } catch (e) {
      log('Error fetching more logs: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _fetchMoreOrderLogs();
    }
  }

  Future<List<OrderLog>> _fetchOrderLogs({required int page, required int pageSize}) async {
    final url = Uri.parse('$_baseUrl/api/order-logs/?page=$page&page_size=$pageSize');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      log('API Response Status: ${response.statusCode}');
      log('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> logsJson = responseData['results'];
        return logsJson.map((json) => OrderLog.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load order logs: ${response.statusCode}');
      }
    } catch (e) {
      log('Error during API call: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Logs'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderLogs.isEmpty
              ? const Center(child: Text('No order logs found.'))
              : _buildOrderLogsList(),
    );
  }

  Widget _buildOrderLogsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _orderLogs.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orderLogs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final log = _orderLogs[index];
        final isOnlineOrder = log.orderDetails is OnlineOrderDetails;

        IconData actionIcon;
        Color iconColor;
        switch (log.actionType) {
          case 'In-store Purchase':
            actionIcon = Icons.store_rounded;
            iconColor = Colors.green;
            break;
          case 'Online Order':
            actionIcon = Icons.web_rounded;
            iconColor = Colors.blue;
            break;
          case 'Order Cancelled':
            actionIcon = Icons.cancel_rounded;
            iconColor = Colors.red;
            break;
          case 'Order Updated':
            actionIcon = Icons.update_rounded;
            iconColor = Colors.orange;
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
              '${log.actionType.replaceAll('_', ' ')}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            subtitle: Text(
              isOnlineOrder ? (log.orderDetails as OnlineOrderDetails).customerName : log.staffName,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MM-dd-yyyy').format(log.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(log.timestamp),
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
                    const SizedBox(height: 8),
                    Text(
                      'Description: ${log.description}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (log.orderDetails is InStoreOrderDetails)
                      _buildInStoreOrderDetails(log.orderDetails as InStoreOrderDetails)
                    else if (log.orderDetails is OnlineOrderDetails)
                      _buildOnlineOrderDetails(log.orderDetails as OnlineOrderDetails),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInStoreOrderDetails(InStoreOrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('In-Store Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Order ID: #${details.id}'),
      ],
    );
  }

  Widget _buildOnlineOrderDetails(OnlineOrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Online Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Order ID: #${details.id}'),
        Text('Customer: ${details.customerName} (${details.customerEmail})'),
      ],
    );
  }
}