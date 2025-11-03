// lib/screens/demand_forecast_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// 🎯 YOUR SPECIFIC IMPORT PATH MUST MATCH THE FILE LOCATION
import 'package:flutter_ui/services/responsive_scale2.dart'; 

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
// Step 2: API SERVICE
// ====================================================================

class ApiService {
  static const String _baseUrl = "http://192.168.1.21:8000/api";
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
// Step 3: UI VIEW (Screen) (Updated with Responsive Scaling)
// ====================================================================

class DemandForecastScreen extends StatefulWidget {
  const DemandForecastScreen({super.key});

  @override
  State<DemandForecastScreen> createState() => _DemandForecastScreenState();
}

// 1. MIX IN THE RESPONSIVE SCALE UTILITY
class _DemandForecastScreenState extends State<DemandForecastScreen> with ResponsiveScale {
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

  void _showForecastPlot(ForecastItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Pass the item and the responsive scale mixin instance
        return PlottingWidget(item: item, responsiveScale: this); 
      },
    );
  }

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Pass the plotting function and the responsive scale mixin instance
        return SingleMedicineSearch(onShowPlot: _showForecastPlot, responsiveScale: this); 
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
        // Use scaleValue for padding
        padding: EdgeInsets.all(scaleValue(context, 16.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate a report of the top forecasted medicines.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF5C7C9A),
                  fontWeight: FontWeight.bold,
                  // Use scaleFontSize for text
                  fontSize: scaleFontSize(context, Theme.of(context).textTheme.titleLarge!.fontSize!),
                ),
            ),
            SizedBox(height: scaleValue(context, 16)),
            Center(
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : _fetchData,
                icon: isGenerating
                    ? SizedBox(
                        width: scaleValue(context, 20),
                        height: scaleValue(context, 20),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.show_chart, size: scaleValue(context, 24)),
                label: Text(
                  isGenerating ? 'Generating...' : 'Generate Forecast',
                  style: TextStyle(fontSize: scaleFontSize(context, 14)),
                ),
              ),
            ),
            SizedBox(height: scaleValue(context, 16)),
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
                    
                    // --- LIMIT ITEMS TO TOP 10 ---
                    final List<ForecastItem> top10Items = forecastReport.items.take(10).toList();


                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generated: $formattedTime',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: scaleFontSize(context, 14)),
                        ),
                        Text(
                          'For the week of: $formattedWeekStart',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: scaleFontSize(context, 14)),
                        ),
                        SizedBox(height: scaleValue(context, 16)),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildTableHeader(context),
                              ...top10Items.map((item) {
                                return InkWell(
                                  onTap: () => _showForecastPlot(item),
                                  child: _buildTableRow(
                                    context: context,
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

  // REVISED HEADER WIDGET
  Widget _buildTableHeader(BuildContext context) {
    const double baseFontSize = 10.5; 
    const double baseVerticalPadding = 8.0;
    const double baseHorizontalPadding = 8.0;

    TextStyle headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: scaleFontSize(context, baseFontSize));

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: scaleValue(context, baseVerticalPadding), 
        horizontal: scaleValue(context, baseHorizontalPadding)
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(scaleValue(context, 8.0)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Center(child: Text('No.', style: headerStyle))),
          // CHANGE 1: Remove Center around Medicine header. The header text is still center-aligned via the headerStyle's TextAlign.
          Expanded(flex: 3, child: Center(child: Text('Medicine', style: headerStyle))),
          Expanded(flex: 3, child: Center(child: Text('Forecast', style: headerStyle))),
          Expanded(flex: 3, child: Center(child: Text('Current Stock', style: headerStyle))),
          Expanded(flex: 2, child: Center(child: Text('ROL', style: headerStyle))), 
          Expanded(flex: 2, child: Center(child: Text('Restock', style: headerStyle))),
        ],
      ),
    );
  }

  // REVISED TABLE ROW WIDGET
  Widget _buildTableRow({
    required BuildContext context, 
    required int rank,
    required String medicineName,
    required int forecastedQuantity,
    required int currentStock,
    required int restockAmount,
    required int reorderLevel, 
  }) {
    const double baseRowFontSize = 10.0; 

    return Card(
      // Scale the vertical margin
      margin: EdgeInsets.symmetric(vertical: scaleValue(context, 4.0)),
      child: Padding(
        // Scale the padding
        padding: EdgeInsets.symmetric(vertical: scaleValue(context, 11.0), horizontal: scaleValue(context, 7.0)),
        child: Row(
          children: [
            Expanded(
              flex: 1, 
              child: Text('$rank', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: scaleFontSize(context, baseRowFontSize))
              )
            ),
            Expanded(
              flex: 3,
              child: Text(
                medicineName,
                // CHANGE 2: Set text alignment to center to align the medicine name under the header.
                textAlign: TextAlign.center,
                style: medicineName == 'Medicine Deleted' 
                  ? TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: scaleFontSize(context, baseRowFontSize + 1)) 
                  : TextStyle(fontSize: scaleFontSize(context, baseRowFontSize + 1)),
              )
            ),
            Expanded(
              flex: 3, 
              child: Text('$forecastedQuantity', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: scaleFontSize(context, baseRowFontSize))
              )
            ),
            Expanded(
              flex: 3, 
              child: Text(
                '$currentStock', 
                // CHANGE 3: Set text alignment to center to match the header.
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaleFontSize(context, baseRowFontSize),
                  color: currentStock < reorderLevel ? Colors.orange[700] : Colors.green[700],
                  fontWeight: currentStock < reorderLevel ? FontWeight.bold : FontWeight.normal,
                )
              )
            ),
            Expanded(
              flex: 2, 
              child: Text('$reorderLevel', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: scaleFontSize(context, baseRowFontSize), color: const Color(0xFF5C7C9A), fontWeight: FontWeight.bold)
              )
            ), 
            Expanded(
              flex: 2,
              child: Text(
                restockAmount > 0 ? '$restockAmount' : 'Sufficient',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaleFontSize(context, baseRowFontSize), 
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
// Step 4: NEW WIDGET FOR SINGLE MEDICINE SEARCH (Scaled)
// ====================================================================

class SingleMedicineSearch extends StatefulWidget {
  final Function(ForecastItem item) onShowPlot;
  // Propagate the scale mixin for nested widgets
  final ResponsiveScale responsiveScale;
  
  const SingleMedicineSearch({super.key, required this.onShowPlot, required this.responsiveScale});

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
    final ResponsiveScale rs = widget.responsiveScale;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Padding(
      padding: EdgeInsets.only(
        top: rs.scaleValue(context, 20.0),
        left: rs.scaleValue(context, 20.0),
        right: rs.scaleValue(context, 20.0),
        bottom: bottomPadding > 0 ? bottomPadding : rs.scaleValue(context, 20.0), 
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Search Medicine Forecast',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: rs.scaleFontSize(context, Theme.of(context).textTheme.titleLarge!.fontSize!),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: rs.scaleValue(context, 20)),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Medicine Name',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoading
                  ? Padding(
                      padding: EdgeInsets.all(rs.scaleValue(context, 8.0)),
                      child: SizedBox(width: rs.scaleValue(context, 20), height: rs.scaleValue(context, 20), child: const CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchMedicine,
                    ),
            ),
            onSubmitted: (_) => _searchMedicine(),
          ),
          SizedBox(height: rs.scaleValue(context, 20)),
          
          // --- Display Area ---
          if (_isLoading)
            const Center(child: Text('Searching...'))
          else if (_errorMessage != null)
            Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          else if (_searchResult != null)
            _buildResultCard(_searchResult!, rs)
          else
            const Center(child: Text('Enter a medicine name to see its forecast.')),
          
          SizedBox(height: rs.scaleValue(context, 10)),
        ],
      ),
    );
  }

  Widget _buildResultCard(ForecastItem item, ResponsiveScale rs) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(rs.scaleValue(context, 16.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.medicine.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: rs.scaleFontSize(context, 24)),
            ),
            Text(
              item.medicine.genericName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[700], fontSize: rs.scaleFontSize(context, 14)),
            ),
            Divider(height: rs.scaleValue(context, 20)),
            _buildInfoRow('Forecasted Demand:', item.forecastedQuantity.toString(), Colors.blue, rs),
            _buildInfoRow('Reorder Level (ROL):', item.reorderLevel.toString(), const Color(0xFF5C7C9A), rs),
            _buildInfoRow('Current Stock:', item.currentStock.toString(), item.currentStock < item.reorderLevel ? Colors.orange[700]! : Colors.green[700]!, rs),
            _buildInfoRow('Restock Recommendation:', item.restockAmount > 0 ? item.restockAmount.toString() : 'Sufficient', item.restockAmount > 0 ? Colors.red : Colors.green, rs),
            SizedBox(height: rs.scaleValue(context, 10)),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Pass the scaled item to the plot function
                  widget.onShowPlot(item); 
                },
                icon: Icon(Icons.bar_chart, size: rs.scaleValue(context, 20)),
                label: Text('View Historical Chart', style: TextStyle(fontSize: rs.scaleFontSize(context, 14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor, ResponsiveScale rs) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: rs.scaleValue(context, 4.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: rs.scaleFontSize(context, 14))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: rs.scaleFontSize(context, 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Step 5: DEDICATED PLOTTING WIDGET (Scaled and 'Forecast' label removed)
// ====================================================================

class PlottingWidget extends StatelessWidget {
  final ForecastItem item;
  // Propagate the scale mixin for nested widgets
  final ResponsiveScale responsiveScale;
  
  const PlottingWidget({super.key, required this.item, required this.responsiveScale});

  @override
  Widget build(BuildContext context) {
    final ResponsiveScale rs = responsiveScale;

    return Padding(
      padding: EdgeInsets.all(rs.scaleValue(context, 16.0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Historical Sales & Forecast for\n${item.medicine.name}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: rs.scaleFontSize(context, 20)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: rs.scaleValue(context, 20)),
          SizedBox(
            height: rs.scaleValue(context, 300),
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
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: rs.scaleFontSize(context, 14)),
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
                          reservedSize: rs.scaleValue(context, 30),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            // Only show historical dates and skip the final 'Forecast' point
                            if (index < historicalData.length && index % 4 == 0) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: rs.scaleValue(context, 8.0),
                                child: Text(DateFormat.yM().format(historicalData[index].weekStartDate),
                                    style: TextStyle(fontSize: rs.scaleFontSize(context, 10))),
                              );
                            }
                            // Removed the specific logic for the 'Forecast' label here
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: rs.scaleValue(context, 40),
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString(), style: TextStyle(fontSize: rs.scaleFontSize(context, 10)));
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: const Color(0xff37434d), width: rs.scaleValue(context, 1)),
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
                        barWidth: rs.scaleValue(context, 3),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            // Highlight the final point (the forecast) in red
                            if (index == spots.length - 1) {
                              return FlDotCirclePainter(color: Colors.red, radius: rs.scaleValue(context, 4), strokeColor: Colors.transparent,);
                            }
                            return FlDotCirclePainter(color: Colors.blue, radius: rs.scaleValue(context, 2));
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
          SizedBox(height: rs.scaleValue(context, 20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: rs.scaleValue(context, 12), height: rs.scaleValue(context, 12), color: Colors.blue),
              SizedBox(width: rs.scaleValue(context, 8)),
              Text('Historical Sales', style: TextStyle(fontSize: rs.scaleFontSize(context, 12))),
              SizedBox(width: rs.scaleValue(context, 20)),
              Container(width: rs.scaleValue(context, 12), height: rs.scaleValue(context, 12), color: Colors.red),
              SizedBox(width: rs.scaleValue(context, 8)),
              Text('Forecasted', style: TextStyle(fontSize: rs.scaleFontSize(context, 12))),
            ],
          ),
        ],
      ),
    );
  }
}