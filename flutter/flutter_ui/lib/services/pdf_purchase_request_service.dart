// lib/services/pdf_purchase_request_service.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfPurchaseRequestService {
  /// Generates a PDF from the purchase request list and saves it.
  static Future<void> generateAndSavePdf({
    required List<dynamic> purchaseRequests,
  }) async {
    final pdf = pw.Document();

    // Fetch the manager's name from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final managerName = prefs.getString('name') ?? 'N/A';

    // Get current date and format it
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, y').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'PURCHASE REQUEST',
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
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: [
              'No.',
              'Medicine',
              'Restock Amount',
              'Units per Items',
              'Supplier',
              'Contact No.'
            ],
            data: purchaseRequests.map<List<String>>((item) {
              final restockAmount = item['restock_amount'] ?? 0;
              final unitsPerItems = item['units_per_items'] ?? 1;

              return [
                (item['no'] ?? '').toString(),
                item['medicine_name'] ?? 'N/A',
                restockAmount.toString(),
                unitsPerItems.toString(),
                item['supplier_name'] ?? 'N/A',
                item['contact_num'] ?? 'N/A',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    // Save the PDF using the reliable, shared service
    await PdfService.savePdfToDownloadsAndAppStorage(pdf, 'purchase_request.pdf');
  }
}