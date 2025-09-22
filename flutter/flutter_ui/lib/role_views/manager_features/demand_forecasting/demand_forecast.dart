// lib/screens/demand_forecast_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart'; // NEW: Charting library
import 'package:intl/intl.dart'; // NEW: For date formatting

// ====================================================================
// Step 1: DATA MODELS
// These classes represent the structure of the JSON data from your API.
// ====================================================================

class MedicineForecast {
  final int id;
  final String name;
  final String genericName;

  MedicineForecast({
    required this.id,
    required this.name,
    required this.genericName,
  });

  factory MedicineForecast.fromJson(Map<String, dynamic> json) {
    return MedicineForecast(
      id: json['id'],
      name: json['name'],
      genericName: json['generic_name'],
    );
  }
}

class ForecastItem {
  final int rank;
  final int forecastedQuantity;
  final int currentStock;
  final int restockAmount;
  final MedicineForecast medicine;

  ForecastItem({
    required this.rank,
    required this.forecastedQuantity,
    required this.currentStock,
    required this.restockAmount,
    required this.medicine,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      rank: json['rank'],
      forecastedQuantity: json['forecasted_quantity'],
      currentStock: json['current_stock'],
      restockAmount: json['restock_amount'],
      medicine: MedicineForecast.fromJson(json['medicine']),
    );
  }
}

class ForecastReport {
  final String weekStartDate;
  final String dateGenerated;
  final List<ForecastItem> items;

  ForecastReport({
    required this.weekStartDate,
    required this.dateGenerated,
    required this.items,
  });

  factory ForecastReport.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List;
    List<ForecastItem> itemsList = list.map((i) => ForecastItem.fromJson(i)).toList();

    return ForecastReport(
      weekStartDate: json['week_start_date'],
      dateGenerated: json['date_generated'],
      items: itemsList,
    );
  }
}

// NEW: Model for the historical sales data from the new API endpoint
class HistoricalSalesData {
  final DateTime weekStartDate;
  final int sales;

  HistoricalSalesData({
    required this.weekStartDate,
    required this.sales,
  });

  factory HistoricalSalesData.fromJson(Map<String, dynamic> json) {
    return HistoricalSalesData(
      weekStartDate: DateTime.parse(json['week_start_date']),
      sales: json['sales'],
    );
  }
}

// ====================================================================
// Step 2: API SERVICE
// This class handles the network request to your Django API.
// ====================================================================

class ApiService {
  static const String _baseUrl = "http://10.0.2.2:8000/api"; // For Android Emulator
  // static const String _baseUrl = "http://127.0.0.1:8000/api"; // For iOS Simulator

  Future<ForecastReport> fetchLatestForecast() async {
    final response = await http.get(Uri.parse('$_baseUrl/forecast/latest/'));

    if (response.statusCode == 200) {
      return ForecastReport.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load forecast data');
    }
  }

  // NEW METHOD: Calls the Django endpoint to generate a new forecast
  Future<void> generateForecast() async {
    final response = await http.post(Uri.parse('$_baseUrl/forecast/generate/'));

    if (response.statusCode != 200) {
      throw Exception('Failed to generate new forecast on the server.');
    }
  }

  // NEW METHOD: Fetches the historical sales data for a specific medicine
  Future<List<HistoricalSalesData>> fetchMedicineHistory(int medicineId) async {
    final response = await http.get(Uri.parse('$_baseUrl/forecast/history/$medicineId/'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => HistoricalSalesData.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load historical data');
    }
  }
}

// ====================================================================
// Step 3: UI VIEW (Screen)
// This widget fetches the data and displays it to the user.
// ====================================================================

class DemandForecastScreen extends StatefulWidget {
  const DemandForecastScreen({Key? key}) : super(key: key);

  @override
  State<DemandForecastScreen> createState() => _DemandForecastScreenState();
}

class _DemandForecastScreenState extends State<DemandForecastScreen> {
  Future<ForecastReport>? futureForecast;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
  }

  void _fetchData() {
    setState(() {
      isGenerating = true;
      futureForecast = null;
    });

    futureForecast = ApiService().generateForecast().then((_) {
      return ApiService().fetchLatestForecast();
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }).catchError((error) {
      throw error;
    });
  }

