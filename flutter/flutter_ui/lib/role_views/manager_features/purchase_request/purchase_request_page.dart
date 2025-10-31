// lib/role_views/manager_features/purchase_request_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_ui/services/pdf_purchase_request_service.dart';

// Define a common color palette for better consistency
const Color _primaryColor = Color(0xFF5C7C9A); // Dark Blue
const Color _accentColor = Color(0xFF5C7C9A); // Mid Blue
const Color _lowStockColor = Color(0xFFF0AD4E); // Warning Yellow/Orange

class PurchaseRequestPage extends StatefulWidget {
    const PurchaseRequestPage({super.key});

    @override
    State<PurchaseRequestPage> createState() => _PurchaseRequestPageState();
}

class _PurchaseRequestPageState extends State<PurchaseRequestPage> with SingleTickerProviderStateMixin {
    // Forecasted items (Editable tab)
    List<Map<String, dynamic>> _editablePurchaseRequests = [];
    // Low Stock items (Read-Only tab, needs to be included in submission)
    List<Map<String, dynamic>> _lowStockItems = []; 
    
    // Tab Controller is back
    late TabController _tabController; 
    
    bool _isLoading = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        // Initialize TabController for two tabs
        _tabController = TabController(length: 2, vsync: this);
        // Fetch both lists
        _fetchPurchaseRequests(); 
    }

    @override
    void dispose() {
        _tabController.dispose();
        // Dispose existing controllers before clearing the list
        for (var item in _editablePurchaseRequests) {
            (item['controller'] as TextEditingController).dispose();
        }
        super.dispose();
    }

    // Restore the separate fetch for Low Stock items
    Future<void> _fetchLowStockItems() async {
        // Clear list on fetch start
        setState(() {
            _lowStockItems = [];
        });

        try {
            // NOTE: Assuming your /api/medicines/low-stock/ returns the medicine ID and restock_quantity (suggested amount)
            const String lowStockApiUrl = 'http://10.0.2.2:8000/api/medicines/low-stock/';
            final lowStockResponse = await http.get(Uri.parse(lowStockApiUrl));

            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                
                // Map low stock data into a consistent format for submission payload
                List<Map<String, dynamic>> lowStockList = fetchedLowStockData.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> item = entry.value as Map<String, dynamic>;
                    
                    // --- CRITICAL FIX: Use the new field name from the backend serializer ---
                    final int suggestedAmount = item['suggested_amount'] ?? 0;
                    // ----------------------------------------------------------------------
                    
                    return {
                        'no': index + 1, 
                        'medicine_name': item['name'] ?? 'Unknown Medicine',
                        'medicine_id': item['medicine_id'], // <--- CRITICAL FIX: Use 'medicine_id' from the serializer
                        'restock_amount': suggestedAmount, // The suggested amount from low stock (used for display and as final restock amount)
                        'suggested_amount': suggestedAmount, // Required for submission payload
                        'total_quantity': item['total_quantity'] ?? 0, 
                        'units_per_items': 1, // Placeholder
                        'supplier_name': item['supplier_name'] ?? 'N/A', 
                        'contact_num': item['contact_num'] ?? 'N/A', 
                    };
                }).toList();

                setState(() {
                    _lowStockItems = lowStockList;
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
        
        // Fetch Forecasted items from the dedicated endpoint
        const String apiUrl = 'http://10.0.2.2:8000/api/purchase-request/';
        try {
            final response = await http.get(Uri.parse(apiUrl)); 

            if (response.statusCode == 200) {
                List<dynamic> fetchedData = json.decode(response.body);
                setState(() {
                    _editablePurchaseRequests = fetchedData.map((item) {
                        final int restockAmount = item['restock_amount'] ?? 0;
                        final int suggestedAmount = item['suggested_amount'] ?? restockAmount; 

                        return {
                            'no': item['no'],
                            'medicine_name': item['medicine_name'],
                            'medicine_id': item['medicine_id'], 
                            'restock_amount': restockAmount,
                            'suggested_amount': suggestedAmount, 
                            'units_per_items': item['units_per_items'],
                            'supplier_name': item['supplier_name'],
                            'contact_num': item['contact_num'],
                            'controller': TextEditingController(text: restockAmount.toString()),
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

    // FUNCTION MODIFIED: Combines items from BOTH lists before submission
    Future<void> _submitPurchaseRequest() async {
        // 1. Combine items from both tabs into a single list
        final List<Map<String, dynamic>> allItemsForSubmission = [];

        // --- A. Add Forecasted Items (Editable List) ---
        // Use the manager's edited restock amount from the TextEditingController
        for (var item in _editablePurchaseRequests) {
            final restockAmountText = (item['controller'] as TextEditingController).text;
            final int restockAmount = int.tryParse(restockAmountText) ?? 0;
            
            if (restockAmount > 0) {
                allItemsForSubmission.add({
                    'medicine': item['medicine_id'],// Medicine PK
                    'restock_amount': restockAmount,// Manager's edited amount
                    'suggested_amount': item['suggested_amount'], // System's suggestion
                });
            }
        }

        // --- B. Add Low Stock Items (Read-Only List) ---
        // Use the system's suggested amount (restock_amount) from the low stock list as the final order amount
        // Ensure no duplicates by checking medicine ID (optional optimization)
        final Set<int> submittedMedicineIds = allItemsForSubmission.map<int>((item) => item['medicine'] as int).toSet();
        
        for (var item in _lowStockItems) {
            final int suggestedRestockAmount = item['restock_amount'] ?? 0; // This is the system's order suggestion

            if (suggestedRestockAmount > 0 && !submittedMedicineIds.contains(item['medicine_id'])) {
                allItemsForSubmission.add({
                    'medicine': item['medicine_id'], // Medicine PK
                    'restock_amount': suggestedRestockAmount,// Use suggested amount as the final restock amount
                    'suggested_amount': suggestedRestockAmount, // <--- CRITICAL FIX: Ensure suggested_amount is explicitly set
                });
            }
        }


        if (allItemsForSubmission.isEmpty) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No items to submit. Please set a restock amount greater than zero.')),
                );
                return;
            }
        }
        
        setState(() { _isLoading = true; });

        // 2. Prepare the final request body (wrapper)
        final Map<String, dynamic> requestBody = {
            'items': allItemsForSubmission,
        };

        // --- 3. Send Request (REST OF SUBMISSION LOGIC REMAINS THE SAME) ---
        try {
            const String apiUrl = 'http://10.0.2.2:8000/api/purchase-request/';
            final response = await http.post(
                Uri.parse(apiUrl),
                headers: <String, String>{
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: jsonEncode(requestBody),
            );

            if (mounted) {
                if (response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Purchase Request submitted successfully!')),
                    );
                    await _fetchPurchaseRequests(); 
                } else {
                    final errorData = jsonDecode(response.body);
                    String message = 'Submission failed. Status: ${response.statusCode}';
                    if (errorData is Map && errorData.containsKey('detail')) {
                        message = 'Submission failed: ${errorData['detail']}';
                    } else if (errorData is Map && errorData.containsKey('items')) {
                        message = 'Submission failed due to item validation error.';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ $message')),
                    );
                }
            }
        } catch (e) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Network Error: $e')),
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


    Future<void> _generateAndSavePdf() async {
        // Logic remains the same (uses _editablePurchaseRequests and _lowStockItems)
        // ... (PDF Generation logic omitted for brevity) ...
        
        // Use combined data for PDF generation if needed
        final List<Map<String, dynamic>> finalPurchaseRequests = _editablePurchaseRequests.map((item) {
             return {
                 ...item,
                 'restock_amount': int.tryParse((item['controller'] as TextEditingController).text) ?? 0, 
             };
        }).toList();

        try {
            await PdfPurchaseRequestService.generateAndSavePdf(
                purchaseRequests: finalPurchaseRequests,
                lowStockItems: _lowStockItems, 
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

    // Widget helpers remain the same
    Widget _buildHeaderWithAction(String title, {bool showPdfButton = true}) {
        // ... (Header logic omitted for brevity) ...
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
                                    title, 
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
                        
                        if (showPdfButton && (_editablePurchaseRequests.isNotEmpty || _lowStockItems.isNotEmpty))
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

    // WIDGET: Purchase Items Table (Editable)
    Widget _buildPurchaseTable() {
        if (_editablePurchaseRequests.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text('No forecasted items available for purchase request.'),
                ),
            );
        }

        // NOTE: Submit button removed from here to place it as a floating button
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
                    // DataColumn(label: Text('Suggested Amt')), // <-- REMOVED THIS COLUMN
                    DataColumn(label: Text('Restock Amt (Edit)')),
                    DataColumn(label: Text('Units/Item')), 
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Contact No.')),
                ],
                rows: _editablePurchaseRequests.map<DataRow>((item) {
                    final controller = item['controller'] as TextEditingController;

                    return DataRow(
                        cells: [
                            DataCell(Text(item['no'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item['medicine_name'])),
                            // DataCell(Text(item['suggested_amount'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, color: _primaryColor))), // <-- REMOVED THIS CELL
                            DataCell(
                                SizedBox(
                                    width: 80, 
                                    child: TextFormField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center, 
                                        decoration: InputDecoration(
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
                                        ),
                                        onChanged: (value) {
                                            item['restock_amount'] = int.tryParse(value) ?? 0;
                                        },
                                    ),
                                ),
                            ),
                            DataCell(Text(item['units_per_items'].toString())),
                            DataCell(Text(item['supplier_name'])),
                            DataCell(Text(item['contact_num'])),
                        ]
                    );
                }).toList(),
            ),
        );
    }
    
    // WIDGET: Low Stock Table (Read-Only)
    Widget _buildLowStockTable() {
        // Displays items that will be automatically added to the submission payload
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
                    DataColumn(label: Text('Current Stock')), 
                    DataColumn(label: Text('Suggested Order')), // This amount will be submitted
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
                            DataCell(Text(suggestedRestock.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: _lowStockColor))),
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
        // Total count of items that will be submitted
        final int totalItemsToSubmit = _editablePurchaseRequests.length + _lowStockItems.length;

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
                // TabBar added to the bottom of the AppBar
                bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                        Tab(text: 'Forecasted Items', icon: Icon(Icons.shopping_cart)),
                        Tab(text: 'Low Stock Items', icon: Icon(Icons.warning_amber)),
                    ],
                ),
            ),
            body: Stack( // Use Stack to allow the Floating button positioning
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                        // TabBarView to switch between the two content views
                        : TabBarView(
                            controller: _tabController,
                            children: [
                                // === TAB 1: Forecasted (Editable) Items ===
                                SingleChildScrollView(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                            _buildHeaderWithAction('Editable Purchase Items', showPdfButton: true),
                                            const SizedBox(height: 10),
                                            _buildPurchaseTable(), 
                                            // Add extra space at the bottom for the floating button
                                            const SizedBox(height: 100), 
                                        ],
                                    ),
                                ),

                                // === TAB 2: Low Stock (Read-Only) Report ===
                                SingleChildScrollView(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                            _buildHeaderWithAction('Low Stock Items', showPdfButton: false), 
                                            const SizedBox(height: 10),
                                            _buildLowStockTable(),
                                            // Add extra space at the bottom for the floating button
                                            const SizedBox(height: 100),
                                        ],
                                    ),
                                ),
                            ],
                        ),

                // NEW: Floating Submit Button (Single Button)
                if (!_isLoading && _errorMessage == null)
                    Positioned(
                        bottom: 16.0,
                        left: 16.0,
                        right: 16.0,
                        child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitPurchaseRequest,
                            icon: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send),
                            label: Text(
                                _isLoading 
                                    ? 'SUBMITTING...' 
                                    : 'SUBMIT ALL REQUESTS ($totalItemsToSubmit ITEMS)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size(double.infinity, 50), // Full width button
                                elevation: 8, // Give it a shadow to make it float
                            ),
                        ),
                    ),
              ],
            ),
        );
    }
}