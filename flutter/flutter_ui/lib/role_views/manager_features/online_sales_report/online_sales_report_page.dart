// lib/pages/online_sales_report_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/sales_report_service.dart';
import 'package:flutter_ui/services/pdf_online_service.dart';

class OnlineSalesReportPage extends StatefulWidget {
  const OnlineSalesReportPage({super.key});

  @override
  _OnlineSalesReportPageState createState() => _OnlineSalesReportPageState();
}

class _OnlineSalesReportPageState extends State<OnlineSalesReportPage> {
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
      final report = await fetchOnlineSalesReport(
        DateFormat('yyyy-MM-dd').format(_startDate!),
        DateFormat('yyyy-MM-dd').format(_endDate!),
      );
      setState(() {
        _salesReport = report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch online sales report: ${e.toString()}';
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

    // Call the online-specific PDF service
    try {
      final salesJson = {
        'total_revenue': _salesReport!.totalRevenue,
        'reporting_period': {
          'start_date': _salesReport!.reportingPeriod.startDate,
          'end_date': _salesReport!.reportingPeriod.endDate,
        },
        'sales_report': _salesReport!.salesReport
            .map((item) => {
                  'medicine': item.medicine,
                  'quantity_sold': item.quantitySold,
                  'total_sale': item.totalSale,
                })
            .toList(),
      };

      await PdfOnlineService.generateAndSavePdf(salesJson: salesJson);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF saved successfully to downloads.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to save PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Sales Report'),
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