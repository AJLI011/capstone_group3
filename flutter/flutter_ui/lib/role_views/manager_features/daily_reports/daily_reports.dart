// daily_reports.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_ui/services/pdf_daily_report_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// --- Transaction Item Model (Used by InStoreTransaction) ---
class TransactionItem {
  final String medicineName;
  final int quantitySold;
  final int freeQuantityGiven;
  final bool isPromo;
  final double pricePerItem;

  TransactionItem({
    required this.medicineName,
    required this.quantitySold,
    required this.freeQuantityGiven,
    required this.isPromo,
    required this.pricePerItem,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      medicineName: json['medicine_name'] ?? 'N/A',
      quantitySold: json['quantity_sold'] ?? 0,
      freeQuantityGiven: json['free_quantity_given'] ?? 0,
      isPromo: json['is_promo'] ?? false,
      pricePerItem: double.tryParse(json['price_per_item'].toString()) ?? 0.0,
    );
  }
}

// --- InStoreTransaction Model ---
class InStoreTransaction {
  final int id;
  // UPDATED: Changed from DateTime dateCreated to String dateCreatedTimestamp 
  final String dateCreatedTimestamp; 
  final String staffName;
  final String? cashierName;
  final String status;
  final double subtotal;
  final double totalAmount;
  final List<TransactionItem> items;
  final double discountAmount;
  final bool isPwd;

  InStoreTransaction({
    required this.id,
    // UPDATED: Parameter name changed
    required this.dateCreatedTimestamp, 
    required this.staffName,
    this.cashierName,
    required this.status,
    required this.subtotal,
    required this.totalAmount,
    required this.items,
    required this.discountAmount,
    required this.isPwd,
  });

  factory InStoreTransaction.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List?;
    List<TransactionItem> parsedItems = (itemsList ?? [])
        .map((itemJson) => TransactionItem.fromJson(itemJson))
        .toList();

    final int id = int.tryParse(json['id'].toString()) ?? 0;

    return InStoreTransaction(
      id: id,
      // UPDATED: Storing the raw timestamp string
      dateCreatedTimestamp: json['date_created'], 
      staffName: json['staff'] as String? ?? 'N/A',
      cashierName: json['cashier'] as String?,
      status: json['status'] ?? 'N/A',
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0.0,
      // Uses the final amount for the display
      totalAmount: double.tryParse(json['total_amount_after_discount'].toString()) ?? 0.0,
      items: parsedItems,
      discountAmount: double.tryParse(json['discount_amount'].toString()) ?? 0.0,
      isPwd: json['is_pwd'] ?? false,
    );
  }
}

// --- OnlineTransaction Model ---
class OnlineTransaction {
  final int orderId;
  final String customerType;
  final String initiatedByName;
  final String approvedByName;
  final double totalAmount;
  final double subtotalAmount;
  final double discountAmount;
  final String fulfilledTimestamp;
  final List<dynamic> items;

  OnlineTransaction({
    required this.orderId,
    required this.customerType,
    required this.initiatedByName,
    required this.approvedByName,
    required this.totalAmount,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.fulfilledTimestamp,
    required this.items,
  });

  factory OnlineTransaction.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List?;

    return OnlineTransaction(
      orderId: json['id'] as int? ?? 0,
      customerType: json['customer_type'] ?? 'N/A',
      initiatedByName: json['initiated_by_name'] ?? 'N/A',
      approvedByName: json['approved_by_name'] ?? 'N/A',
      // Uses the final amount for the display
      totalAmount: double.tryParse(json['total_amount_after_discount'].toString()) ?? 0.0,
      subtotalAmount: double.tryParse(json['total_amount_before_discount'].toString()) ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount'].toString()) ?? 0.0,
      fulfilledTimestamp: json['fulfilled_timestamp'] ?? 'N/A', // This key is exposed correctly by the serializer
      items: itemsList ?? [], // Default to empty list if null
    );
  }
}

// --- NEW UNIFIED SALES ROW MODEL ---
class SalesTransactionRow {
  final String orderNo;
  final String initiatedBy;
  final String approvedBy;
  final String medicineName;
  final int quantity;
  final double totalAmount; // Overall Transaction Total
  final String timestamp;
  final String transactionType;

  SalesTransactionRow({
    required this.orderNo,
    required this.initiatedBy,
    required this.approvedBy,
    required this.medicineName,
    required this.quantity,
    required this.totalAmount,
    required this.timestamp,
    required this.transactionType,
  });
}
// -----------------------------------------------------------------
// ⬇️ Existing Log Models (Included for completeness)
// -----------------------------------------------------------------
class EmployeeLog {
  final int id;
  final String staffName;
  final String? staffRole;
  final String action;
  final String timestamp;

  EmployeeLog({
    required this.id,
    required this.staffName,
    this.staffRole,
    required this.action,
    required this.timestamp,
  });

