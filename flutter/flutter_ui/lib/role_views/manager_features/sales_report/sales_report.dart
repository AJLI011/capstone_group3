import 'package:flutter/material.dart';
import 'package:flutter_ui/services/sales_report_service.dart'; 
import 'package:flutter_ui/services/pdf_instore_service.dart'; 
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CombinedSalesReportPage extends StatefulWidget {
  const CombinedSalesReportPage({super.key});

  @override
  _CombinedSalesReportPageState createState() => _CombinedSalesReportPageState();
}

class _CombinedSalesReportPageState extends State<CombinedSalesReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  SalesReport? _inStoreSalesReport;
  bool _isLoading = false;
  String? _errorMessage;

  final Color _primaryColor = const Color(0xFF5C7C9A);

  // --- Date Picker Logic ---

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

  // --- Report Fetching Logic ---

  Future<void> _fetchReports() async {
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
      _inStoreSalesReport = null;
    });

    final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate!);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate!);
    
    // Fetch Only In-Store Report
    try {
      final report = await fetchInStoreSalesReport(formattedStartDate, formattedEndDate);
      setState(() {
        _inStoreSalesReport = report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch In-Store report: ${e.toString()}';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // --- PDF Generation Logic ---

  Future<void> _generateAndSavePdf() async {
    if (_inStoreSalesReport == null || _inStoreSalesReport!.salesReport.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot generate PDF: No sales data was found for this period.')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final managerName = prefs.getString('name') ?? 'N/A';

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, y').format(now);
    
    final totalRevenue = _inStoreSalesReport?.totalRevenue ?? 0.0;
    final reportingPeriod = DateFormat('yyyy-MM-dd').format(_startDate!);
    final reportingPeriodEnd = DateFormat('yyyy-MM-dd').format(_endDate!);
    final reportingPeriodText = '$reportingPeriod - $reportingPeriodEnd';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final List<pw.Widget> widgets = [
            pw.Center(
              child: pw.Text(
                'SALES REPORT SUMMARY',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Text('BlueWhite Generic Pharmacy', style: pw.TextStyle(fontSize: 18)),
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
              'TOTAL REVENUE: P${totalRevenue.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.SizedBox(height: 30),
          ];

          // In-Store Section Only
          widgets.addAll([
            pw.Text(
              '--- IN-STORE SALES REPORT ---',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total In-Store Revenue: P${_inStoreSalesReport!.totalRevenue.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildReportTable(_inStoreSalesReport!),
            pw.SizedBox(height: 30),
          ]);

          return widgets;
        },
      ),
    );

    try {
      await PdfService.savePdfToDownloadsAndAppStorage(
        pdf,
        'sales_report_summary.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to save PDF.')),
        );
      }
    }
  }
  
  pw.Table _buildReportTable(SalesReport report) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(width: 1),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Medicine', 'Quantity Sold', 'Total Sale'],
      data: report.salesReport
          .map((item) => [
              item.medicine,
              item.quantitySold.toString(),
              'P${item.totalSale.toStringAsFixed(2)}',
            ])
          .toList(),
    );
  }

  // Content Builder without Tabs
  Widget _buildReportView(SalesReport? report, String title, bool isLoading) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 10),
            const Text('Fetching data...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    
    if (report == null || report.salesReport.isEmpty) { 
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('No Data Available for this period.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                  Text(
                    'P${report.totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, color: _primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Medicine')),
                DataColumn(label: Text('Quantity Sold'), numeric: true),
                DataColumn(label: Text('Total Sale'), numeric: true),
              ],
              rows: report.salesReport
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
    );
  }


  @override
  Widget build(BuildContext context) {
    bool hasReport = _inStoreSalesReport != null && _inStoreSalesReport!.salesReport.isNotEmpty;
    final double totalRevenue = _inStoreSalesReport?.totalRevenue ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- Date Pickers and Generate Button ---
          Padding(
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
                            prefixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(
                            _startDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_startDate!),
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
                            prefixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(
                            _endDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_endDate!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchReports,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isLoading ? 
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Loading...' : 'Generate Report'),
                  ),
                ),
                const SizedBox(height: 10),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))
              ],
            ),
          ),
          
          // --- Report Summary Block ---
          if (hasReport || _isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                color: const Color(0xFFE0F7FA), 
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sales Report Summary',
                              style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF00796B))),
                          IconButton(
                            onPressed: (hasReport && !_isLoading) ? _generateAndSavePdf : null,
                            icon: const Icon(Icons.picture_as_pdf, size: 24),
                            color: _primaryColor,
                            tooltip: 'Generate PDF Report',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL REVENUE:', style: TextStyle(fontSize: 16, color: Colors.black)),
                          Text(
                            'P${totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // --- Main Report Content Display Area ---
          if (hasReport || _isLoading)
            Expanded(
              child: _buildReportView(_inStoreSalesReport, 'In-Store Sales Breakdown:', _isLoading),
            ),
          
          if (!hasReport && !_isLoading && _startDate != null && _endDate != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No sales reports were found for the selected period.', 
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}