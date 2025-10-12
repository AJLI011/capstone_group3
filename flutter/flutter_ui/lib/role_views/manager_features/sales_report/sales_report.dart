import 'package:flutter/material.dart';
import 'package:flutter_ui/services/sales_report_service.dart';
import 'package:flutter_ui/services/pdf_instore_service.dart'; // Assuming this exists for saving
import 'package:flutter_ui/services/responsive_scale.dart'; 
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CombinedSalesReportPage extends StatefulWidget {
  const CombinedSalesReportPage({super.key});

  @override
  _CombinedSalesReportPageState createState() => _CombinedSalesReportPageState();
}

class _CombinedSalesReportPageState extends State<CombinedSalesReportPage> 
  with SingleTickerProviderStateMixin, ResponsiveScale { // <-- ResponsiveScale MIXIN
  DateTime? _startDate;
  DateTime? _endDate;
  SalesReport? _inStoreSalesReport;
  SalesReport? _onlineSalesReport;
  bool _isLoading = false;
  String? _errorMessage;

  late TabController _tabController;
  final Color _primaryColor = const Color(0xFF5C7C9A);

  @override
  void initState() {
    super.initState();
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
    final scale = getScaleFactor(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (_startDate != null && picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('End date cannot be before the start date.', 
              style: TextStyle(fontSize: 14 * scale)),
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
    final scale = getScaleFactor(context);

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select both a start and end date.', 
            style: TextStyle(fontSize: 14 * scale)),
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
        _errorMessage = (_errorMessage ?? '') + 'Failed to fetch In-Store report: ${e.toString()}\n';
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
        _errorMessage = (_errorMessage ?? '') + 'Failed to fetch Online report: ${e.toString()}';
      });
    }

    if (_errorMessage?.trim().isEmpty == true) {
      _errorMessage = null;
    }

    setState(() {
      _isLoading = false;
    });
    
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
  }

  // --- PDF Generation Logic (Unchanged in logic, only SnackBar text is scaled) ---
  Future<void> _generateAndSavePdf() async {
    final scale = getScaleFactor(context);

    if ((_inStoreSalesReport == null || _inStoreSalesReport!.salesReport.isEmpty) && 
        (_onlineSalesReport == null || _onlineSalesReport!.salesReport.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot generate PDF: No sales data was found for this period.',
            style: TextStyle(fontSize: 14 * scale)),
        ),
      );
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
            // PDF widgets kept unscaled (pdf package dimensions)
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF saved successfully at: $savedPath',
              style: TextStyle(fontSize: 14 * scale)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save PDF.',
              style: TextStyle(fontSize: 14 * scale)),
          ),
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

  // Helper to build the content for each TabBarView
  // Applied scale to all relevant sizes/fonts
  Widget _buildReportView(SalesReport? report, String title, bool isLoading) {
    final scale = getScaleFactor(context);
    
    // NEW LOGIC: If loading, show the spinner.
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 10 * scale),
            Text('Fetching data...', style: TextStyle(fontSize: 16 * scale, color: Colors.grey)),
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
            Icon(Icons.info_outline, size: 40 * scale, color: Colors.grey),
            SizedBox(height: 10 * scale),
            Text('No Data Available for this period.', style: TextStyle(fontSize: 16 * scale, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      // Padding scaled
      padding: EdgeInsets.symmetric(horizontal: 16.0 * scale, vertical: 16.0 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simplified summary card for the current tab
          Card(
            elevation: 2 * scale, // Scaled
            child: Padding(
              padding: EdgeInsets.all(12.0 * scale), // Scaled
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, 
                    style: TextStyle(
                      fontSize: 16 * scale, // Scaled
                      fontWeight: FontWeight.bold, 
                      color: _primaryColor,
                    )),
                  Text(
                    'P${report.totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18 * scale, // Scaled
                      color: _primaryColor, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              // Data table elements scaled
              columnSpacing: 40 * scale,
              dataRowMinHeight: 40 * scale,
              dataRowMaxHeight: 60 * scale,
              columns: <DataColumn>[
                DataColumn(label: Text('Medicine', style: TextStyle(fontSize: 14 * scale))),
                DataColumn(label: Text('Quantity Sold', style: TextStyle(fontSize: 14 * scale)), numeric: true),
                DataColumn(label: Text('Total Sale', style: TextStyle(fontSize: 14 * scale)), numeric: true),
              ],
              rows: report.salesReport
                  .map(
                    (item) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(item.medicine, style: TextStyle(fontSize: 14 * scale))),
                        DataCell(Text(item.quantitySold.toString(), style: TextStyle(fontSize: 14 * scale))),
                        DataCell(Text('P${item.totalSale.toStringAsFixed(2)}', style: TextStyle(fontSize: 14 * scale))),
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
    final scale = getScaleFactor(context); // Get scale
    
    bool hasReport = (_inStoreSalesReport != null && _inStoreSalesReport!.salesReport.isNotEmpty) || 
                     (_onlineSalesReport != null && _onlineSalesReport!.salesReport.isNotEmpty);
    final double totalRevenue = (_inStoreSalesReport?.totalRevenue ?? 0.0) + (_onlineSalesReport?.totalRevenue ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Report', style: TextStyle(fontSize: 20 * scale)), // Scaled
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- Date Pickers and Generate Button (Static Header) ---
          Padding(
            padding: EdgeInsets.all(16.0 * scale), // Scaled
            child: Column(
              children: [
                // Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today, size: 20 * scale), // Scaled
                            labelStyle: TextStyle(fontSize: 14 * scale), // Scaled
                          ),
                          child: Text(
                            _startDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_startDate!),
                                style: TextStyle(fontSize: 16 * scale), // Scaled
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * scale), // Scaled
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today, size: 20 * scale), // Scaled
                            labelStyle: TextStyle(fontSize: 14 * scale), // Scaled
                          ),
                          child: Text(
                            _endDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_endDate!),
                                style: TextStyle(fontSize: 16 * scale), // Scaled
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * scale), // Scaled
                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchReports,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12 * scale), // Scaled
                    ),
                    icon: _isLoading ? 
                        SizedBox(width: 16 * scale, height: 16 * scale, child: CircularProgressIndicator(strokeWidth: 2 * scale, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))) // Scaled
                        : Icon(Icons.search, size: 20 * scale), // Scaled
                    label: Text(_isLoading ? 'Loading...' : 'Generate Report',
                        style: TextStyle(fontSize: 16 * scale)), // Scaled
                  ),
                ),
                SizedBox(height: 10 * scale), // Scaled
                // Error Message
                if (_errorMessage != null)
                  Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 12 * scale)) // Scaled
              ],
            ),
          ),
          
          // --- Report Display Area (Conditional) ---
          if (hasReport || _isLoading)
            // Overall Summary Card (Static, always visible when data exists)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale), // Scaled
              child: Card(
                elevation: 4 * scale, // Scaled
                color: const Color(0xFFE0F7FA), // Light blue background for emphasis
                child: Padding(
                  padding: EdgeInsets.all(16.0 * scale), // Scaled
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Report Summary',
                          style: TextStyle(
                              fontSize: 18 * scale, // Scaled
                              fontWeight: FontWeight.bold, color: const Color(0xFF00796B))), // Dark teal
                      SizedBox(height: 8 * scale), // Scaled
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL REVENUE:', style: TextStyle(fontSize: 20 * scale, color: Colors.black)), // Scaled
                          Text(
                            'P${totalRevenue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22 * scale, // Scaled
                              fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      Divider(height: 16 * scale), // Scaled
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('In-Store: P${(_inStoreSalesReport?.totalRevenue ?? 0.0).toStringAsFixed(2)}', 
                            style: TextStyle(fontSize: 14 * scale)), // Scaled
                          Text('Online: P${(_onlineSalesReport?.totalRevenue ?? 0.0).toStringAsFixed(2)}', 
                            style: TextStyle(fontSize: 14 * scale)), // Scaled
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // --- Sliding Sections (TabBar and TabBarView) ---
          if (hasReport || _isLoading)
            Expanded(
              child: Column(
                children: [
                  // TabBar
                  Padding(
                    padding: EdgeInsets.only(top: 16.0 * scale, left: 16.0 * scale, right: 16.0 * scale), // Scaled
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _primaryColor,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: _primaryColor,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        // Tab labels with real-time summary data
                        Tab(
                          icon: Icon(Icons.store, size: 20 * scale), // Scaled
                          child: Text('In-Store', style: TextStyle(fontSize: 14 * scale)), // Scaled
                        ),
                        Tab(
                          icon: Icon(Icons.trending_up, size: 20 * scale), // Scaled
                          child: Text('Online', style: TextStyle(fontSize: 14 * scale)), // Scaled
                        ),
                      ],
                    ),
                  ),
                  
                  // TabBarView for Content
                  Expanded( 
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReportView(_inStoreSalesReport, 'In-Store Sales Breakdown', _isLoading),
                        _buildReportView(_onlineSalesReport, 'Online Sales Breakdown', _isLoading),
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
                      SizedBox(height: 10 * scale), // Scaled
                      Text(
                        'No sales reports were found for the selected period.', 
                        style: TextStyle(fontSize: 16 * scale, color: Colors.grey[700]), // Scaled
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
      // --- Floating Action Button (Scaled) ---
      floatingActionButton: hasReport
          ? FloatingActionButton( // CHANGED
              onPressed: _generateAndSavePdf,
              child: Icon(Icons.picture_as_pdf, size: 24 * scale), // CHANGED
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}