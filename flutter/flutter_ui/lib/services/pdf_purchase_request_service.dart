// lib/services/pdf_purchase_request_service.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfPurchaseRequestService {
    /// Generates a PDF from the purchase request and low stock lists and saves it.
    static Future<void> generateAndSavePdf({
        required List<dynamic> purchaseRequests,
        required List<dynamic> lowStockItems,
    }) async {
        final pdf = pw.Document();

        // Fetch the manager's name from shared preferences
        final prefs = await SharedPreferences.getInstance();
        final managerName = prefs.getString('name') ?? 'N/A';

        // Get current date and format it
        final now = DateTime.now();
        final formattedDate = DateFormat('MMMM d, y').format(now);

        // ==================== PAGE 1: PURCHASE REQUEST ====================
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
                        child: pw.Text('BlueWhite Generic Pharmacy', style: const pw.TextStyle(fontSize: 16)),
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
                        // Updated: Reduced header font size and added column widths
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        columnWidths: {
                            0: pw.FixedColumnWidth(0.5),    // 'No.'
                            1: pw.FlexColumnWidth(2.0),     // 'Medicine'
                            2: pw.FlexColumnWidth(1.5),     // 'Restock Amount'
                            3: pw.FlexColumnWidth(1.5),     // 'Units per Items'
                            4: pw.FlexColumnWidth(1.5),     // 'Supplier'
                            5: pw.FlexColumnWidth(1.8),     // 'Contact No.'
                        },
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
                            final supplierName = item['supplier_name'] ?? 'N/A';
                            final contactNum = item['contact_num'] ?? 'N/A';

                            return [
                                (item['no'] ?? '').toString(),
                                item['medicine_name'] ?? 'N/A',
                                restockAmount.toString(),
                                unitsPerItems.toString(),
                                supplierName,
                                contactNum,
                            ];
                        }).toList(),
                    ),
                ],
            ),
        );

        // ==================== PAGE 2: LOW STOCK REPORT ====================
        pdf.addPage(
            pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                build: (context) => [
                    pw.Center(
                        child: pw.Text(
                            'LOW STOCK REPORT',
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
                            pw.Text('Manager: $managerName', style: const pw.TextStyle(fontSize: 12)),
                        ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Table.fromTextArray(
                        border: pw.TableBorder.all(width: 1),
                        // Updated: Reduced header font size and added column widths
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        columnWidths: {
                            0: pw.FixedColumnWidth(0.5),    // 'No.'
                            1: pw.FlexColumnWidth(2.0),     // 'Medicine'
                            2: pw.FlexColumnWidth(1.5),     // 'Stock Quantity' (Actual low quantity)
                            3: pw.FlexColumnWidth(1.5),     // 'Restock Amount' (Order quantity)
                            4: pw.FlexColumnWidth(1.5),     // 'Supplier'
                            5: pw.FlexColumnWidth(1.8),     // 'Contact No.'
                        },
                        headers: [
                            'No.',
                            'Medicine',
                            'Stock Quantity', // Updated header
                            'Restock Amount', // Corrected header placement
                            'Supplier',
                            'Contact No.'
                        ],
                        data: lowStockItems.asMap().entries.map<List<String>>((entry) {
                            final item = entry.value;

                            // Data keys are set in purchase_request_page.dart's _generateAndSavePdf method
                            final medicineName = item['medicine_name'] ?? 'N/A'; 
                            // This is the actual quantity currently in stock
                            final totalQuantity = item['total_quantity'] ?? 0; 
                            // This is the calculated restock order quantity
                            final restockAmount = item['restock_amount'] ?? 0;
                            final supplierName = item['supplier_name'] ?? 'N/A';
                            final contactNum = item['contact_num'] ?? 'N/A';

                            // Data mapping updated to correctly use total_quantity and restock_amount
                            return [
                                (item['no'] ?? '').toString(),
                                medicineName,
                                totalQuantity.toString(), // The actual quantity in stock
                                restockAmount.toString(), // The calculated restock quantity
                                supplierName,
                                contactNum,
                            ];
                        }).toList(),
                    ),
                ],
            ),
        );

        // Save the PDF using the reliable, shared service
        await PdfService.savePdfToDownloadsAndAppStorage(pdf, 'purchase_request_and_low_stock.pdf');
    }
}