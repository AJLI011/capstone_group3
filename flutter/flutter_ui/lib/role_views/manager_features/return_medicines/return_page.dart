import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ui/services/pdf_service.dart'; // Import your existing PdfService

class ReturnMedicinePage extends StatefulWidget {
  const ReturnMedicinePage({super.key});

  @override
  State<ReturnMedicinePage> createState() => _ReturnMedicinePageState();
}

class _ReturnMedicinePageState extends State<ReturnMedicinePage> {
  List<dynamic> expiredMedicines = [];

  @override
  void initState() {
    super.initState();
    fetchExpiredMedicines();
  }

  void fetchExpiredMedicines() async {
    final response = await http.get(Uri.parse('http://192.168.0.104:8000/api/medicines/expired/'));
    if (response.statusCode == 200) {
      setState(() {
        expiredMedicines = jsonDecode(response.body);
      });
      // Print to debug the data structure
      print(jsonEncode(expiredMedicines));
    } else {
      print('Failed to fetch expired medicines: ${response.statusCode}');
    }
  }

  Future<void> markAsReturned(int inventoryId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Return'),
        content: const Text('Mark as returned?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // ✅ Get staff_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getInt('staff_id');

      if (staffId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff ID not found. Please log in again.')),
        );
        return;
      }

      // ✅ Include staff_id as query param in the DELETE request
      final String deleteUrl =
          'http://192.168.0.104:8000/api/medicines/delete/$inventoryId/?staff_id=$staffId';

      final response = await http.delete(Uri.parse(deleteUrl));
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          expiredMedicines.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine marked as returned.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to return the medicine.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred.')),
      );
    }
  }

  Future<void> generateAndSavePdf(List<Map<String, dynamic>> medicines) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'RETURN EXPIRED MEDICINES',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('BlueWhite Generic Pharmacy', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('DATE: $now', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(width: 1),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                // FIXED: Adjust column widths to prevent 'Medicine' from cutting off
                columnWidths: {
                  0: pw.FixedColumnWidth(0.5), // 'No.'
                  1: pw.FlexColumnWidth(1.5),  // 'Medicine'
                  2: pw.FlexColumnWidth(1.5),  // 'Batch No.'
                  3: pw.FlexColumnWidth(1.8),  // 'Expiration Date'
                  4: pw.FlexColumnWidth(1.0),  // 'Expired Quantity'
                  5: pw.FlexColumnWidth(1.5),  // 'Supplier'
                },
                headers: [
                  'No.',
                  'Medicine',
                  'Batch No.',
                  'Expiration Date',
                  'Expired Quantity',
                  'Supplier',
                ],
                data: List<List<String>>.generate(
                  medicines.length,
                  (index) => [
                    '${index + 1}',
                    medicines[index]['medicine_name'] ?? 'N/A',
                    medicines[index]['batch_num'] ?? 'N/A',
                    medicines[index]['exp_date'] ?? 'N/A',
                    medicines[index]['quantity'].toString(),
                    medicines[index]['supplier_name'] ?? 'N/A',
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save the PDF using your existing, centralized PdfService
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'returned_medicines_report_$formattedDate.pdf';

      await PdfService.savePdfToDownloadsAndAppStorage(pdf, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to save PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Medicines'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: expiredMedicines.isEmpty
          ? const Center(child: Text('No expired medicines to return.'))
          : ListView.builder(
              itemCount: expiredMedicines.length,
              itemBuilder: (context, index) {
                final medicine = expiredMedicines[index];
                final inventoryId = medicine['id']; // ✅ This should be the Inventory.id
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 219, 219),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromARGB(255, 236, 155, 155)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine['medicine_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${medicine['generic_name'] ?? 'N/A'}'),
                            Text('${medicine['batch_num'] ?? 'N/A'}'),
                            Text('${medicine['supplier_name'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Right side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            medicine['quantity']?.toString() ?? '0',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            medicine['exp_date'] ?? 'N/A',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => markAsReturned(expiredMedicines[index]['id'], index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 224, 93, 93),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Return'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => generateAndSavePdf(expiredMedicines.cast<Map<String, dynamic>>()),
        backgroundColor: const Color.fromARGB(255, 212, 86, 86),
        foregroundColor: Colors.black,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
