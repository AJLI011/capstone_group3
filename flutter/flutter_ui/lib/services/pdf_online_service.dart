// lib/services/pdf_online_service.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfOnlineService {
  /// Generates a PDF from the online sales JSON and saves it using PdfService.
  static Future<void> generateAndSavePdf({
    required Map<String, dynamic> salesJson,
  }) async {
    final pdf = pw.Document();

    // Fetch the manager's name from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final managerName = prefs.getString('name') ?? 'N/A';

    // Get current date and format it
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, y').format(now);

    // Extract data from the sales JSON
    final totalRevenue = salesJson['total_revenue'] ?? 0.0;
    final reportingPeriod = salesJson['reporting_period'] ?? {};
    final salesReport = salesJson['sales_report'] ?? [];
    final reportingPeriodText =
        '${reportingPeriod['start_date']} - ${reportingPeriod['end_date']}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'ONLINE SALES SUMMARY',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text('Generic Pharmacy', style: const pw.TextStyle(fontSize: 16)),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Manager: $managerName', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Reporting Period: $reportingPeriodText',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Total Revenue: P${totalRevenue.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Medicine', 'Quantity Sold', 'Total Sale'],
            data: salesReport.map<List<String>>((item) {
              final totalSaleFormatted =
                  NumberFormat.currency(symbol: '', decimalDigits: 2).format(item['total_sale'] ?? 0.0);
              return [
                item['medicine'].toString(),
                (item['quantity_sold'] ?? 0).toString(),
                'P$totalSaleFormatted',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    // Save the PDF using the reliable, shared service
    await PdfService.savePdfToDownloadsAndAppStorage(pdf, 'online_sales_report.pdf');
  }
}