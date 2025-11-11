import 'dart:convert';
import 'package:http/http.dart' as http;

// Data model for a single medicine's sales item
class SaleItem {
  final String medicine;
  final int quantitySold;
  final double totalSale;

  SaleItem({
    required this.medicine,
    required this.quantitySold,
    required this.totalSale,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      medicine: json['medicine'],
      quantitySold: json['quantity_sold'],
      totalSale: (json['total_sale'] as num).toDouble(),
    );
  }
}

// Data model for the reporting period
class ReportingPeriod {
  final String startDate;
  final String endDate;

  ReportingPeriod({
    required this.startDate,
    required this.endDate,
  });

  factory ReportingPeriod.fromJson(Map<String, dynamic> json) {
    return ReportingPeriod(
      startDate: json['start_date'],
      endDate: json['end_date'],
    );
  }
}

// Main data model for the entire sales report
class SalesReport {
  final double totalRevenue;
  final ReportingPeriod reportingPeriod;
  final List<SaleItem> salesReport;

  SalesReport({
    required this.totalRevenue,
    required this.reportingPeriod,
    required this.salesReport,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    var salesReportList = json['sales_report'] as List;
    List<SaleItem> salesReportItems = salesReportList
        .map((item) => SaleItem.fromJson(item))
        .toList();

    return SalesReport(
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      reportingPeriod: ReportingPeriod.fromJson(json['reporting_period']),
      salesReport: salesReportItems,
    );
  }
}

// Correct base URL for Android emulator to connect to host machine's localhost
const String baseUrl = '10.0.2.2:8000/api';

Future<SalesReport> fetchInStoreSalesReport(
    String startDate, String endDate) async {
  final response = await http.get(Uri.parse(
      '$baseUrl/in-store-sales-report/?start_date=$startDate&end_date=$endDate'));

  if (response.statusCode == 200) {
    // If the server returns a 200 OK response, parse the JSON.
    return SalesReport.fromJson(jsonDecode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // throw an exception.
    throw Exception('Failed to load sales report');
  }
}

Future<SalesReport> fetchOnlineSalesReport(
    String startDate, String endDate) async {
  final response = await http.get(Uri.parse(
      '$baseUrl/online-sales-report/?start_date=$startDate&end_date=$endDate'));

  if (response.statusCode == 200) {
    // If the server returns a 200 OK response, parse the JSON.
    return SalesReport.fromJson(jsonDecode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // throw an exception.
    throw Exception('Failed to load online sales report');
  }
}