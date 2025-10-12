// lib/screens/demand_forecast_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ====================================================================
// Step 1: DATA MODELS
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
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Medicine Deleted',
      genericName: json['generic_name'] ?? 'N/A',
    );
  }
}

class ForecastItem {
  final int rank;
  final int forecastedQuantity;
  final int currentStock;
  final int restockAmount;
  final int reorderLevel; 
  final MedicineForecast medicine;

  ForecastItem({
    required this.rank,
    required this.forecastedQuantity,
    required this.currentStock,
    required this.restockAmount,
    required this.reorderLevel, 
    required this.medicine,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      rank: json['rank'] ?? 0,
      forecastedQuantity: json['forecasted_quantity'] ?? 0,
      currentStock: json['current_stock'] ?? 0,
      restockAmount: json['restock_amount'] ?? 0,
      reorderLevel: json['reorder_level'] ?? 0, 
      medicine: json['medicine'] != null
          ? MedicineForecast.fromJson(json['medicine'])
          : MedicineForecast(
              id: 0,
              name: json['medicine_name'] ?? 'Medicine Deleted',
              genericName: json['generic_name'] ?? 'N/A'
            ),
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
// Step 2: API SERVICE (UPDATED with Search)
// ====================================================================

class ApiService {
  static const String _baseUrl = "http://192.168.1.11:8000/api";
  // static const String _baseUrl = "http://127.0.0.1:8000/api";

  Future<ForecastReport?> fetchLatestForecast() async {
    final response = await http.get(Uri.parse('$_baseUrl/forecast/latest/'));

    if (response.statusCode == 200) {
      return ForecastReport.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load forecast data');
    }
  }

  Future<void> generateForecast() async {
    final response = await http.post(Uri.parse('$_baseUrl/forecast/generate/'));

    if (response.statusCode != 200) {
      throw Exception('Failed to generate new forecast on the server.');
    }
  }

  Future<List<HistoricalSalesData>> fetchMedicineHistory(int medicineId) async {
    final response = await http.get(Uri.parse('$_baseUrl/forecast/history/$medicineId/'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => HistoricalSalesData.fromJson(item)).toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to load historical data');
    }
  }

  Future<ForecastItem?> fetchMedicineForecastByName(String medicineName) async {
    final encodedName = Uri.encodeComponent(medicineName);
    final response = await http.get(Uri.parse('$_baseUrl/forecast/medicine/?name=$encodedName'));

    if (response.statusCode == 200) {
      // Assuming the backend returns the single ForecastItem object directly
      return ForecastItem.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to search for medicine forecast: ${response.statusCode}');
    }
  }
}

// ====================================================================
// Step 3: UI VIEW (Screen) (Updated to Limit to Top 10)
// ====================================================================

class DemandForecastScreen extends StatefulWidget {
  const DemandForecastScreen({super.key});

  @override
  State<DemandForecastScreen> createState() => _DemandForecastScreenState();
}

class _DemandForecastScreenState extends State<DemandForecastScreen> {
  Future<ForecastReport?>? futureForecast;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    futureForecast = ApiService().fetchLatestForecast(); 
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
      // Optionally display a snackbar error here
      throw error;
    });
  }

