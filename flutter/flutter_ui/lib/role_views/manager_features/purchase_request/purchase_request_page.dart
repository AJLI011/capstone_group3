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

class _PurchaseRequestPageState extends State<PurchaseRequestPage> {
    List<Map<String, dynamic>> _editablePurchaseRequests = [];
    bool _isLoading = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        _fetchPurchaseRequests();
    }

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
            // Dispose existing controllers before clearing the list
            for (var item in _editablePurchaseRequests) {
                (item['controller'] as TextEditingController).dispose();
            }
            _editablePurchaseRequests = [];
        });
        
        const String apiUrl = 'http://10.0.0.2.2:8000/api/purchase-request/';
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
            final lowStockResponse = await http.get(Uri.parse('http://10.0.0.2.2:8000/api/medicines/low-stock/'));
            
            List<Map<String, dynamic>> lowStockRequests = [];
            
            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                
                lowStockRequests = fetchedLowStockData.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> item = entry.value as Map<String, dynamic>;
                    
                    return {
                        'no': _editablePurchaseRequests.length + index + 1, 
                        'medicine_name': item['name'] ?? 'Unknown Medicine',
                        'restock_amount': item['restock_quantity'] ?? 0,
                        'total_quantity': item['total_quantity'] ?? 0,
                        'units_per_items': 1,
                        'supplier_name': item['supplier_name'] ?? 'N/A', 
                        'contact_num': item['contact_num'] ?? 'N/A', 
                    };
                }).toList();
                
            } else {
                debugPrint('Warning: Failed to load low stock items. Status code: ${lowStockResponse.statusCode}');
            }

            final List<Map<String, dynamic>> finalPurchaseRequests = _editablePurchaseRequests.map((item) {
                return {
                    ...item,
                    'restock_amount': int.tryParse((item['controller'] as TextEditingController).text) ?? 0,
                };
            }).toList();

            await PdfPurchaseRequestService.generateAndSavePdf(
                purchaseRequests: finalPurchaseRequests,
                lowStockItems: lowStockRequests,
            );
            
            // if (mounted) {
            //      ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('✅ Purchase Request PDF saved successfully!')),
            //     );
            // }
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

    Widget _buildHeaderWithAction(String formattedDate) {
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
                                const Text(
                                    'Items to Purchase',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                    ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'Request Date: $formattedDate',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54, 
                                        fontWeight: FontWeight.w500,
                                    ),
                                ),
                            ],
                        ),
                        
                        if (_editablePurchaseRequests.isNotEmpty)
                            IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                tooltip: 'Generate PDF', 
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
                // --- FIX: Removed DataCheckbox in DataColumn, and related selection logic ---
                columns: const [
                    DataColumn(label: Text('No.')), // Now just 'No.'
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Restock Amt')), 
                    DataColumn(label: Text('Units/Item')), 
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Contact No.')),
                ],
                rows: _editablePurchaseRequests.map<DataRow>((item) {
                    final unitsPerItems = item['units_per_items'] ?? 1;
                    final controller = item['controller'] as TextEditingController;

                    return DataRow(
                        // Removed onSelectChanged as there's no checkbox for row selection
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

    @override
    Widget build(BuildContext context) {
        final formattedDate = DateFormat('MMMM d, y').format(DateTime.now());

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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    _buildHeaderWithAction(formattedDate),
                                    const SizedBox(height: 10),
                                    _buildPurchaseTable(),
                                ],
                            ),
                        ),
        );
    }
}