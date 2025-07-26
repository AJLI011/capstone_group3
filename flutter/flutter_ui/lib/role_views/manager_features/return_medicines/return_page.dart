import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<void> fetchExpiredMedicines() async {
    const String url = 'http://10.0.2.2:8000/api/medicines/expired/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          expiredMedicines = json.decode(response.body);
        });
      } else {
        print('Failed to load expired medicines. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching expired medicines: $e');
    }
  }

  Future<void> markAsReturned(int medicineId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Return'),
        content: const Text('Mark this medicine as returned?'),
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

    final String deleteUrl = 'http://10.0.2.2:8000/api/medicines/return/$medicineId/';

    try {
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

Future<void> generatePdf() async {
  if (expiredMedicines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No expired medicines to generate PDF.')),
    );
    return;
  }

  final pdf = pw.Document();
  final now = DateFormat('MM/dd/yy').format(DateTime.now());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
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
                pw.Text('PHARMACY NAME', style: pw.TextStyle(fontSize: 12)),
                pw.Text('DATE: $now', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1),
            pw.Table.fromTextArray(
              headers: [
                'No.',
                'Medicine',
                'Batch No.',
                'Expiration Date',
                'Expired Qty to\nbe returned',
                'Supplier'
              ],
              data: List.generate(expiredMedicines.length, (index) {
                final med = expiredMedicines[index];
                return [
                  (index + 1).toString(),
                  med['medicine_name'] ?? '',
                  med['batch_num'] ?? '',
                  med['exp_date'] ?? '',
                  med['quantity'].toString(),
                  med['supplier_name'] ?? '',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 30,
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(2),
              },
              border: pw.TableBorder.all(color: PdfColors.black),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());

  // ✅ Show a snackbar message after generating
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Return Medicine File Downloaded!')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return Medicines')),
      body: expiredMedicines.isEmpty
          ? const Center(child: Text('No expired medicines to return.'))
          : ListView.builder(
              itemCount: expiredMedicines.length,
              itemBuilder: (context, index) {
                final medicine = expiredMedicines[index];
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
                            Text('Generic: ${medicine['generic_name'] ?? 'N/A'}'),
                            Text('Batch: ${medicine['batch_num'] ?? 'N/A'}'),
                            Text('Supplier: ${medicine['supplier_name'] ?? 'N/A'}'),
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
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            medicine['exp_date'] ?? 'N/A',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => markAsReturned(medicine['id'], index),
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
        onPressed: generatePdf,
        backgroundColor: const Color.fromARGB(255, 212, 86, 86),
        foregroundColor: Colors.black,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
