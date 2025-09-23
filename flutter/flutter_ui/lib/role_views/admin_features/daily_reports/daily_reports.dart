// daily_reports.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_ui/services/pdf_daily_report_service.dart';

// --- Data Models (Keep as is) ---
class DailyReport {
  final List<EmployeeLog> employeeLogs;
  final List<OrderLog> orderLogs;
  final List<InventoryLog> inventoryLogs;

  DailyReport({
    required this.employeeLogs,
    required this.orderLogs,
    required this.inventoryLogs,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      employeeLogs: (json['employee_logs'] as List)
          .map((e) => EmployeeLog.fromJson(e))
          .toList(),
      orderLogs: (json['order_logs'] as List)
          .map((e) => OrderLog.fromJson(e))
          .toList(),
      inventoryLogs: (json['inventory_logs'] as List)
          .map((e) => InventoryLog.fromJson(e))
          .toList(),
    );
  }
}

class EmployeeLog {
  final int id;
  final String staffName;
  final String action;
  final String timestamp;

  EmployeeLog({
    required this.id,
    required this.staffName,
    required this.action,
    required this.timestamp,
  });

  factory EmployeeLog.fromJson(Map<String, dynamic> json) {
    return EmployeeLog(
      id: json['id'],
      staffName: json['staff_name'] ?? 'N/A',
      action: json['action'] ?? 'N/A',
      timestamp: json['timestamp'],
    );
  }
}

class OrderLog {
  final int id;
  final String? staffUserName;
  final String actionType;
  final String? description;
  final String timestamp;
  final InStoreOrderDetails? inStoreOrderDetails;
  final OnlineOrderDetails? onlineOrderDetails;

  OrderLog({
    required this.id,
    this.staffUserName,
    required this.actionType,
    this.description,
    required this.timestamp,
    this.inStoreOrderDetails,
    this.onlineOrderDetails,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    return OrderLog(
      id: json['id'],
      staffUserName: json['staff_user']?['name'],
      actionType: json['action_type'] ?? 'N/A',
      description: json['description'],
      timestamp: json['timestamp'],
      inStoreOrderDetails: json['in_store_order_details'] != null
          ? InStoreOrderDetails.fromJson(json['in_store_order_details'])
          : null,
      onlineOrderDetails: json['online_order_details'] != null
          ? OnlineOrderDetails.fromJson(json['online_order_details'])
          : null,
    );
  }
}

class InStoreOrderDetails {
  final int id;
  final String dateCreated;
  final double totalAmountAfterDiscount;

  InStoreOrderDetails({
    required this.id,
    required this.dateCreated,
    required this.totalAmountAfterDiscount,
  });

  factory InStoreOrderDetails.fromJson(Map<String, dynamic> json) {
    return InStoreOrderDetails(
      id: json['id'],
      dateCreated: json['date_created'],
      totalAmountAfterDiscount:
          json['total_amount_after_discount']?.toDouble() ?? 0.0,
    );
  }
}

class OnlineOrderDetails {
  final int id;
  final String dateCreated;
  final String customerName;
  final double totalAmountAfterDiscount;

  OnlineOrderDetails({
    required this.id,
    required this.dateCreated,
    required this.customerName,
    required this.totalAmountAfterDiscount,
  });

  factory OnlineOrderDetails.fromJson(Map<String, dynamic> json) {
    return OnlineOrderDetails(
      id: json['id'],
      dateCreated: json['date_created'],
      customerName: json['customer_name'] ?? 'N/A',
      totalAmountAfterDiscount:
          json['total_amount_after_discount']?.toDouble() ?? 0.0,
    );
  }
}

class InventoryLog {
  final int id;
  final String actionType;
  final String? description;
  final String timestamp;
  final String? userName;
  final String? medicineName;