  factory EmployeeLog.fromJson(Map<String, dynamic> json) {
    return EmployeeLog(
      id: json['id'],
      staffName: json['staff_name'] ?? 'N/A',
      staffRole: json['staff_role'] as String?,
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
  final String? staffName;
  final String? staffRole;

  InventoryLog({
    required this.id,
    required this.actionType,
    this.description,
    required this.timestamp,
    this.userName,
    this.medicineName,
    this.staffName,
    this.staffRole,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    return InventoryLog(
      id: json['id'],
      actionType: json['action_type'] ?? 'N/A',
      description: json['description'],
      timestamp: json['timestamp'],
      userName: json['user_name'],
      medicineName: json['medicine_name'] ?? 'N/A',
      staffName: json['staff_name'],
      staffRole: json['staff_role'],
    );
  }
}
// -----------------------------------------------------------------


// --- DailyReport Model (Consolidated) ---
class DailyReport {
  final List<EmployeeLog> employeeLogs;
  final List<OrderLog> orderLogs;
  final List<InventoryLog> inventoryLogs;
  final List<InStoreTransaction> inStoreTransactions;
  final List<OnlineTransaction> onlineTransactions;

  DailyReport({
    required this.employeeLogs,
    required this.orderLogs,
    required this.inventoryLogs,
    required this.inStoreTransactions,
    required this.onlineTransactions,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {

    return DailyReport(
      employeeLogs: (json['employee_logs'] as List<dynamic>?)
          ?.map((e) => EmployeeLog.fromJson(e))
          .toList() ?? [],

      orderLogs: (json['order_logs'] as List<dynamic>?)
          ?.map((e) => OrderLog.fromJson(e))
          .toList() ?? [],

      inventoryLogs: (json['inventory_logs'] as List<dynamic>?)
          ?.map((e) => InventoryLog.fromJson(e))
          .toList() ?? [],

      inStoreTransactions: (json['in_store_transactions'] as List<dynamic>?)
          ?.map((e) => InStoreTransaction.fromJson(e))
          .toList() ?? [],

      onlineTransactions: (json['online_transactions'] as List<dynamic>?)
          ?.map((e) => OnlineTransaction.fromJson(e))
          .toList() ?? [],
    );
  }
}

// --- Main Widget ---
class DailyReportsPage extends StatefulWidget {
  const DailyReportsPage({super.key});

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
    tz.initializeTimeZones();
    _fetchDailyReport(_selectedDate);
  }

  tz.TZDateTime _convertToManilaTime(String timestamp) {
    final DateTime utcTimestamp = DateTime.parse(timestamp).toUtc();
    final location = tz.getLocation('Asia/Manila');
    return tz.TZDateTime.from(utcTimestamp, location);
  }

  // --- NEW HELPER FUNCTION TO UNIFY TRANSACTION DATA ---
  List<SalesTransactionRow> _createTransactionRows(DailyReport report) {
    final List<SalesTransactionRow> rows = [];
    final manilaTz = tz.getLocation('Asia/Manila');
    final formatter = DateFormat('MMM d, yyyy h:mm a');

    final reversedInStoreTransactions = report.inStoreTransactions.reversed.toList();

    // A. Process In-Store Transactions
    for (final tx in reversedInStoreTransactions) {
      // UPDATED: Use dateCreatedTimestamp for formatting
      final manilaTimestamp = _convertToManilaTime(tx.dateCreatedTimestamp); 
      final formattedTimestamp = formatter.format(manilaTimestamp);

      if (tx.items.isEmpty) continue;

      for (final item in tx.items) {
        // Quantity is the sum of paid and free items
        final totalQuantity = item.quantitySold + item.freeQuantityGiven;

        rows.add(
          SalesTransactionRow(
            orderNo: 'IN-${tx.id}',
            initiatedBy: tx.staffName,
            approvedBy: tx.cashierName ?? 'N/A',
            medicineName: item.medicineName,
            quantity: totalQuantity,
            totalAmount: tx.totalAmount, // Overall transaction total
            timestamp: formattedTimestamp,
            transactionType: 'In-Store',
          ),
        );
      }
    }

    final reversedOnlineTransactions = report.onlineTransactions.reversed.toList();

    // B. Process Online Transactions
    for (final tx in reversedOnlineTransactions) {
      String formattedTimestamp = 'N/A';
      if (tx.fulfilledTimestamp != 'N/A') {
          try {
              final DateTime utcTimestamp = DateTime.parse(tx.fulfilledTimestamp).toUtc();
              final tz.TZDateTime manilaTimestamp = tz.TZDateTime.from(utcTimestamp, manilaTz);
              formattedTimestamp = formatter.format(manilaTimestamp);
          } catch (_) {}
      }

      if (tx.items.isEmpty) continue;

      for (final itemDynamic in tx.items) {
        final item = itemDynamic as Map<String, dynamic>;

        // 🟢 FIX 1: Robust Medicine Name Extraction
        // Accesses item['medicine'], then the nested map's ['name'] key.
        final Map<String, dynamic>? medicineDetails = item['medicine'] as Map<String, dynamic>?;

        // Use the 'name' from the nested map, or 'N/A'
        final String medicineName = medicineDetails?['name'] ?? 'N/A';

        // 🟢 FIX 2: Quantity field is 'quantity_sold' in the serializer.
        final int quantity = int.tryParse(item['quantity_sold'].toString()) ?? 0;

        rows.add(
          SalesTransactionRow(
            // Order No. should be displaying correctly as 'ON-${tx.orderId}'
            orderNo: 'ON-${tx.orderId}', // Should be concatenating 'ON-'
            initiatedBy: tx.initiatedByName,
            approvedBy: tx.approvedByName,
            medicineName: medicineName, // Should now be correct
            quantity: quantity,// Should now be correct
            totalAmount: tx.totalAmount,
            timestamp: formattedTimestamp,
            transactionType: 'Online',
          ),
        );
      }
    }

    return rows;
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
    // NOTE: This URL is based on the terminal output and previous assumptions
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

  // ------------------------------------------------------------------
  // ⬇️ MODIFIED/NEW LOG TAB WIDGETS
  // ------------------------------------------------------------------

  // NEW: Helper method for the main "Logs" section with nested tabs
  Widget _buildLogsView(DailyReport report, Color appbarColor) {
    return DefaultTabController( // Nested Tab Controller for Logs
      length: 3, // Employee, Order, Inventory
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          // Tab Bar for Logs: Employee, Order, Inventory
          TabBar(
            indicatorColor: appbarColor,
            labelColor: appbarColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Employee'), // Employee Log Tab
              Tab(text: 'Order'), // Order Log Tab
              Tab(text: 'Inventory'), // Inventory Log Tab
            ],
          ),
          SizedBox(height: 10),
          // TabBarView contains the separate log lists
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Employee Logs Content
                _buildEmployeeLogsTab(report),
                
                // Tab 2: Order Logs Content
                _buildOrderLogsTab(report),
                
                // Tab 3: Inventory Logs Content
                _buildInventoryLogsTab(report),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // NEW: Helper method for the "Employee Logs" tab content
  Widget _buildEmployeeLogsTab(DailyReport report) {
    return _buildLogSection(
      'Employee Logs (Login/Logout)',
      report.employeeLogs.map((log) {
        final manilaTimestamp = _convertToManilaTime(log.timestamp);
        final String staffInfo = log.staffRole != null
            ? '${log.staffName} (${log.staffRole})'
            : log.staffName;

        return _buildLogCard(
          title: log.action.toUpperCase(),
          subtitle:
              'Staff: $staffInfo\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp)}',
        );
      }).toList(),
      emptyMessage: 'No employee logs for this date.',
    );
  }

  // NEW: Helper method for the "Order Logs" tab content
  Widget _buildOrderLogsTab(DailyReport report) {
    return _buildLogSection(
      'Order Logs',
      report.orderLogs.map((log) {
        final manilaTimestamp = _convertToManilaTime(log.timestamp);
        String title = log.actionType;
        String subtitle = log.description ?? '';

        if (log.inStoreOrderDetails != null) {
          title = 'In-Store Order #${log.inStoreOrderDetails!.id}';
          subtitle = 'Amount: ₱${log.inStoreOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp)}';
        } else if (log.onlineOrderDetails != null) {
          title = 'Online Order #${log.onlineOrderDetails!.id}';
          subtitle = 'Customer: ${log.onlineOrderDetails!.customerName} | Amount: ₱${log.onlineOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp)}';
        } else {
          subtitle = '${log.description ?? ''}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp)}';
        }
        return _buildLogCard(
          title: title,
          subtitle: subtitle,
        );
      }).toList(),
      emptyMessage: 'No order logs for this date.',
    );
  }

  // NEW: Helper method for the "Inventory Logs" tab content
  Widget _buildInventoryLogsTab(DailyReport report) {
    return _buildLogSection(
      'Inventory Logs',
      report.inventoryLogs.map((log) {
        final manilaTimestamp = _convertToManilaTime(log.timestamp);
        final String staffInfo = log.staffName != null && log.staffRole != null
            ? '${log.staffName} (${log.staffRole})'
            : log.staffName ?? 'N/A Staff';

        // UPDATED SUBTITLE: Made fields explicit and removed repetition of actionType (now in title)
        String subtitle = 'Staff: $staffInfo\nDescription: ${log.description ?? ''}\nTimestamp: ${DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp)}';

        return _buildLogCard(
          // MODIFIED: Simplified title to just the action type, removing the redundant line
          title: log.actionType.toUpperCase(),
          subtitle: subtitle,
        );
      }).toList(),
      emptyMessage: 'No inventory logs for this date.',
    );
  }

  // MODIFIED: Helper method to build the content for the "Sales Transactions" tab
  Widget _buildSalesView(List<SalesTransactionRow> inStoreSalesRows, List<SalesTransactionRow> onlineSalesRows, Color appbarColor) {
    return DefaultTabController( // Nested Tab Controller for Sales Types
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // REMOVED redundant title, added space for layout consistency
          SizedBox(height: 10),
          // Tab Bar for separation of Online and In-Store
          TabBar(
            indicatorColor: appbarColor,
            labelColor: appbarColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Online'), // Online first as requested
              Tab(text: 'Instore'), // Instore second as requested
            ],
          ),
          SizedBox(height: 10),
          // TabBarView contains the separate lists (content order updated to match tabs)
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Online Sales Content
                _buildTransactionList(
                  onlineSalesRows,
                  emptyMessage: 'No Online sales transactions for this date.',
                ),
                // Tab 2: In-Store Sales Content
                _buildTransactionList(
                  inStoreSalesRows,
                  emptyMessage: 'No In-Store sales transactions for this date.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appbarColor = const Color(0xFF5C7C9A);

    // Call the data transformation function once
    final List<SalesTransactionRow> allSalesRows = _dailyReport == null
        ? []
        : _createTransactionRows(_dailyReport!);

    // 1. SEPARATE SALES DATA (Used by _buildSalesView)
    final List<SalesTransactionRow> inStoreSalesRows = allSalesRows
        .where((row) => row.transactionType == 'In-Store')
        .toList();

    final List<SalesTransactionRow> onlineSalesRows = allSalesRows
        .where((row) => row.transactionType == 'Online')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Reports'),
        backgroundColor: appbarColor,
        foregroundColor: Colors.white,
      ),
      // UPDATED: Top-level Tab Controller now has 2 tabs: Logs and Sales Transactions
      body: DefaultTabController(
        length: 2, // CHANGED from 4 to 2
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Date display card
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: appbarColor,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Text(
                    'Daily Report for: ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
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

              // UPDATED: Main TabBar for the 2 sections
              TabBar(
                indicatorColor: appbarColor,
                labelColor: appbarColor,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Logs'), // Top-level Logs tab
                  Tab(text: 'Sales Transactions'), // Top-level Sales Transactions tab
                ],
              ),
              SizedBox(height: 10),

              // Main Content Area (TabBarView) with conditional display
              _isLoading
                  ? Expanded(child: Center(child: CircularProgressIndicator()))
                  : _errorMessage.isNotEmpty
                      ? Expanded(child: Center(
                          child: Text(_errorMessage,
                              style: TextStyle(color: Colors.red))))
                      : _dailyReport == null
                          ? Expanded(child: Center(
                              child: Text('No data available for this date.',
                                  style: TextStyle(color: Colors.grey))))
                          : Expanded(
                              child: TabBarView(
                                children: [
                                  // Tab 1: Logs (Nested Tabs: Employee, Order, Inventory)
                                  _buildLogsView(_dailyReport!, appbarColor),

                                  // Tab 2: Sales Transactions (Nested Tabs: Online, Instore)
                                  _buildSalesView(inStoreSalesRows, onlineSalesRows, appbarColor),
                                ],
                              ),
                            ),

              SizedBox(height: 20),

              // Footer buttons (Choose Date, Download PDF)
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
      ),
    );
  }

  Widget _buildLogCard({
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildLogSection(String title, List<Widget> children, {required String emptyMessage}) {
    // Note: Removed the fixed height SizedBox and added an Expanded to ListView
    // to allow the content to fill the TabBarView space.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
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
              padding: EdgeInsets.zero,
              children: children,
            ),
          ),
      ],
    );
  }

  // 2. RENAMED AND MODIFIED WIDGET FOR SEPARATE SALES LISTS (NO TITLE NEEDED)
  Widget _buildTransactionList(List<SalesTransactionRow> rows, {required String emptyMessage}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Center(
              child: Text(
                emptyMessage,
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];

                // Details reflecting the required table headers
                String details = 'Item: ${row.medicineName} (x${row.quantity})\n';
                details += 'Order Total: ₱${row.totalAmount.toStringAsFixed(2)}\n';
                details += 'Initiated by: ${row.initiatedBy} | Approved by: ${row.approvedBy}\n';
                details += 'Timestamp: ${row.timestamp}';

                // Title combines order number and transaction type
                String titleText = '${row.transactionType.toUpperCase()} ORDER ${row.orderNo}';

                return _buildLogCard(
                  title: titleText,
                  subtitle: details,
                );
              },
            ),
          ),
      ],
    );
  }
}