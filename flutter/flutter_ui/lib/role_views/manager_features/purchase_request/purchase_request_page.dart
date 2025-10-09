// lib/role_views/manager_features/purchase_request_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_purchase_request_service.dart';

class PurchaseRequestPage extends StatefulWidget {
    const PurchaseRequestPage({super.key});

    @override
    State<PurchaseRequestPage> createState() => _PurchaseRequestPageState();
}

class _PurchaseRequestPageState extends State<PurchaseRequestPage> {
    // A new list to hold the data and their respective controllers for editing
    List<Map<String, dynamic>> _editablePurchaseRequests = [];
    bool _isLoading = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        _fetchPurchaseRequests();
    }

    // Remember to dispose of the controllers to prevent memory leaks
    @override
    void dispose() {
        for (var item in _editablePurchaseRequests) {
            (item['controller'] as TextEditingController).dispose();
        }
        super.dispose();
    }

    Future<void> _fetchPurchaseRequests() async {
        setState(() {
            _isLoading = true;
            _errorMessage = null;
            // Dispose of previous controllers before re-fetching
            for (var item in _editablePurchaseRequests) {
                (item['controller'] as TextEditingController).dispose();
            }
            _editablePurchaseRequests = [];
        });
        
        const String apiUrl = 'http://192.168.0.104:8000/api/purchase-request/';
        try {
            final response = await http.get(Uri.parse(apiUrl));

            if (response.statusCode == 200) {
                List<dynamic> fetchedData = json.decode(response.body);
                setState(() {
                    _editablePurchaseRequests = fetchedData.map((item) {
                        // Create a TextEditingController for each restock_amount
                        return {
                            'no': item['no'],
                            'medicine_name': item['medicine_name'],
                            'restock_amount': item['restock_amount'],
                            'units_per_items': item['units_per_items'],
                            'supplier_name': item['supplier_name'],
                            'contact_num': item['contact_num'],
                            'controller': TextEditingController(text: item['restock_amount'].toString()),
                        };
                    }).toList().cast<Map<String, dynamic>>(); // Corrected line
                    _isLoading = false;
                });
            } else if (response.statusCode == 404) {
                // Handle 404 specifically by not setting an error message
                // This will let the UI show the 'No items to purchase' message
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

    // ✅ FIX APPLIED HERE: Low stock items are now correctly mapped to the required keys.
    Future<void> _generateAndSavePdf() async {
        if (_editablePurchaseRequests.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No purchase requests to generate PDF.')),
            );
            return;
        }

        setState(() {
            _isLoading = true; // Show a loading indicator while fetching low stock data and generating PDF
        });

        try {
            // Step 1: Fetch the raw low stock data
            final lowStockResponse = await http.get(Uri.parse('http://192.168.0.104:8000/api/medicines/low-stock/'));
            
            // Initialize the list that holds the PROCESSED low stock requests
            List<Map<String, dynamic>> lowStockRequests = [];
            
            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                
                // CRITICAL FIX: Map the raw low stock data to align with the purchase request structure
                // This ensures 'medicine_name' and 'restock_amount' are correctly populated,
                // solving the 'n/a' and '0' issues.
                lowStockRequests = fetchedLowStockData.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> item = entry.value as Map<String, dynamic>;
                    
                    return {
                        // Assign sequential 'no' starting after the main purchase requests
                        'no': _editablePurchaseRequests.length + index + 1, 
                        'medicine_name': item['name'] ?? 'Unknown Medicine', // Maps 'name' to 'medicine_name'
                        'restock_amount': item['restock_quantity'] ?? 0, // Maps 'restock_quantity' to 'restock_amount'
                        'total_quantity': item['total_quantity'] ?? 0, // <--- ADDED: Maps the actual total quantity
                        'units_per_items': 1, // Defaulting to 1 as it's not provided by the low-stock endpoint
                        'supplier_name': item['supplier_name'] ?? 'N/A', 
                        'contact_num': item['contact_num'] ?? 'N/A', 
                    };
                }).toList();
                
            } else {
                // Handle case where low stock data fails to load, but don't stop the process
                print('Warning: Failed to load low stock items. Status code: ${lowStockResponse.statusCode}');
            }

            // Step 2: Prepare the purchase requests data from the controllers
            final List<Map<String, dynamic>> finalPurchaseRequests = _editablePurchaseRequests.map((item) {
                return {
                    ...item,
                    'restock_amount': int.tryParse((item['controller'] as TextEditingController).text) ?? 0,
                };
            }).toList();

            // Step 3: Pass both lists to the PDF service
            await PdfPurchaseRequestService.generateAndSavePdf(
                purchaseRequests: finalPurchaseRequests,
                lowStockItems: lowStockRequests, // Pass the MAPPED low stock data
            );

            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ PDF saved successfully to downloads.')),
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

    @override
    Widget build(BuildContext context) {
        final formattedDate = DateFormat('MMMM d, y').format(DateTime.now());

        return Scaffold(
            appBar: AppBar(
                title: const Text('Purchase Request'),
                backgroundColor: const Color(0xFF5C7C9A),
                foregroundColor: Colors.white,
                actions: [
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchPurchaseRequests,
                    ),
                ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _editablePurchaseRequests.isEmpty
                        ? const Center(child: Text('No items to purchase.', style: TextStyle(fontSize: 16)))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Center(
                                        child: Column(
                                            children: [
                                                const Text(
                                                    'Items to Purchase',
                                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                    formattedDate,
                                                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                                                ),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(height: 20),
                                    SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                            columnSpacing: 24.0,
                                            dataRowHeight: 60.0,
                                            columns: const [
                                                DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Restock Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Units per Items', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Contact No.', style: TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                            rows: _editablePurchaseRequests.map<DataRow>((item) {
                                                final unitsPerItems = item['units_per_items'] ?? 1;
                                                final controller = item['controller'] as TextEditingController;

                                                return DataRow(cells: [
                                                    DataCell(Text(item['no'].toString())),
                                                    DataCell(Text(item['medicine_name'])),
                                                    DataCell(
                                                        SizedBox(
                                                            width: 100, // Provides a fixed width for the text field
                                                            child: TextFormField(
                                                                controller: controller,
                                                                keyboardType: TextInputType.number,
                                                                decoration: const InputDecoration(
                                                                    border: OutlineInputBorder(),
                                                                    isDense: true,
                                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                                ),
                                                                onChanged: (value) {
                                                                    // Update the value in the data list as well, just in case
                                                                    item['restock_amount'] = int.tryParse(value) ?? 0;
                                                                },
                                                            ),
                                                        ),
                                                    ),
                                                    DataCell(Text(unitsPerItems.toString())),
                                                    DataCell(Text(item['supplier_name'])),
                                                    DataCell(Text(item['contact_num'])),
                                                ]);
                                            }).toList(),
                                        ),
                                    ),
                                ],
                            ),
                        ),
            floatingActionButton: _editablePurchaseRequests.isNotEmpty && !_isLoading
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