  // NEW: Method to show the bottom sheet with the plot
  void _showForecastPlot(ForecastItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Historical Sales & Forecast for\n${item.medicine.name}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: FutureBuilder<List<HistoricalSalesData>>(
                  future: ApiService().fetchMedicineHistory(item.medicine.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No historical data available.'));
                    }

                    final historicalData = snapshot.data!;
                    final List<FlSpot> spots = [];

                    // Create FlSpots for historical data
                    for (int i = 0; i < historicalData.length; i++) {
                      spots.add(FlSpot(i.toDouble(), historicalData[i].sales.toDouble()));
                    }

                    // Add a single spot for the forecasted value at the end of the line
                    spots.add(FlSpot(spots.length.toDouble(), item.forecastedQuantity.toDouble()));

                    return LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                // Display month for every few data points
                                final index = value.toInt();
                                if (index < historicalData.length && index % 4 == 0) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8.0,
                                    child: Text(DateFormat.yM().format(historicalData[index].weekStartDate),
                                        style: const TextStyle(fontSize: 10)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: const Color(0xff37434d), width: 1),
                        ),
                        minX: 0,
                        maxX: spots.length.toDouble() - 1,
                        minY: 0,
                        maxY: (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                // Make the last dot (forecasted) red
                                if (index == spots.length - 1) {
                                  return FlDotCirclePainter(color: Colors.red, radius: 4);
                                }
                                return FlDotCirclePainter(color: Colors.blue, radius: 2);
                              },
                            ),
                            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 12, height: 12, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Historical Sales'),
                  const SizedBox(width: 20),
                  Container(width: 12, height: 12, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Forecasted'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Forecast'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate a report of the top forecasted medicines.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF5C7C9A),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : _fetchData,
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.show_chart),
                label: Text(isGenerating ? 'Generating...' : 'Generate Forecast'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: futureForecast == null
                  ? const Center(
                      child: Text(
                        "Press 'Generate Forecast' to view the report.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : FutureBuilder<ForecastReport>(
                      future: futureForecast,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                isGenerating = false;
                              });
                            }
                          });
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (snapshot.hasData) {
                          final forecastReport = snapshot.data!;

                          if (forecastReport.items.isEmpty) {
                            return const Center(child: Text('No forecast data available.'));
                          }

                          // Parse the dateGenerated string into a DateTime object
                          final DateTime generatedDateTime = DateTime.parse(forecastReport.dateGenerated);
                          // Format the DateTime object to the desired format
                          final String formattedTime = DateFormat('MMM d, y hh:mm a').format(generatedDateTime);

                          // Parse the weekStartDate string into a DateTime object
                          final DateTime weekStartDateTime = DateTime.parse(forecastReport.weekStartDate);
                          // Format the DateTime object for the week start date
                          final String formattedWeekStart = DateFormat('MMM d, y').format(weekStartDateTime);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // Use the formatted time string
                                'Generated: $formattedTime',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                // Use the new formatted week start date
                                'For the week of: $formattedWeekStart',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ListView(
                                  children: [
                                    _buildTableHeader(),
                                    ...forecastReport.items.map((item) {
                                      // WRAPPING THE ROW IN AN INKWELL TO MAKE IT TAPPABLE
                                      return InkWell(
                                        onTap: () => _showForecastPlot(item),
                                        child: _buildTableRow(
                                          rank: item.rank,
                                          medicineName: item.medicine.name,
                                          forecastedQuantity: item.forecastedQuantity,
                                          currentStock: item.currentStock,
                                          restockAmount: item.restockAmount,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return const Center(child: Text("No forecast data available."));
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: const [
          Expanded(flex: 1, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Forecasted', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Restock Amount', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required int rank,
    required String medicineName,
    required int forecastedQuantity,
    required int currentStock,
    required int restockAmount,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Expanded(flex: 1, child: Text('$rank')),
            Expanded(flex: 3, child: Text(medicineName)),
            Expanded(flex: 2, child: Text('$forecastedQuantity')),
            Expanded(flex: 2, child: Text('$currentStock')),
            Expanded(
              flex: 2,
              child: Text(
                restockAmount > 0 ? '$restockAmount' : 'Sufficient',
                style: TextStyle(
                  color: restockAmount > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}