  // Helper method to show the plotting modal, now using the PlottingWidget
  void _showForecastPlot(ForecastItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return PlottingWidget(item: item); 
      },
    );
  }

  // Method to show the search modal
  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Pass the plotting function to the search modal
        return SingleMedicineSearch(onShowPlot: _showForecastPlot); 
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
        actions: [ 
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchModal, 
            tooltip: 'Search for a specific medicine forecast',
          ),
        ],
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
              child: FutureBuilder<ForecastReport?>(
                future: futureForecast,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && futureForecast != null) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData && snapshot.data != null) {
                    final forecastReport = snapshot.data!;

                    if (forecastReport.items.isEmpty) {
                      return const Center(child: Text('No forecast data available.'));
                    }

                    final DateTime generatedDateTime = DateTime.parse(forecastReport.dateGenerated);
                    final String formattedTime = DateFormat('MMM d, y hh:mm a').format(generatedDateTime);

                    final DateTime weekStartDateTime = DateTime.parse(forecastReport.weekStartDate);
                    final String formattedWeekStart = DateFormat('MMM d, y').format(weekStartDateTime);
                    
                    // --- FIX: LIMIT ITEMS TO TOP 10 ---
                    final List<ForecastItem> top10Items = forecastReport.items.take(10).toList();


                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generated: $formattedTime',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          'For the week of: $formattedWeekStart',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildTableHeader(context),
                              ...top10Items.map((item) {
                                return InkWell(
                                  onTap: () => _showForecastPlot(item),
                                  child: _buildTableRow(
                                    rank: item.rank,
                                    medicineName: item.medicine.name,
                                    forecastedQuantity: item.forecastedQuantity,
                                    currentStock: item.currentStock,
                                    restockAmount: item.restockAmount,
                                    reorderLevel: item.reorderLevel, 
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const Center(child: Text("Press 'Generate Forecast' to view the report."));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: const [
          Expanded(flex: 1, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(flex: 3, child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(flex: 2, child: Text('Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(flex: 2, child: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(flex: 2, child: Text('ROL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))), 
          Expanded(flex: 2, child: Text('Restock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
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
    required int reorderLevel, 
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 7.0),
        child: Row(
          children: [
            Expanded(flex: 1, child: Text('$rank', style: const TextStyle(fontSize: 11))),
            Expanded(
              flex: 3,
              child: Text(
                medicineName,
                style: medicineName == 'Medicine Deleted' ? const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12) : const TextStyle(fontSize: 12),
              )
            ),
            Expanded(flex: 2, child: Text('$forecastedQuantity', style: const TextStyle(fontSize: 11))),
            Expanded(
              flex: 2, 
              child: Text(
                '$currentStock', 
                style: TextStyle(
                  fontSize: 11,
                  // Color cue for low stock (below ROL)
                  color: currentStock < reorderLevel ? Colors.orange[700] : Colors.green[700],
                  fontWeight: currentStock < reorderLevel ? FontWeight.bold : FontWeight.normal,
                )
              )
            ),
            Expanded(flex: 2, child: Text('$reorderLevel', style: const TextStyle(fontSize: 11, color: Color(0xFF5C7C9A), fontWeight: FontWeight.bold))), 
            Expanded(
              flex: 2,
              child: Text(
                restockAmount > 0 ? '$restockAmount' : 'Sufficient',
                style: TextStyle(
                  fontSize: 10,
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

// ====================================================================
// Step 4: NEW WIDGET FOR SINGLE MEDICINE SEARCH
// ====================================================================

class SingleMedicineSearch extends StatefulWidget {
  final Function(ForecastItem item) onShowPlot;
  
  const SingleMedicineSearch({super.key, required this.onShowPlot});

  @override
  State<SingleMedicineSearch> createState() => _SingleMedicineSearchState();
}

class _SingleMedicineSearchState extends State<SingleMedicineSearch> {
  final TextEditingController _searchController = TextEditingController();
  ForecastItem? _searchResult;
  bool _isLoading = false;
  String? _errorMessage;

  void _searchMedicine() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a medicine name.';
        _searchResult = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _errorMessage = null;
    });

    try {
      final result = await ApiService().fetchMedicineForecastByName(name);
      setState(() {
        _searchResult = result;
        if (result == null) {
          _errorMessage = 'No forecast found for "$name". Check the name or try generating a new report.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred during search.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Padding(
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: bottomPadding > 0 ? bottomPadding : 20.0, 
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Search Medicine Forecast',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Medicine Name',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchMedicine,
                    ),
            ),
            onSubmitted: (_) => _searchMedicine(),
          ),
          const SizedBox(height: 20),
          
          // --- Display Area ---
          if (_isLoading)
            const Center(child: Text('Searching...'))
          else if (_errorMessage != null)
            Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          else if (_searchResult != null)
            _buildResultCard(_searchResult!)
          else
            const Center(child: Text('Enter a medicine name to see its forecast.')),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildResultCard(ForecastItem item) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.medicine.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              item.medicine.genericName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[700]),
            ),
            const Divider(height: 20),
            _buildInfoRow('Forecasted Demand:', item.forecastedQuantity.toString(), Colors.blue),
            _buildInfoRow('Reorder Level (ROL):', item.reorderLevel.toString(), const Color(0xFF5C7C9A)),
            _buildInfoRow('Current Stock:', item.currentStock.toString(), item.currentStock < item.reorderLevel ? Colors.orange[700]! : Colors.green[700]!),
            _buildInfoRow('Restock Recommendation:', item.restockAmount > 0 ? item.restockAmount.toString() : 'Sufficient', item.restockAmount > 0 ? Colors.red : Colors.green),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Call the plot function passed from the parent screen
                  widget.onShowPlot(item); 
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('View Historical Chart'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Step 5: DEDICATED PLOTTING WIDGET
// ====================================================================

class PlottingWidget extends StatelessWidget {
  final ForecastItem item;
  
  const PlottingWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
                final List<FlSpot> spots = [];

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } 
                
                bool isDataMissing = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;
                
                if (isDataMissing) {
                  return Center(
                    child: Text(
                      item.medicine.id == 0 
                      ? 'Historical data is not available as the medicine has been deleted.'
                      : 'No historical data available. Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    )
                  );
                }
                
                final historicalData = snapshot.data!;
                for (int i = 0; i < historicalData.length; i++) {
                  spots.add(FlSpot(i.toDouble(), historicalData[i].sales.toDouble()));
                }
                // Add the forecast point
                spots.add(FlSpot(spots.length.toDouble(), item.forecastedQuantity.toDouble()));
              
                double maxY = (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
                
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
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            // Highlight the final point (the forecast) in red
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
  }
}