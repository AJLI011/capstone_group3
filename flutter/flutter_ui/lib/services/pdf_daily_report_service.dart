// lib/services/pdf_daily_report_service.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_service.dart';
// Ensure this path is correct and contains the models (DailyReport, InStoreTransaction, etc.)
import 'package:flutter_ui/role_views/admin_features/daily_reports/daily_reports.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PdfDailyReportService {

    static final tz.Location _manila = tz.getLocation('Asia/Manila');

    static tz.TZDateTime _convertToManilaTime(String timestamp) {
        // Assume the backend provides UTC or an unzoned time string
        final DateTime utcTimestamp = DateTime.parse(timestamp).toUtc();
        return tz.TZDateTime.from(utcTimestamp, _manila);
    }

    /// Generates a PDF for a daily report and saves it.
    static Future<void> generateAndSavePdf({
        required DailyReport dailyReport,
        required DateTime selectedDate,
    }) async {
        tz.initializeTimeZones();

        final pdf = pw.Document();

        // Fetch the manager's name from shared preferences
        final prefs = await SharedPreferences.getInstance();
        final managerName = prefs.getString('name') ?? 'N/A';

        final formattedDate = DateFormat('MMMM d, yyyy').format(selectedDate);
        final fileName = 'daily_report_${DateFormat('yyyy-MM-dd').format(selectedDate)}.pdf';

        // A single MultiPage widget to handle all content and page breaks
        pdf.addPage(
            pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                header: (context) {
                    return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                            pw.Center(
                                child: pw.Text(
                                    'DAILY REPORT',
                                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                                ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Center(
                                child: pw.Text('BlueWhite Generic Pharmacy', style: const pw.TextStyle(fontSize: 16)),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                    pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 12)),
                                ],
                            ),
                            pw.SizedBox(height: 20),
                        ],
                    );
                },
                build: (context) => [
                    // ==================== EMPLOYEE LOGS TABLE ====================
                    if (dailyReport.employeeLogs.isNotEmpty) ...[
                        pw.Text(
                            'Employee Logs',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        _buildEmployeeLogsTable(dailyReport.employeeLogs),
                        pw.SizedBox(height: 20),
                    ],

                    // ==================== ORDER LOGS TABLE ====================
                    if (dailyReport.orderLogs.isNotEmpty) ...[
                        pw.Text(
                            'Order Logs',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        _buildOrderLogsTable(dailyReport.orderLogs),
                        pw.SizedBox(height: 20),
                    ],

                    // ==================== INVENTORY LOGS TABLE ====================
                    if (dailyReport.inventoryLogs.isNotEmpty) ...[
                        pw.Text(
                            'Inventory Logs',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        _buildInventoryLogsTable(dailyReport.inventoryLogs),
                        pw.SizedBox(height: 20),
                    ],

                    // ⬇️ 🆕 ==================== IN-STORE TRANSACTIONS TABLE ====================
                    if (dailyReport.inStoreTransactions.isNotEmpty) ...[
                        pw.Divider(),
                        pw.SizedBox(height: 15),
                        pw.Text(
                            'In-Store Sales Transactions',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        _buildInStoreTransactionTable(dailyReport.inStoreTransactions),
                        pw.SizedBox(height: 20),
                    ],

                    // ⬇️ 🆕 ==================== ONLINE TRANSACTIONS TABLE ====================
                    if (dailyReport.onlineTransactions.isNotEmpty) ...[
                        pw.Divider(),
                        pw.SizedBox(height: 15),
                        pw.Text(
                            'Online Sales Transactions',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        _buildOnlineTransactionTable(dailyReport.onlineTransactions),
                        pw.SizedBox(height: 20),
                    ],
                ],
            ),
        );

        await PdfService.savePdfToDownloadsAndAppStorage(pdf, fileName);
    }

    // ----------------------------------------------------------------------
    // ⬇️ NEW HELPER FUNCTIONS FOR TRANSACTION TABLES
    // ----------------------------------------------------------------------

    static pw.Widget _buildInStoreTransactionTable(List<InStoreTransaction> transactions) {
        final headers = [
            'No.',
            'Order No.',
            'Initiated by',
            'Approved by',
            'Medicine',
            'Quantity',
            'Total Amount',
            // 🟢 ADDED: Timestamp
            'Timestamp'
        ];

        final List<List<String>> data = [];
        int globalRowIndex = 1;

        // 🟢 MODIFICATION: Reverse the list to display latest transactions first
        final reversedTransactions = transactions.reversed.toList();

        for (var tx in reversedTransactions) {
            // 🟢 ADDED: Format the timestamp for the transaction once
            final manilaTimestamp = _convertToManilaTime(tx.dateCreatedTimestamp);
            final formattedTimestamp = DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp);

            // Loop through each item in the transaction
            for (int i = 0; i < tx.items.length; i++) {
                final item = tx.items[i];
                final isFirstItem = i == 0;

                // Quantity includes sold and free given
                final qtySold = item.quantitySold + item.freeQuantityGiven;

                data.add([
                    globalRowIndex.toString(),
                    // Show Order No., Initiated by, Approved by, and Total Amount only on the first item line (i==0)
                    isFirstItem ? '${tx.id}' : '', // Added 'IN-' prefix
                    isFirstItem ? tx.staffName : '',
                    isFirstItem ? (tx.cashierName ?? 'N/A') : '',
                    '${item.medicineName} ${item.isPromo ? '(Promo)' : ''}',
                    '$qtySold',
                    isFirstItem ? tx.totalAmount.toStringAsFixed(2) : '',
                    // 🟢 ADDED: Timestamp (only on first row)
                    isFirstItem ? formattedTimestamp : '',
                ]);
                globalRowIndex++;
            }
        }

        return pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: const {
                0: pw.FixedColumnWidth(25), // No.
                1: pw.FixedColumnWidth(50), // Order No.
                2: pw.FlexColumnWidth(1.0), // Initiated by
                3: pw.FlexColumnWidth(1.0), // Approved by
                4: pw.FlexColumnWidth(1.5), // Medicine
                5: pw.FixedColumnWidth(40), // Quantity
                6: pw.FixedColumnWidth(65), // Total Amount
                // 🟢 ADDED: Timestamp Column Width
                7: pw.FixedColumnWidth(80), // Timestamp
            },
        );
    }

    static pw.Widget _buildOnlineTransactionTable(List<OnlineTransaction> transactions) {
        final headers = [
            'No.',
            'Order No.',
            'Initiated by',
            'Approved by',
            'Medicine',
            'Quantity',
            'Total Amount',
            // 🟢 ADDED: Timestamp
            'Timestamp'
        ];

        final List<List<String>> data = [];
        int globalRowIndex = 1;

        // 🟢 MODIFICATION: Reverse the list to display latest transactions first
        final reversedTransactions = transactions.reversed.toList();

        for (var tx in reversedTransactions) {
            // 🟢 ADDED: Format the timestamp for the transaction once
            String formattedTimestamp = '';
            if (tx.fulfilledTimestamp != 'N/A') {
                try {
                    final manilaTimestamp = _convertToManilaTime(tx.fulfilledTimestamp);
                    formattedTimestamp = DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp);
                } catch (_) { /* Do nothing if parsing fails */ }
            }

            // Loop through each item in the transaction (items list)
            for (int i = 0; i < tx.items.length; i++) {
                final item = tx.items[i] as Map<String, dynamic>; // Cast to Map
                final isFirstItem = i == 0;

                // 🟢 FIX 1: Extract nested medicine name (as per API structure)
                final Map<String, dynamic>? medicineDetails = item['medicine'] as Map<String, dynamic>?;
                final String medicineName = medicineDetails?['name'] ?? 'N/A';

                // 🟢 FIX 2: Use the correct quantity key ('quantity_sold')
                final String quantitySold = item['quantity_sold']?.toString() ?? 'N/A';

                data.add([
                    globalRowIndex.toString(),
                    // 🟢 FIX 3: Add 'ON-' prefix to Order ID
                    isFirstItem ? '${tx.orderId}' : '', // Added 'ON-' prefix
                    isFirstItem ? '${tx.initiatedByName}' : '',
                    isFirstItem ? '${tx.approvedByName}' : '',

                    medicineName, // Uses fixed variable
                    quantitySold, // Uses fixed variable

                    isFirstItem ? tx.totalAmount.toStringAsFixed(2) : '',
                    // 🟢 ADDED: Timestamp (only on first row)
                    isFirstItem ? formattedTimestamp : '',
                ]);
                globalRowIndex++;
            }
        }

        return pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: const {
                0: pw.FixedColumnWidth(25), // No.
                1: pw.FixedColumnWidth(50), // Order No.
                2: pw.FlexColumnWidth(1.0), // Initiated by
                3: pw.FlexColumnWidth(1.0), // Approved by
                4: pw.FlexColumnWidth(1.5), // Medicine
                5: pw.FixedColumnWidth(40), // Quantity
                6: pw.FixedColumnWidth(65), // Total Amount
                // 🟢 ADDED: Timestamp Column Width
                7: pw.FixedColumnWidth(80), // Timestamp
            },
        );
    }

    // ----------------------------------------------------------------------
    // ⬇️ EXISTING HELPER FUNCTIONS (Included for completeness)
    // ----------------------------------------------------------------------

    static pw.Widget _buildEmployeeLogsTable(List<EmployeeLog> logs) {
        return pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // No.
                1: const pw.FlexColumnWidth(1.5), // Staff Name
                2: const pw.FlexColumnWidth(2.5), // Action
                3: const pw.FlexColumnWidth(1.5), // Timestamp
            },
            headers: ['No.', 'Staff Name', 'Action', 'Timestamp'],
            data: logs.asMap().entries.map((entry) {
                int index = entry.key + 1;
                EmployeeLog log = entry.value;

                final manilaTimestamp = _convertToManilaTime(log.timestamp);

                return [
                    index.toString(),
                    log.staffName,
                    log.action,
                    DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp),
                ];
            }).toList(),
        );
    }

    static pw.Widget _buildOrderLogsTable(List<OrderLog> logs) {
        return pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // No.
                1: const pw.FlexColumnWidth(1.5), // Action Type
                2: const pw.FlexColumnWidth(3.0), // Description
                3: const pw.FlexColumnWidth(1.5), // Timestamp
            },
            headers: ['No.', 'Action Type', 'Description', 'Timestamp'],
            data: logs.asMap().entries.map((entry) {
                int index = entry.key + 1;
                OrderLog log = entry.value;

                final manilaTimestamp = _convertToManilaTime(log.timestamp);

                String description = log.description ?? 'N/A';
                if (log.inStoreOrderDetails != null) {
                    description = 'Order #${log.inStoreOrderDetails!.id} | Total: ₱${log.inStoreOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}';
                } else if (log.onlineOrderDetails != null) {
                    description = 'Order #${log.onlineOrderDetails!.id} | Customer: ${log.onlineOrderDetails!.customerName} | Total: ₱${log.onlineOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}';
                }

                return [
                    index.toString(),
                    log.actionType,
                    description,
                    DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp),
                ];
            }).toList(),
        );
    }

    /// FIX: Replaces 'Medicine Name' column with 'Staff Logged (Role)' in the PDF.
    static pw.Widget _buildInventoryLogsTable(List<InventoryLog> logs) {
        return pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // No.
                1: const pw.FlexColumnWidth(1.5), // Action Type
                2: const pw.FlexColumnWidth(1.5), // Staff Logged (replaces Medicine Name)
                3: const pw.FlexColumnWidth(2.5), // Description
                4: const pw.FlexColumnWidth(1.5), // Timestamp
            },
            headers: ['No.', 'Action Type', 'Staff', 'Description', 'Timestamp'],
            data: logs.asMap().entries.map((entry) {
                int index = entry.key + 1;
                InventoryLog log = entry.value;

                final manilaTimestamp = _convertToManilaTime(log.timestamp);

                // Combine staff name and role
                final String staffInfo = log.staffName != null && log.staffRole != null
                                ? '${log.staffName} (${log.staffRole})'
                                : log.staffName ?? 'N/A Staff';

                return [
                    index.toString(),
                    log.actionType,
                    staffInfo,
                    log.description ?? 'N/A',
                    DateFormat('MMM d, yyyy h:mm a').format(manilaTimestamp),
                ];
            }).toList(),
        );
    }
}