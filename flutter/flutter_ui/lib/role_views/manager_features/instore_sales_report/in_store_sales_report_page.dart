import 'package:flutter/material.dart';
import 'package:flutter_ui/services/sales_report_service.dart';
import 'package:flutter_ui/services/pdf_instore_service.dart'; // updated PdfService
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InStoreSalesReportPage extends StatefulWidget {
  const InStoreSalesReportPage({super.key});

  @override
  _InStoreSalesReportPageState createState() => _InStoreSalesReportPageState();
}

class _InStoreSalesReportPageState extends State<InStoreSalesReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  SalesReport? _salesReport;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (_startDate != null && picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date cannot be before the start date.'),
          ),
        );
      } else {
        setState(() {
          _endDate = picked;
        });
      }
    }
  }

  Future<void> _fetchReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a start and end date.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _salesReport = null;
    });

    try {
      final report = await fetchInStoreSalesReport(
        '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
        '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
      );
      setState(() {
        _salesReport = report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch report: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAndSavePdf() async {
    if (_salesReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate the report first.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final managerName = prefs.getString('name') ?? 'N/A';

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, y').format(now);
    final reportingPeriodText =
        '${_salesReport!.reportingPeriod.startDate} - ${_salesReport!.reportingPeriod.endDate}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'IN-STORE SALE SUMMARY',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text('Generic Pharmacy', style: pw.TextStyle(fontSize: 16)),
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
            'Total Revenue: P${_salesReport!.totalRevenue.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 1),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Medicine', 'Quantity Sold', 'Total Sale'],
            data: _salesReport!.salesReport
                .map((item) => [
                      item.medicine,
                      item.quantitySold.toString(),
                      'P${item.totalSale.toStringAsFixed(2)}',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    try {
      final savedPath = await PdfService.savePdfToDownloadsAndAppStorage(
        pdf,
        'in_store_sales_report_summary.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ PDF saved successfully at: $savedPath')),
        );
      }
    } catch (e) {
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
      appBar: AppBar(title: const Text('In-store Sales Report'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,      
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startDate == null
                            ? 'Select Date'
                            : '${_startDate!.year}-${_startDate!.month}-${_startDate!.day}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endDate == null
                            ? 'Select Date'
                            : '${_endDate!.year}-${_endDate!.month}-${_endDate!.day}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchReport,
              child: const Text('Generate Report'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else if (_salesReport != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Report Summary',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                'Total Revenue: P${_salesReport!.totalRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                'Reporting Period: ${_salesReport!.reportingPeriod.startDate} - ${_salesReport!.reportingPeriod.endDate}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Detailed Sales Report',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // The new DataTable widget
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Medicine')),
                            DataColumn(label: Text('Quantity Sold'), numeric: true),
                            DataColumn(label: Text('Total Sale'), numeric: true),
                          ],
                          rows: _salesReport!.salesReport
                              .map(
                                (item) => DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(item.medicine)),
                                    DataCell(Text(item.quantitySold.toString())),
                                    DataCell(Text('P${item.totalSale.toStringAsFixed(2)}')),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _salesReport != null
          ? FloatingActionButton.extended(
              onPressed: _generateAndSavePdf,
              label: const Text('Generate PDF'),
              icon: const Icon(Icons.picture_as_pdf),
              backgroundColor: const Color(0xFF5C7C9A),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}