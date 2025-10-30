// lib/role_views/manager_features/purchase_request_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_purchase_request_service.dart';

// Define a common color palette for better consistency
const Color _primaryColor = Color(0xFF5C7C9A); // Dark Blue
const Color _accentColor = Color(0xFF5C7C9A); // Mid Blue

class PurchaseRequestPage extends StatefulWidget {
    const PurchaseRequestPage({super.key});

    @override
    State<PurchaseRequestPage> createState() => _PurchaseRequestPageState();
}

class _PurchaseRequestPageState extends State<PurchaseRequestPage> with SingleTickerProviderStateMixin {
    List<Map<String, dynamic>> _editablePurchaseRequests = [];
    List<Map<String, dynamic>> _lowStockItems = []; // NEW: List for low stock data
    late TabController _tabController; // NEW: Tab controller
    bool _isLoading = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        // NEW: Initialize TabController for two tabs
        _tabController = TabController(length: 2, vsync: this);
        _fetchPurchaseRequests(); // This now calls _fetchLowStockItems internally
    }

    @override
    void dispose() {
        // NEW: Dispose the TabController
        _tabController.dispose();
        // Dispose existing controllers before clearing the list
        for (var item in _editablePurchaseRequests) {
            (item['controller'] as TextEditingController).dispose();
        }
        super.dispose();
    }

    // NEW: Extracted function to fetch low stock items
    Future<void> _fetchLowStockItems() async {
        setState(() {
            _lowStockItems = [];
        });

        try {
            const String lowStockApiUrl = 'http://10.0.2.2:8000/api/medicines/low-stock/';
            final lowStockResponse = await http.get(Uri.parse(lowStockApiUrl));

            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                setState(() {
                    _lowStockItems = fetchedLowStockData.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> item = entry.value as Map<String, dynamic>;

                        return {
                            // Using index + 1 for 'No.' in the report
                            'no': index + 1, 
                            'medicine_name': item['name'] ?? 'Unknown Medicine',
                            'restock_amount': item['restock_quantity'] ?? 0,
                            'total_quantity': item['total_quantity'] ?? 0, // Current stock
                            'units_per_items': 1, // Placeholder, adjust if structure changes
                            'supplier_name': item['supplier_name'] ?? 'N/A', 
                            'contact_num': item['contact_num'] ?? 'N/A', 
                        };
                    }).toList();
                });
            } else if (lowStockResponse.statusCode == 404) {
                 debugPrint('No low stock items found.');
            } else {
                debugPrint('Warning: Failed to load low stock items. Status code: ${lowStockResponse.statusCode}');
            }
        } catch (e) {
            debugPrint('Error fetching low stock items: $e');
        }
    }

    Future<void> _fetchPurchaseRequests() async {
        setState(() {
            _isLoading = true;
            _errorMessage = null;
            // Dispose existing controllers before clearing the list
            for (var item in _editablePurchaseRequests) {
                (item['controller'] as TextEditingController).dispose();
            }
            _editablePurchaseRequests = [];
        });
        
        // Fetch low stock items first/concurrently
        await _fetchLowStockItems();
        
        const String apiUrl = 'http://10.0.2.2:8000/api/purchase-request/';
        try {
            final response = await http.get(Uri.parse(apiUrl));

            if (response.statusCode == 200) {
                List<dynamic> fetchedData = json.decode(response.body);
                setState(() {
                    _editablePurchaseRequests = fetchedData.map((item) {
                        return {
                            'no': item['no'],
                            'medicine_name': item['medicine_name'],
                            'restock_amount': item['restock_amount'],
                            'units_per_items': item['units_per_items'],
                            'supplier_name': item['supplier_name'],
                            'contact_num': item['contact_num'],
                            'controller': TextEditingController(text: item['restock_amount'].toString()),
                        };
                    }).toList().cast<Map<String, dynamic>>();
                    _isLoading = false;
                });
            } else if (response.statusCode == 404) {
                setState(() {
                    _isLoading = false;
                });
            } else {
                setState(() {
                    _errorMessage = 'Failed to load purchase requests. Status code: ${response.statusCode}';
                    _isLoading = false;
                });
            }
        } catch (e) {
            setState(() {
                _errorMessage = 'An error occurred: $e';
                _isLoading = false;
            });
        }
    }

    Future<void> _generateAndSavePdf() async {
        if (_editablePurchaseRequests.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No purchase requests to generate PDF.')),
            );
            return;
        }

        setState(() {
            _isLoading = true;
        });

        try {
            // Note: _lowStockItems is already populated from page load! We no longer fetch it here.
            final List<Map<String, dynamic>> finalPurchaseRequests = _editablePurchaseRequests.map((item) {
                return {
                    ...item,
                    // Ensure the latest edited value from the controller is used
                    'restock_amount': int.tryParse((item['controller'] as TextEditingController).text) ?? 0, 
                };
            }).toList();

            await PdfPurchaseRequestService.generateAndSavePdf(
                purchaseRequests: finalPurchaseRequests,
                lowStockItems: _lowStockItems, // Use the already fetched list
            );
            
            if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('✅ Purchase Request PDF saved successfully!')),
                 );
            }
        } catch (e) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Failed to save PDF: $e')),
                );
            }
        } finally {
            if (mounted) {
                setState(() {
                    _isLoading = false;
                });
            }
        }
    }

    Widget _buildHeaderWithAction(String title, {bool showPdfButton = true}) {
        final formattedDate = DateFormat('MMMM d, y').format(DateTime.now());
        return Card(
            color: _accentColor.withOpacity(0.1), 
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    title, // Uses the dynamic title
                                    style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                    ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'Report Date: $formattedDate',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54, 
                                        fontWeight: FontWeight.w500,
                                    ),
                                ),
                            ],
                        ),
                        
                        if (showPdfButton && _editablePurchaseRequests.isNotEmpty)
                            IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                tooltip: 'Generate PDF Report', 
                                onPressed: _isLoading ? null : _generateAndSavePdf,
                                style: IconButton.styleFrom(
                                    backgroundColor: _primaryColor, 
                                    padding: const EdgeInsets.all(12),
                                ),
                            )
                        else
                            const SizedBox.shrink(), 
                    ],
                ),
            ),
        );
    }

    Widget _buildPurchaseTable() {
        if (_editablePurchaseRequests.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text('No forecasted items available for purchase request.'),
                ),
            );
        }

        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(10),
                ),
                headingRowColor: MaterialStateProperty.all(_primaryColor.withOpacity(0.85)), 
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), 
                dataRowHeight: 60.0, 
                columnSpacing: 16.0, 
                columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Restock Amt (Edit)')), // Title updated for clarity
                    DataColumn(label: Text('Units/Item')), 
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Contact No.')),
                ],
                rows: _editablePurchaseRequests.map<DataRow>((item) {
                    final unitsPerItems = item['units_per_items'] ?? 1;
                    final controller = item['controller'] as TextEditingController;

                    return DataRow(
                        cells: [
                            DataCell(Text(item['no'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item['medicine_name'])),
                            DataCell(
                                SizedBox(
                                    width: 80, 
                                    child: TextFormField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center, 
                                        decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8.0),
                                                borderSide: const BorderSide(color: _accentColor),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8.0),
                                                borderSide: const BorderSide(color: _primaryColor, width: 2),
                                            ),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
                                        ),
                                        onChanged: (value) {
                                            // Update the map item directly on change
                                            item['restock_amount'] = int.tryParse(value) ?? 0;
                                        },
                                    ),
                                ),
                            ),
                            DataCell(Text(unitsPerItems.toString())),
                            DataCell(Text(item['supplier_name'])),
                            DataCell(Text(item['contact_num'])),
                        ]
                    );
                }).toList(),
            ),
        );
    }
    
    // NEW WIDGET: Read-only table for Low Stock Items
    Widget _buildLowStockTable() {
        if (_lowStockItems.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text('No items currently flagged as low stock.'),
                ),
            );
        }

        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(10),
                ),
                headingRowColor: MaterialStateProperty.all(_primaryColor.withOpacity(0.85)), 
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), 
                dataRowHeight: 50.0, 
                columnSpacing: 16.0, 
                columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Current Stock')), // Actual quantity in stock
                    DataColumn(label: Text('Suggested Amt')), // Suggested restock
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Contact No.')),
                ],
                rows: _lowStockItems.map<DataRow>((item) {
                    final currentStock = item['total_quantity'] ?? 0;
                    final suggestedRestock = item['restock_amount'] ?? 0;

                    return DataRow(
                        cells: [
                            DataCell(Text(item['no'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item['medicine_name'])),
                            DataCell(Text(currentStock.toString())),
                            DataCell(Text(suggestedRestock.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                            DataCell(Text(item['supplier_name'])),
                            DataCell(Text(item['contact_num'])),
                        ]
                    );
                }).toList(),
            ),
        );
    }


    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: const Text('Purchase Request'),
                backgroundColor: _primaryColor, 
                foregroundColor: Colors.white,
                actions: [
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh List',
                        onPressed: _isLoading ? null : _fetchPurchaseRequests,
                    ),
                ],
                // NEW: TabBar added to the bottom of the AppBar
                bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                        Tab(text: 'To Purchase Items', icon: Icon(Icons.shopping_cart)),
                        Tab(text: 'Low Stock Items', icon: Icon(Icons.warning_amber)),
                    ],
                ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    // NEW: TabBarView to switch between the two content views
                    : TabBarView(
                        controller: _tabController,
                        children: [
                            // === TAB 1: Forecasted (Editable) Items ===
                            SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        _buildHeaderWithAction('Items to Purchase', showPdfButton: true),
                                        const SizedBox(height: 10),
                                        _buildPurchaseTable(),
                                    ],
                                ),
                            ),

                            // === TAB 2: Low Stock (Read-Only) Report ===
                            SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        _buildHeaderWithAction('Low Stock Report', showPdfButton: true), // PDF button remains
                                        const SizedBox(height: 10),
                                        _buildLowStockTable(),
                                    ],
                                ),
                            ),
                        ],
                    ),
        );
    }
}