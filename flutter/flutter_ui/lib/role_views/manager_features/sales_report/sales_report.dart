import 'package:flutter/material.dart';
import 'package:flutter_ui/services/sales_report_service.dart'; 
import 'package:flutter_ui/services/pdf_instore_service.dart'; 
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. ADD SingleTickerProviderStateMixin for TabController
class CombinedSalesReportPage extends StatefulWidget {
  const CombinedSalesReportPage({super.key});

  @override
  _CombinedSalesReportPageState createState() => _CombinedSalesReportPageState();
}

class _CombinedSalesReportPageState extends State<CombinedSalesReportPage> with SingleTickerProviderStateMixin {
  DateTime? _startDate;
  DateTime? _endDate;
  SalesReport? _inStoreSalesReport;
  SalesReport? _onlineSalesReport;
  bool _isLoading = false;
  String? _errorMessage;

  // 2. Add TabController
  late TabController _tabController;
  final Color _primaryColor = const Color(0xFF5C7C9A);

  @override
  void initState() {
    super.initState();
    // Initialize TabController with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Date Picker Logic (Unchanged) ---

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

  // --- Report Fetching Logic (Unchanged) ---

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
      _onlineSalesReport = null;
    });

    final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate!);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate!);
    
    // Fetch In-Store Report
    try {
      final report = await fetchInStoreSalesReport(formattedStartDate, formattedEndDate);
      setState(() {
        _inStoreSalesReport = report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${_errorMessage ?? ''}Failed to fetch In-Store report: ${e.toString()}\n';
      });
    }

    // Fetch Online Report
    try {
      final report = await fetchOnlineSalesReport(formattedStartDate, formattedEndDate);
      setState(() {
        _onlineSalesReport = report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${_errorMessage ?? ''}Failed to fetch Online report: ${e.toString()}';
      });
    }

    if (_errorMessage?.trim().isEmpty == true) {
      _errorMessage = null;
    }

    setState(() {
      _isLoading = false;
    });
    
    // Reset to the first tab after fetching
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
  }

  // --- PDF Generation Logic (Unchanged) ---

  Future<void> _generateAndSavePdf() async {
    if ((_inStoreSalesReport == null || _inStoreSalesReport!.salesReport.isEmpty) && 
        (_onlineSalesReport == null || _onlineSalesReport!.salesReport.isEmpty)) {
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
    
    final totalRevenue = (_inStoreSalesReport?.totalRevenue ?? 0.0) + (_onlineSalesReport?.totalRevenue ?? 0.0);
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

          // In-Store Section
          if (_inStoreSalesReport != null && _inStoreSalesReport!.salesReport.isNotEmpty) {
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
          } else if (_inStoreSalesReport == null || _inStoreSalesReport!.salesReport.isEmpty) {
              widgets.addAll([
              pw.Text('--- IN-STORE SALES REPORT ---', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('No Data Available for this period.', style: const pw.TextStyle(color: PdfColors.grey))),
              pw.SizedBox(height: 30),
            ]);
          }

          // Online Section
          if (_onlineSalesReport != null && _onlineSalesReport!.salesReport.isNotEmpty) {
            widgets.addAll([
              pw.Text(
                '--- ONLINE SALES REPORT ---',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Online Revenue: P${_onlineSalesReport!.totalRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildReportTable(_onlineSalesReport!),
              pw.SizedBox(height: 30),
            ]);
          } else if (_onlineSalesReport == null || _onlineSalesReport!.salesReport.isEmpty) {
              widgets.addAll([
              pw.Text('--- ONLINE SALES REPORT ---', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('No Data Available for this period.', style: const pw.TextStyle(color: PdfColors.grey))),
              pw.SizedBox(height: 30),
            ]);
          }

          return widgets;
        },
      ),
    );

    try {
      final savedPath = await PdfService.savePdfToDownloadsAndAppStorage(
        pdf,
        'sales_report_summary.pdf',
      );

      // if (context.mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('✅ PDF saved successfully at: $savedPath')),
      //   );
      // }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to save PDF.')),
        );
      }
    }
  }
  
  // Helper to build a table for the PDF (Unchanged)
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

  // Helper to build the content for each TabBarView (Unchanged)
  Widget _buildReportView(SalesReport? report, String title, bool isLoading) {
    
    // NEW LOGIC: If loading, show the spinner.
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
    
    // EXISTING LOGIC: If not loading AND data is null/empty, show "No Data" message
    if (report == null || report.salesReport.isEmpty) { 
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            // The requested display message
            Text('No Data Available for this period.', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    // ... rest of the widget unchanged (shows data table) ...
    return SingleChildScrollView(
      // Add padding to ensure content is readable
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simplified summary card for the current tab
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
    bool hasReport = (_inStoreSalesReport != null && _inStoreSalesReport!.salesReport.isNotEmpty) || 
                     (_onlineSalesReport != null && _onlineSalesReport!.salesReport.isNotEmpty);
    final double totalRevenue = (_inStoreSalesReport?.totalRevenue ?? 0.0) + (_onlineSalesReport?.totalRevenue ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- Date Pickers and Generate Button (Static Header) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Pickers
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
                // Generate Button
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
                // Error Message
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))
              ],
            ),
          ),
          
          // --- Report Display Area (Conditional) ---
          if (hasReport || _isLoading) // Show summary/tabs while loading
            // Overall Summary Card (Static, always visible when data exists)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                color: const Color(0xFFE0F7FA), // Light blue background for emphasis
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Combined title and PDF button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sales Report Summary',
                              style: TextStyle(
                                  // Reduced font size from 18 to 16
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF00796B))), // Dark teal
                          // PDF Download Button (replaces the FAB)
                          IconButton(
                            // Button is enabled only if there's report data AND not currently loading/fetching
                            onPressed: (hasReport && !_isLoading) ? _generateAndSavePdf : null,
                            icon: const Icon(Icons.picture_as_pdf, size: 24),
                            color: _primaryColor,
                            tooltip: 'Generate PDF Report', // Added tooltip for accessibility
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Reduced font size from 20 to 16
                          const Text('TOTAL REVENUE:', style: TextStyle(fontSize: 16, color: Colors.black)),
                          Text(
                            'P${totalRevenue.toStringAsFixed(2)}',
                            // Reduced font size from 22 to 18
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Added a dedicated smaller TextStyle to ensure it fits and avoids overflow
                          Text(
                            'In-Store: P${(_inStoreSalesReport?.totalRevenue ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          // Added a dedicated smaller TextStyle to ensure it fits and avoids overflow
                          Text(
                            'Online: P${(_onlineSalesReport?.totalRevenue ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // --- Sliding Sections (TabBar and TabBarView) ---
          if (hasReport || _isLoading) // Show tabs while loading
            Expanded(
              child: Column(
                children: [
                  // TabBar
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _primaryColor,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: _primaryColor,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        // Tab labels with real-time summary data
                        Tab(
                          icon: Icon(Icons.store, size: 20),
                          text: 'In-Store',
                        ),
                        Tab(
                          icon: Icon(Icons.trending_up, size: 20),
                          text: 'Online',
                        ),
                      ],
                    ),
                  ),
                  
                  // TabBarView for Content
                  Expanded( 
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // MODIFIED: Pass _isLoading to _buildReportView
                        _buildReportView(_inStoreSalesReport, 'Sales Breakdown:', _isLoading),
                        
                        // MODIFIED: Pass _isLoading to _buildReportView
                        _buildReportView(_onlineSalesReport, 'Sales Breakdown:', _isLoading),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // General No Report Message (Only show if not loading AND no data)
          if (!hasReport && !_isLoading && _startDate != null && _endDate != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'No sales reports were found for the selected period.', 
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
      // MODIFICATION: Removed the Floating Action Button
      floatingActionButton: null,
    );
  }
}