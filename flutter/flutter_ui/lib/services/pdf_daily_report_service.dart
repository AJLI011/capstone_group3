// lib/services/pdf_daily_report_service.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_service.dart';
import 'package:flutter_ui/role_views/admin_features/daily_reports/daily_reports.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfDailyReportService {
  /// Generates a PDF for a daily report and saves it.
  static Future<void> generateAndSavePdf({
    required DailyReport dailyReport,
    required DateTime selectedDate,
  }) async {
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
        ],
      ),
    );

    await PdfService.savePdfToDownloadsAndAppStorage(pdf, fileName);
  }

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
        return [
          index.toString(),
          log.staffName,
          log.action,
          DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp)),
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

        String description = log.description ?? 'N/A';
        if (log.inStoreOrderDetails != null) {
          description = 'Order #${log.inStoreOrderDetails!.id} | Total: \$${log.inStoreOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}';
        } else if (log.onlineOrderDetails != null) {
          description = 'Order #${log.onlineOrderDetails!.id} | Customer: ${log.onlineOrderDetails!.customerName} | Total: \$${log.onlineOrderDetails!.totalAmountAfterDiscount.toStringAsFixed(2)}';
        }

        return [
          index.toString(),
          log.actionType,
          description,
          DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp)),
        ];
      }).toList(),
    );
  }

  // 🚨 MODIFIED: Added 'Staff Name' column for Inventory Logs
  static pw.Widget _buildInventoryLogsTable(List<InventoryLog> logs) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(width: 1, color: PdfColors.black),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // No.
        1: const pw.FlexColumnWidth(1.5), // Staff Name
        2: const pw.FlexColumnWidth(1.5), // Action Type
        3: const pw.FlexColumnWidth(1.5), // Medicine Name
        4: const pw.FlexColumnWidth(2.5), // Description
        5: const pw.FlexColumnWidth(1.5), // Timestamp
      },
      headers: ['No.', 'Staff Name', 'Action Type', 'Medicine Name', 'Description', 'Timestamp'], // 🚨 UPDATED HEADERS
      data: logs.asMap().entries.map((entry) {
        int index = entry.key + 1;
        InventoryLog log = entry.value;

        // Combine staff name and role for a single column if role exists
        final String staffInfo = log.staffName != null && log.staffRole != null
             ? '${log.staffName} (${log.staffRole})'
             : log.staffName ?? 'N/A';

        return [
          index.toString(),
          staffInfo, // 🚨 ADDED STAFF INFO
          log.actionType,
          log.medicineName ?? 'N/A',
          log.description ?? 'N/A',
          DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(log.timestamp)),
        ];
      }).toList(),
    );
  }
}