import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

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
                pw.Text('PHARMACY NAME', style: pw.TextStyle(fontSize: 12)),
                pw.Text('DATE: $now', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 1),
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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

  try {
    final bytes = await pdf.save();

    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir != null) {
        // Adjust to real Downloads directory
        String newPath = "";
        List<String> paths = downloadsDir.path.split("/");
        for (int i = 1; i < paths.length; i++) {
          String folder = paths[i];
          if (folder == "Android") break;
          newPath += "/$folder";
        }
        newPath += "/Download";
        downloadsDir = Directory(newPath);
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      throw Exception("Downloads folder not found.");
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
    final file = File('${downloadsDir.path}/returned_medicines_report_$formattedDate.pdf');
    await file.writeAsBytes(await pdf.save());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ PDF saved at: ${file.path}')),
      );
    }

    print('✅ PDF saved at: ${file.path}');
  } catch (e) {
    print('❌ Error saving PDF: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save PDF.')),
      );
    }
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
        onPressed: () => generateAndSavePdf(expiredMedicines.cast<Map<String, dynamic>>()),
        backgroundColor: const Color.fromARGB(255, 212, 86, 86),
        foregroundColor: Colors.black,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
