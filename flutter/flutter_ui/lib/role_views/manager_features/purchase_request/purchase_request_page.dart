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
    // NEW: List to hold the full medicine catalog for the selection modal
    List<Map<String, dynamic>> _allMedicines = []; 
    
    // Tab Controller is back
    late TabController _tabController; 
    
    bool _isLoading = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        // Initialize TabController for two tabs
        _tabController = TabController(length: 2, vsync: this);
        // Fetch both lists and the medicine catalog
        _fetchPurchaseRequests(); 
        _fetchAllMedicines(); // <--- NEW: Fetch all medicines
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

    // --- FETCH LOGIC ---
    
    // NEW: Fetch all medicines for the selection modal
    Future<void> _fetchAllMedicines() async {
        const String apiUrl = 'http://192.168.1.21:8000/api/medicines/all/';
        try {
            final response = await http.get(Uri.parse(apiUrl));
            if (response.statusCode == 200) {
                List<dynamic> fetchedData = json.decode(response.body);
                setState(() {
                    // Assuming the serializer returns fields like id, name, restock_quantity, supplier_name, contact_num
                    _allMedicines = fetchedData.map((item) => item as Map<String, dynamic>).toList();
                });
            } else {
                debugPrint('Warning: Failed to load all medicines. Status code: ${response.statusCode}');
            }
        } catch (e) {
            debugPrint('Error fetching all medicines: $e');
        }
    }
    
    Future<void> _fetchLowStockItems() async {
        // Clear list on fetch start
        setState(() {
            _lowStockItems = [];
        });

        try {
            const String lowStockApiUrl = 'http://192.168.1.21:8000/api/medicines/low-stock/';
            final lowStockResponse = await http.get(Uri.parse(lowStockApiUrl));

            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                
                // Map low stock data into a consistent format for submission payload
                List<Map<String, dynamic>> lowStockList = fetchedLowStockData.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> item = entry.value as Map<String, dynamic>;
                    
                    final int suggestedAmount = item['suggested_amount'] ?? 0;
                    
                    return {
                        'no': index + 1, 
                        'medicine_name': item['name'] ?? 'Unknown Medicine',
                        'medicine_id': item['medicine_id'], // CRITICAL FIX: Use 'medicine_id' from the serializer
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
        const String apiUrl = 'http://192.168.1.21:8000/api/purchase-request/';
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
                    
                    // Re-index the 'no' field for remaining items (important if new items are added to top later)
                    for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                        _editablePurchaseRequests[i]['no'] = i + 1;
                    }

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

    // --- ITEM MANAGEMENT LOGIC ---
    
    // NEW: Function to add a selected item to the editable list
    void _addSelectedMedicine(Map<String, dynamic> medicine) {
        // Find the next available 'no' (rank)
        // Add one to the max 'no' value, or start at 1 if list is empty
        int maxNo = _editablePurchaseRequests.map((item) => item['no'] as int).fold(0, (max, current) => current > max ? current : max);
        int newNo = maxNo + 1;
        
        // Define a default restock amount (using the model's restock quantity as a suggestion)
        final defaultRestockAmount = medicine['restock_quantity'] ?? 1; 

        final newItem = {
            'no': newNo,
            'medicine_name': medicine['name'],
            'medicine_id': medicine['id'], // Use 'id' from MedicineSelectionSerializer
            'restock_amount': defaultRestockAmount,
            'suggested_amount': 0, // Manually added items have no system suggestion
            'units_per_items': medicine['restock_quantity'], // Assumed unit from medicine model
            'supplier_name': medicine['supplier_name'] ?? 'N/A', 
            'contact_num': medicine['contact_num'] ?? 'N/A',
            'controller': TextEditingController(text: defaultRestockAmount.toString()),
        };

        setState(() {
            _editablePurchaseRequests.insert(0, newItem); // Add to the top
            // Re-index all items after insertion
            for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                _editablePurchaseRequests[i]['no'] = i + 1;
            }
        });
        
        // Switch to the Forecasted/Editable tab if currently on Low Stock tab
        if (_tabController.index == 1) {
             _tabController.animateTo(0);
        }
        
        // Close the dialog
        Navigator.of(context).pop(); 
    }
    
    // NEW: Function to remove an item from the editable list
    void _removeItem(int index) {
        // Dispose of the controller first
        (_editablePurchaseRequests[index]['controller'] as TextEditingController).dispose();
        
        setState(() {
            _editablePurchaseRequests.removeAt(index);
            // Re-index the 'no' field for remaining items
            for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                _editablePurchaseRequests[i]['no'] = i + 1;
            }
        });
    }

    // NEW: Build the selection modal/dialog
    void _showAddMedicineDialog() {
        showDialog(
            context: context,
            builder: (BuildContext context) {
                // Filter the list to exclude medicines already in _editablePurchaseRequests
                final Set<int> existingIds = _editablePurchaseRequests.map<int>((item) => item['medicine_id'] as int).toSet();
                // Also exclude items present in the low stock list (to prevent duplication on submission)
                final Set<int> lowStockIds = _lowStockItems.map<int>((item) => item['medicine_id'] as int).toSet();
                
                final List<Map<String, dynamic>> filteredMedicines = _allMedicines.where(
                    (med) => !existingIds.contains(med['id']) && !lowStockIds.contains(med['id'])
                ).toList();
                
                return AlertDialog(
                    title: const Text('Add Existing Medicine'),
                    content: SizedBox(
                        width: double.maxFinite,
                        child: filteredMedicines.isEmpty
                            ? const Center(child: Text('All relevant medicines are already in a request list.'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredMedicines.length,
                                itemBuilder: (context, index) {
                                    final medicine = filteredMedicines[index];
                                    return ListTile(
                                        title: Text(medicine['name'] ?? 'No Name'),
                                        subtitle: Text('Unit: ${medicine['restock_quantity'] ?? 'N/A'} | Supplier: ${medicine['supplier_name'] ?? 'N/A'}'),
                                        trailing: const Icon(Icons.add_circle, color: _primaryColor),
                                        onTap: () => _addSelectedMedicine(medicine),
                                    );
                                },
                            ),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('CANCEL'),
                        ),
                    ],
                );
            },
        );
    }

    // --- SUBMISSION LOGIC ---
    
    // FUNCTION MODIFIED: Combines items from BOTH lists before submission
    Future<void> _submitPurchaseRequest() async {
        // 1. Combine items from both tabs into a single list
        final List<Map<String, dynamic>> allItemsForSubmission = [];

        // --- A. Add Forecasted/Manually Added Items (Editable List) ---
        // Use the manager's edited restock amount from the TextEditingController
        for (var item in _editablePurchaseRequests) {
            final restockAmountText = (item['controller'] as TextEditingController).text;
            final int restockAmount = int.tryParse(restockAmountText) ?? 0;
            
            if (restockAmount > 0) {
                allItemsForSubmission.add({
                    'medicine': item['medicine_id'],// Medicine PK
                    'restock_amount': restockAmount,// Manager's edited amount
                    'suggested_amount': item['suggested_amount'], // System's suggestion (0 for manually added)
                });
            }
        }

        // --- B. Add Low Stock Items (Read-Only List) ---
        final Set<int> submittedMedicineIds = allItemsForSubmission.map<int>((item) => item['medicine'] as int).toSet();
        
        for (var item in _lowStockItems) {
            final int suggestedRestockAmount = item['restock_amount'] ?? 0; // This is the system's order suggestion

            if (suggestedRestockAmount > 0 && !submittedMedicineIds.contains(item['medicine_id'])) {
                allItemsForSubmission.add({
                    'medicine': item['medicine_id'], // Medicine PK
                    'restock_amount': suggestedRestockAmount,// Use suggested amount as the final restock amount
                    'suggested_amount': suggestedRestockAmount, // CRITICAL FIX: Ensure suggested_amount is explicitly set
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
            const String apiUrl = 'http://192.168.1.21:8000/api/purchase-request/';
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
                        message = 'Submission failed due to item validation error. Check amounts.';
                        debugPrint('Item validation error: ${errorData['items']}');
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

    // --- WIDGETS ---
    
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
                    child: Text('No forecasted or manually added items available for purchase request.'),
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
                    DataColumn(label: Text('Restock Amt (Edit)')),
                    DataColumn(label: Text('Units/Item')), 
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Contact No.')),
                    DataColumn(label: Text('Action')), // <--- NEW COLUMN
                ],
                rows: _editablePurchaseRequests.asMap().entries.map<DataRow>((entry) { // <--- USE ASMAP().ENTRIES
                    final index = entry.key;
                    final item = entry.value;
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
                            DataCell( // <--- NEW ACTION CELL
                                IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                ),
                            ),
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
                        Tab(text: 'Forecasted/Added Items', icon: Icon(Icons.shopping_cart)), // Updated Tab Label
                        Tab(text: 'Low Stock Items', icon: Icon(Icons.warning_amber)),
                    ],
                ),
            ),
            
            // NEW: Floating Action Button for adding new items
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _isLoading ? null : _showAddMedicineDialog,
                label: const Text('Add Existing Item'),
                icon: const Icon(Icons.add_shopping_cart),
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                elevation: 8,
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
                                            _buildHeaderWithAction('Purchase Request Items', showPdfButton: true),
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

                // Floating Submit Button (Positioned inside Stack)
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