  InventoryLog({
    required this.id,
    required this.actionType,
    this.description,
    required this.timestamp,
    this.userName,
    this.medicineName,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    return InventoryLog(
      id: json['id'],
      actionType: json['action_type'] ?? 'N/A',
      description: json['description'],
      timestamp: json['timestamp'],
      userName: json['user_name'],
      medicineName: json['medicine_name'] ?? 'N/A',
    );
  }
}

// --- Main Widget ---
class DailyReportsPage extends StatefulWidget {
  @override
  _DailyReportsPageState createState() => _DailyReportsPageState();
}

class _DailyReportsPageState extends State<DailyReportsPage> {
  DateTime _selectedDate = DateTime.now();
  DailyReport? _dailyReport;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDailyReport(_selectedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDailyReport(_selectedDate);
    }
  }

  Future<void> _fetchDailyReport(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _dailyReport = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final url = 'http://10.0.2.2:8000/api/daily-reports/?date=$formattedDate';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dailyReport = DailyReport.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load data. Status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please check the backend connection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appbarColor = const Color(0xFF5C7C9A);
    final Color lighterColor = Color.lerp(appbarColor, Colors.white, 0.4)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Reports'),
        backgroundColor: appbarColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date display card
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: lighterColor,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Logs for: ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Main Content Area with conditional display
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Text(_errorMessage,
                            style: TextStyle(color: Colors.red)))
                    : _dailyReport == null
                        ? Center(
                            child: Text('No data available for this date.',
                                style: TextStyle(color: Colors.grey)))
                        : Expanded(
                            child: Column(
                              children: [
                                // Employee Logs Section
                                Expanded(
                                  child: _buildLogSection(
                                    'Employee Logs',
                                    _dailyReport!.employeeLogs.map((log) {
                                      return _buildLogCard(
                                        title: log.staffName,
                                        subtitle:
                                            '${log.action}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp))}',
                                      );
                                    }).toList(),
                                    emptyMessage: 'No employee logs for this date.',
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Order Logs Section
                                Expanded(
                                  child: _buildLogSection(
                                    'Order Logs',
                                    _dailyReport!.orderLogs.map((log) {
                                      String title = log.actionType;
                                      String subtitle = log.description ?? '';
                                      if (log.inStoreOrderDetails != null) {
                                        title =
                                            'In-Store Order #${log.inStoreOrderDetails!.id}';
                                        subtitle =
                                            'Amount: \$${log.inStoreOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp))}';
                                      } else if (log.onlineOrderDetails != null) {
                                        title =
                                            'Online Order #${log.onlineOrderDetails!.id}';
                                        subtitle =
                                            'Customer: ${log.onlineOrderDetails!.customerName} | Amount: \$${log.onlineOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp))}';
                                      } else {
                                        subtitle =
                                            '${log.description ?? ''}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp))}';
                                      }
                                      return _buildLogCard(
                                        title: title,
                                        subtitle: subtitle,
                                      );
                                    }).toList(),
                                    emptyMessage: 'No order logs for this date.',
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Inventory Logs Section
                                Expanded(
                                  child: _buildLogSection(
                                    'Inventory Logs',
                                    _dailyReport!.inventoryLogs.map((log) {
                                      String subtitle =
                                          '${log.description ?? ''}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp))}';
                                      return _buildLogCard(
                                        title:
                                            '${log.actionType} - ${log.medicineName ?? 'N/A'}',
                                        subtitle: subtitle,
                                      );
                                    }).toList(),
                                    emptyMessage:
                                        'No inventory logs for this date.',
                                  ),
                                ),
                              ],
                            ),
                          ),

            SizedBox(height: 20),
            
            // "Choose a Date" button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _selectDate(context),
                style: FilledButton.styleFrom(
                  backgroundColor: appbarColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Choose a Date'),
              ),
            ),
            SizedBox(height: 10),

            // Download as PDF button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _dailyReport != null
                    ? () {
                        PdfDailyReportService.generateAndSavePdf(
                          dailyReport: _dailyReport!,
                          selectedDate: _selectedDate,
                        );
                      }
                    : null,
                icon: Icon(Icons.download),
                label: Text('Download as PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: appbarColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // No change to this method
  Widget _buildLogCard({
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
  
  // No change to this method
  Widget _buildLogSection(String title, List<Widget> children, {required String emptyMessage}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              emptyMessage,
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: ListView(
              children: children,
            ),
          ),
      ],
    );
  }
}