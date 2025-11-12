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
    // List to hold the full medicine catalog for the selection modal
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
        _fetchAllMedicines(); 
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
    
    // --- UPDATED HELPER FUNCTION: To find medicine details from the catalog ---
    Map<String, dynamic> _getMedicineDetailsById(dynamic id) {
        if (id == null) return {};
        try {
            // FIX: Ensure the ID is an integer for comparison against _allMedicines['id'], 
            // as JSON can sometimes cast integer IDs to strings.
            final int medicineId = id is int ? id : int.tryParse(id.toString()) ?? -1;

            // Find the matching medicine by its ID
            final medicine = _allMedicines.firstWhere((med) => med['id'] == medicineId); // Use the converted ID
            
            // Return a structured map of details
            return {
                'name': medicine['name'] ?? 'Unknown Medicine',
                'units': (medicine['restock_quantity'] ?? 1).toString(),
                'supplier': medicine['supplier_name'] ?? 'N/A',
                'contact': medicine['contact_num'] ?? 'N/A',
            };
        } catch (e) {
            // If ID is not found in the catalog, return empty
            return {};
        }
    }


    // --- FETCH LOGIC (UNCHANGED) ---
    
    Future<void> _fetchAllMedicines() async {
        const String apiUrl = 'http://10.0.2.2:8000/api/medicines/all/';
        try {
            final response = await http.get(Uri.parse(apiUrl));
            if (response.statusCode == 200) {
                List<dynamic> fetchedData = json.decode(response.body);
                setState(() {
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
        setState(() {
            _lowStockItems = [];
        });

        try {
            const String lowStockApiUrl = 'http://10.0.2.2:8000/api/medicines/low-stock/';
            final lowStockResponse = await http.get(Uri.parse(lowStockApiUrl));

            if (lowStockResponse.statusCode == 200) {
                List<dynamic> fetchedLowStockData = json.decode(lowStockResponse.body);
                
                List<Map<String, dynamic>> lowStockList = fetchedLowStockData.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> item = entry.value as Map<String, dynamic>;
                    
                    final int suggestedAmount = item['suggested_amount'] ?? 0;
                    
                    return {
                        'no': index + 1, 
                        'medicine_name': item['name'] ?? 'Unknown Medicine',
                        'medicine_id': item['medicine_id'], 
                        'restock_amount': suggestedAmount, 
                        'suggested_amount': suggestedAmount, 
                        'total_quantity': item['total_quantity'] ?? 0, 
                        'units_per_items': item['restock_quantity'].toString(), // Use restock_quantity from low stock API, convert to string
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
        for (var item in _editablePurchaseRequests) {
            (item['controller'] as TextEditingController).dispose();
        }
        _editablePurchaseRequests = [];
    });
    
    await _fetchLowStockItems();
    // Ensure the list of all medicines is loaded before processing PR items for fallback
    if (_allMedicines.isEmpty) {
        await _fetchAllMedicines();
    }

    const String apiUrl = 'http://10.0.2.2:8000/api/purchase-request/';
    try {
        final response = await http.get(Uri.parse(apiUrl)); 

        if (response.statusCode == 200) {
            List<dynamic> fetchedData = json.decode(response.body);
            setState(() {
                _editablePurchaseRequests = fetchedData.map((item) {
                    final int restockAmount = item['restock_amount'] ?? 0;
                    final int suggestedAmount = item['suggested_amount'] ?? restockAmount; 

                    final dynamic medicineId = item['medicine'] ?? item['id'] ?? item['medicine_id'];
                    final bool isNew = medicineId == null;

                    // FIX 1: Prioritize the 'medicine_name' field (This fixed the medicine name)
                    String medicineName = item['medicine_name'] ?? 'Unknown Medicine';
                    
                    // FIX 2: Prioritize the direct API fields for current data, falling back to snapshots/defaults.
                    String unitsPerItem = (item['units_per_items'] ?? item['units_per_item'] ?? 'N/A').toString(); 
                    String supplierName = item['supplier_name'] ?? item['supplier_name_snapshot'] ?? 'N/A';
                    String contactNum = item['contact_num'] ?? item['supplier_contact_num_snapshot'] ?? 'N/A';

                    
                    // Fallback and Catalog Lookup
                    if (!isNew) {
                        final catalogDetails = _getMedicineDetailsById(medicineId);
                        
                        // Use catalog name if the API name was still missing
                        if (medicineName == 'Unknown Medicine') {
                            medicineName = catalogDetails['name'] ?? 'Unknown Medicine';
                        }
                        
                        // Always try to get the most current units/supplier info from the catalog if available
                        // This ensures that unit/supplier changes are reflected immediately.
                        unitsPerItem = catalogDetails['units'] ?? unitsPerItem;
                        supplierName = catalogDetails['supplier'] ?? supplierName;
                        contactNum = catalogDetails['contact'] ?? contactNum;
                    }


                    return {
                        'no': item['no'],
                        'medicine_name': medicineName, 
                        'medicine_id': medicineId, 
                        'restock_amount': restockAmount,
                        'suggested_amount': suggestedAmount, 
                        'units_per_items': unitsPerItem, 
                        'supplier_name': supplierName, 
                        'contact_num': contactNum, 
                        'controller': TextEditingController(text: restockAmount.toString()),
                        'is_new': isNew,
                    };
                }).toList().cast<Map<String, dynamic>>();
                
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

    // --- NEW HELPER: Shows the Add Medicine Menu (Moved from old FAB) ---
    void _showAddMedicineMenu() {
        showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
                return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                        ListTile(
                            leading: const Icon(Icons.add_shopping_cart, color: _primaryColor),
                            title: const Text('Add Existing Item'),
                            onTap: () {
                                Navigator.pop(context); // Close the bottom sheet
                                _showAddMedicineDialog(); // Show existing medicine dialog
                            },
                        ),
                        ListTile(
                            leading: const Icon(Icons.note_add, color: _primaryColor),
                            title: const Text('Purchase New Medicine'),
                            onTap: () {
                                Navigator.pop(context); // Close the bottom sheet
                                _showAddNewMedicineDialog(); // Show new medicine dialog
                            },
                        ),
                        const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                        ),
                    ],
                );
            },
        );
    }

    // --- ITEM MANAGEMENT LOGIC (UNCHANGED) ---
    
    // Function to add a selected EXISTING item to the editable list
    void _addSelectedMedicine(Map<String, dynamic> medicine) {
        int maxNo = _editablePurchaseRequests.map((item) => item['no'] as int).fold(0, (max, current) => current > max ? current : max);
        int newNo = maxNo + 1;
        
        // Define a default restock amount (using the model's restock quantity as a suggestion)
        final defaultRestockAmount = medicine['restock_quantity'] ?? 1; 
        final unitsPerItem = medicine['restock_quantity'] ?? 1;


        final newItem = {
            'no': newNo,
            'medicine_name': medicine['name'],
            'medicine_id': medicine['id'], // Actual existing ID
            'restock_amount': defaultRestockAmount,
            'suggested_amount': 0, 
            'units_per_items': unitsPerItem.toString(), // Must be string for snapshot compatibility
            'supplier_name': medicine['supplier_name'] ?? 'N/A', 
            'contact_num': medicine['contact_num'] ?? 'N/A',
            'controller': TextEditingController(text: defaultRestockAmount.toString()),
            'is_new': false,
        };

        setState(() {
            _editablePurchaseRequests.add(newItem); 
            for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                _editablePurchaseRequests[i]['no'] = i + 1;
            }
        });
        
        if (_tabController.index == 1) {
             _tabController.animateTo(0);
        }
        
        Navigator.of(context).pop(); 
    }
    
    // NEW: Function to add a BRAND NEW/INTRODUCED item to the editable list
    void _addNewMedicine(
        String name,
        int restockAmount,
        String supplierName,
        String contactNum, // Only required fields from the UI
    ) {
        int maxNo = _editablePurchaseRequests.map((item) => item['no'] as int).fold(0, (max, current) => current > max ? current : max);
        int newNo = maxNo + 1;
        
        // CRITICAL: Use a temporary NEGATIVE ID for internal tracking/removal only
        int tempUniqueId = -1 - _editablePurchaseRequests.length; 

        final newItem = {
            'no': newNo,
            'medicine_name': name,
            'medicine_id': tempUniqueId, // Temporary ID for frontend management/removal
            'restock_amount': restockAmount,
            'suggested_amount': 0, 
            'units_per_items': 'N/A', // Set to N/A as per requirement
            'supplier_name': supplierName, 
            'contact_num': contactNum,
            'controller': TextEditingController(text: restockAmount.toString()),
            'is_new': true, // Mark it as new
        };

        setState(() {
            _editablePurchaseRequests.add(newItem); 
            for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                _editablePurchaseRequests[i]['no'] = i + 1;
            }
        });
        
        if (_tabController.index == 1) {
             _tabController.animateTo(0);
        }
        
        Navigator.of(context).pop(); 
    }

    // Function to remove an item from the editable list (UNCHANGED)
    void _removeItem(int index) {
        (_editablePurchaseRequests[index]['controller'] as TextEditingController).dispose();
        
        setState(() {
            _editablePurchaseRequests.removeAt(index);
            for (int i = 0; i < _editablePurchaseRequests.length; i++) {
                _editablePurchaseRequests[i]['no'] = i + 1;
            }
        });
    }

    // Existing: Build the selection modal/dialog for existing items (UNCHANGED)
    void _showAddMedicineDialog() {
        showDialog(
            context: context,
            builder: (BuildContext context) {
                final Set<dynamic> existingIds = _editablePurchaseRequests.map<dynamic>((item) => item['medicine_id']).toSet();
                final Set<dynamic> lowStockIds = _lowStockItems.map<dynamic>((item) => item['medicine_id']).toSet();
                
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
    
    // NEW: Build the Add New Medicine modal/dialog (MODIFIED FOR SUPPLIER DROPDOWN AND CONTACT AUTO-FILL)
    void _showAddNewMedicineDialog() {
        final _formKey = GlobalKey<FormState>();
        String _name = '';
        String _supplier = '';
        int _amount = 1;
        String _contact = ''; // State variable for contact number
        
        // New state for dropdown
        String? _selectedSupplier; 
        bool _isNewSupplier = false; // Flag to show or hide the contact field/new supplier text field

        // --- New Logic: Extract unique suppliers and their contacts ---
        // Map to store {Supplier Name: Contact Number}
        final Map<String, String> supplierContactMap = {}; 
        for (var med in _allMedicines) {
            final supplierName = med['supplier_name'] as String?;
            final contactNum = med['contact_num'] as String?;
            
            if (supplierName != null && supplierName.trim().isNotEmpty && supplierName != 'N/A') {
                // Store the first non-null or non-empty contact found for a unique supplier name
                if (!supplierContactMap.containsKey(supplierName.trim())) {
                    supplierContactMap[supplierName.trim()] = contactNum?.trim() ?? 'N/A';
                }
            }
        }
        
        final List<String> uniqueSupplierNames = supplierContactMap.keys.toList();
        final List<String> supplierOptions = ['Add New Supplier', ...uniqueSupplierNames];


        showDialog(
            context: context,
            builder: (BuildContext context) {
                // We need a StateSetter to update the dialog's local state (e.g., when the dropdown changes)
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                        return AlertDialog(
                            title: const Text('Purchase New Medicine'),
                            content: Form(
                                key: _formKey,
                                child: SingleChildScrollView(
                                    child: ListBody(
                                        children: <Widget>[
                                            TextFormField(
                                                decoration: const InputDecoration(labelText: 'Medicine Name *'),
                                                onChanged: (val) => _name = val,
                                                validator: (val) => val!.trim().isEmpty ? 'Name is required' : null,
                                            ),
                                            TextFormField(
                                                decoration: const InputDecoration(labelText: 'Restock Amount *'),
                                                keyboardType: TextInputType.number,
                                                initialValue: '1',
                                                onChanged: (val) => _amount = int.tryParse(val) ?? 1,
                                                validator: (val) => (int.tryParse(val!) ?? 0) < 1 ? 'Must be at least 1' : null,
                                            ),
                                            
                                            // --- Supplier Dropdown ---
                                            DropdownButtonFormField<String>(
                                                decoration: const InputDecoration(labelText: 'Supplier Name *'),
                                                value: _selectedSupplier,
                                                hint: const Text('Select or Add Supplier'),
                                                items: supplierOptions.map((String value) {
                                                    return DropdownMenuItem<String>(
                                                        value: value,
                                                        child: Text(value),
                                                    );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                    setState(() {
                                                        _selectedSupplier = newValue;
                                                        _isNewSupplier = newValue == 'Add New Supplier';
                                                        
                                                        if (!_isNewSupplier && newValue != null) {
                                                            _supplier = newValue;
                                                            // *** CRITICAL FIX: Look up and set contact ***
                                                            _contact = supplierContactMap[newValue] ?? 'N/A'; 
                                                        } else {
                                                            _supplier = ''; // Clear for new input
                                                            _contact = ''; // Clear contact for new input (will be editable)
                                                        }
                                                    });
                                                },
                                                validator: (val) {
                                                    if (val == null) {
                                                        return 'Supplier is required';
                                                    }
                                                    if (val == 'Add New Supplier' && _supplier.trim().isEmpty) {
                                                        return 'New Supplier Name is required';
                                                    }
                                                    return null;
                                                }
                                            ),

                                            // --- Conditional Input for New Supplier Name ---
                                            if (_isNewSupplier)
                                                TextFormField(
                                                    decoration: const InputDecoration(labelText: 'New Supplier Name *'),
                                                    onChanged: (val) => _supplier = val,
                                                ),

                                            // --- Conditional Input for Contact Number (Auto-filled or Editable) ---
                                            // Show if 'Add New Supplier' is selected OR an existing supplier is selected (to show the contact)
                                            if (_isNewSupplier || (_selectedSupplier != null && _selectedSupplier != 'Add New Supplier'))
                                                TextFormField(
                                                    // Key is added to force the widget to rebuild when _contact changes
                                                    key: ValueKey('contact_field_$_contact'), 
                                                    decoration: InputDecoration(
                                                        labelText: _isNewSupplier 
                                                            ? 'Supplier Contact Number' 
                                                            : 'Supplier Contact Number',
                                                        enabled: _isNewSupplier, // Disabled if existing supplier is chosen
                                                        suffixIcon: !_isNewSupplier ? const Icon(Icons.lock_outline, size: 18) : null,
                                                    ),
                                                    // Use the state variable _contact for the current value. If 'N/A' from lookup, display it.
                                                    initialValue: _isNewSupplier ? _contact : (_contact.isEmpty ? 'N/A' : _contact),
                                                    keyboardType: TextInputType.phone,
                                                    onChanged: (val) {
                                                        // Only allow modification if it is a new supplier
                                                        if (_isNewSupplier) {
                                                            _contact = val;
                                                        }
                                                    },
                                                ),
                                                
                                            const SizedBox(height: 10),
                                            const Text('Units/Item will be set to N/A for initial order.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                                        ],
                                    ),
                                ),
                            ),
                            actions: <Widget>[
                                TextButton(
                                    child: const Text('CANCEL'),
                                    onPressed: () => Navigator.of(context).pop(),
                                ),
                                ElevatedButton(
                                    child: const Text('ADD NEW'),
                                    onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                            // Ensure the correct supplier name is used based on selection
                                            final finalSupplierName = _isNewSupplier ? _supplier.trim() : _selectedSupplier!.trim();
                                            
                                            _addNewMedicine(
                                                _name.trim(), 
                                                _amount, 
                                                finalSupplierName, 
                                                // If contact is auto-filled as 'N/A', send an empty string instead of 'N/A'
                                                _contact.trim() == 'N/A' ? '' : _contact.trim()
                                            );
                                        }
                                    },
                                ),
                            ],
                        );
                    }
                );
            },
        );
    }

    // --- SUBMISSION LOGIC (UNCHANGED) ---
    
    // FUNCTION MODIFIED: Combines items from BOTH lists and formats the payload for NEW items
void _submitPurchaseRequest() async {
    // ... (rest of the initial setup code)
    
    final List<Map<String, dynamic>> allItemsForSubmission = [];

    // --- 1. CRITICAL FIX: Process Editable & Manually Added Items ---
    for (var item in _editablePurchaseRequests) {
        
        // 1. Get Restock Amount from the TextEditingController
        final int restockAmount = int.tryParse(
            (item['controller'] as TextEditingController).text
        ) ?? 0;
        
        // Only include items with a restock amount > 0
        if (restockAmount > 0) {
            
            // 2. Handle Medicine ID: Convert temporary negative ID (for new items) to null.
            // Temporary negative IDs (e.g., -1, -2) are used for frontend management only.
            final dynamic medicineId = item['medicine_id'] is int && item['medicine_id'] < 0
                ? null // Send NULL to Django for new/unlisted items
                : item['medicine_id']; // Send the actual ID for existing items

            allItemsForSubmission.add({
                'medicine': medicineId, // NULL or existing ID
                'restock_amount': restockAmount,
                'suggested_amount': item['suggested_amount'] ?? 0, 
                
                // 3. CORRECT SNAPSHOT MAPPING for Django Serializer
                'medicine_name_snapshot': item['medicine_name'], 
                'units_per_item': item['units_per_items'].toString(), // Ensures it's a string
                'supplier_name_snapshot': item['supplier_name'], 
                'supplier_contact_num_snapshot': item['contact_num'] ?? '', // Handles null contact gracefully
            });
        }
    }

    // --- 2. Process Low Stock Items (The existing code in your file) ---
    for (var item in _lowStockItems) { // This loop should follow the one above
        // ... (Your existing logic for low stock items)
        final int suggestedRestockAmount = item['restock_amount'] ?? 0;
        final dynamic lowStockMedicineKey = item['medicine_id'];
        
        if (suggestedRestockAmount > 0) {
            allItemsForSubmission.add({
                'medicine': lowStockMedicineKey,
                'restock_amount': suggestedRestockAmount,
                'suggested_amount': suggestedRestockAmount, 
                
                // Snapshot fields populated from the low-stock item data
                'medicine_name_snapshot': item['medicine_name'], 
                'units_per_item': item['units_per_items'].toString(),
                'supplier_name_snapshot': item['supplier_name'], 
                'supplier_contact_num_snapshot': item['contact_num'] ?? '',
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

        // 3. Prepare the final request body
        final Map<String, dynamic> requestBody = {
            'items': allItemsForSubmission,
        };
        
        // 4. Send Request
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
                        // Display the first validation error from the items list
                        final firstError = errorData['items'][0];
                        if (firstError != null) {
                            // Extract values from the first item error
                            final errorMessages = firstError.values.where((v) => v is List).expand((list) => list).join('; ');
                            message = 'Validation Error in item: $errorMessages';
                        }
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

    // --- WIDGETS (MODIFIED) ---
    
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
                    DataColumn(label: Text('Action')), 
                ],
                rows: _editablePurchaseRequests.asMap().entries.map<DataRow>((entry) { 
                    final index = entry.key;
                    final item = entry.value;
                    final controller = item['controller'] as TextEditingController;

                    // REMOVED: Green highlight logic to use default white/alternating background
                    // final isNew = item['is_new'] ?? false;
                    // final rowColor = isNew ? MaterialStateProperty.all(Colors.lightGreen.shade50) : null;


                    return DataRow(
                        color: null, // Always null (default white/alternating color)
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
                            DataCell( // <--- ACTION CELL
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
                    DataColumn(label: Text('Suggested Order')), 
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
                    // REPLACED REFRESH BUTTON WITH ADD MEDICINE MENU BUTTON
                    IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add Medicine',
                        onPressed: _isLoading ? null : _showAddMedicineMenu, 
                    ),
                ],
                // TabBar added to the bottom of the AppBar
                bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                        Tab(text: 'Forecasted/Added Items', icon: Icon(Icons.shopping_cart)), 
                        Tab(text: 'Low Stock Items', icon: Icon(Icons.warning_amber)),
                    ],
                ),
            ),
            
            // REMOVED Floating Action Button (FAB) since its function was moved to the AppBar action
            floatingActionButton: null, 
            
            body: Stack( 
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
                                            // Add extra space at the bottom for the fixed submit button
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
                                            // Add extra space at the bottom for the fixed submit button
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