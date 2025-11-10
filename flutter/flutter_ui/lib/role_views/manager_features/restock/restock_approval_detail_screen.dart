// lib/restock_approval_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 

// Define the common primary color and date formatter
const Color _primaryColor = Color(0xFF5C7C9A); 
final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

class RestockItem {
  final int medicineId; 
  final String medicineName;
  final String genericName;
  final String supplierName;
  int restockQuantity; 
  
  // *** NEW FIELDS for Batch Number ***
  String batchNumber;
  TextEditingController batchController;
  // **********************************

  TextEditingController quantityController;
  DateTime? manufactureDate; 
  DateTime? expiryDate; 
    
  RestockItem({
    required this.medicineId,
    required this.medicineName,
    required this.genericName,
    required this.supplierName,
    required this.restockQuantity,
    this.manufactureDate,
    this.expiryDate,
    // Initialize new fields
    this.batchNumber = '', // Default to empty string
  }) : quantityController = TextEditingController(text: restockQuantity.toString()),
       batchController = TextEditingController(text: ''); // Start with empty text field

  factory RestockItem.fromJson(Map<String, dynamic> json) {
    int quantity = json['restock_quantity'] ?? 0;
    return RestockItem(
      // Ensure the key 'medicine_id' matches the backend serializer output
      medicineId: json['medicine_id'] ?? 0, 
      medicineName: json['medicine_name'] ?? 'N/A',
      genericName: json['generic_name'] ?? 'N/A',
      supplierName: json['supplier_name'] ?? 'N/A',
      restockQuantity: quantity,
    );
  }
}

class RestockApprovalDetailScreen extends StatefulWidget {
  final int prId;

  const RestockApprovalDetailScreen({super.key, required this.prId});

  @override
  State<RestockApprovalDetailScreen> createState() => _RestockApprovalDetailScreenState();
}

class _RestockApprovalDetailScreenState extends State<RestockApprovalDetailScreen> {
  List<RestockItem> _restockItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _prManagerName = 'N/A';
  DateTime? _prRequestDate;

  @override
  void initState() {
    super.initState();
    _fetchPrDetails();
  }
  
  @override
  void dispose() {
    for (var item in _restockItems) {
      item.quantityController.dispose();
      item.batchController.dispose(); // Dispose the new controller
    }
    super.dispose();
  }

  // --- API FETCH LOGIC ---
  Future<void> _fetchPrDetails() async {
    final String apiUrl = 'http://192.168.1.8:8000/api/restock/purchase-request/${widget.prId}/';
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _prManagerName = data['manager_name'] ?? 'N/A';
        _prRequestDate = DateTime.tryParse(data['request_date'] ?? '');
        
        List<dynamic> itemsData = data['items'] ?? [];
        
        setState(() {
          _restockItems = itemsData.map((json) => RestockItem.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load PR details. Status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network Error: $e';
        _isLoading = false;
      });
    }
  }

  // --- QUANTITY MANAGEMENT LOGIC ---
  void _updateQuantity(RestockItem item, int change) {
    setState(() {
      int newQuantity = item.restockQuantity + change;
      if (newQuantity < 0) newQuantity = 0;
      
      item.restockQuantity = newQuantity;
      item.quantityController.text = newQuantity.toString();
    });
  }

  // --- DATE PICKER LOGIC ---
  Future<void> _selectDate(BuildContext context, RestockItem item, bool isExpiry) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: _primaryColor, 
                onPrimary: Colors.white, 
                onSurface: Colors.black, 
              ),
            ),
            child: child!,
          );
        },
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          item.expiryDate = picked;
        } else {
          item.manufactureDate = picked;
        }
      });
    }
  }

  // --- SUBMIT APPROVAL (UPDATED API CALL with Batch Number) ---
  void _submitApproval() async {
    // 1. Basic Validation
    bool validationFailed = false;
    for (var item in _restockItems) {
      // ** NEW VALIDATION: Check Batch Number **
      if (item.batchController.text.trim().isEmpty) { 
          validationFailed = true;
          break;
      }
      if (item.restockQuantity <= 0) {
          validationFailed = true;
          break;
      }
      if (item.manufactureDate == null || item.expiryDate == null) {
          validationFailed = true;
          break;
      }
    }
    
    if (validationFailed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // UPDATED ERROR MESSAGE
        const SnackBar(content: Text('Please set a valid quantity (> 0), both Manufacture/Expiry Dates, AND a Batch Number for all items.')),
      );
      return;
    }

    // 2. Prepare Payload
    final List<Map<String, dynamic>> itemsPayload = _restockItems.map((item) => {
      'medicine_id': item.medicineId,
      'approved_quantity': item.restockQuantity,
      // ** NEW FIELD IN PAYLOAD **
      'batch_num': item.batchController.text.trim(), 
      'manufacture_date': _dateFormat.format(item.manufactureDate!),
      'expiry_date': _dateFormat.format(item.expiryDate!), 
    }).toList();
    
    final approvedPayload = {
      'items': itemsPayload,
    };
    
    // 3. API Call
    // NOTE: We assume the backend uses the 'approve/' suffix for processing the order
    final String apiUrl = 'http://192.168.1.8:8000/api/restock/purchase-request/${widget.prId}/approve/'; 
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(approvedPayload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PR Approved! New batches created in Inventory.')),
        );
        Navigator.of(context).pop(true); // Pop with true success signal
      } else {
        final errorData = json.decode(response.body);
        String message = errorData['detail'] ?? errorData.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $message', style: const TextStyle(color: Colors.red))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network Error during approval: $e', style: const TextStyle(color: Colors.red))),
      );
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- WIDGET BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Approve PR-${widget.prId}'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // PR Header Info
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: _primaryColor.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Manager: $_prManagerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Date: ${_prRequestDate != null ? _prRequestDate!.toLocal().toString().split(' ')[0] : 'N/A'}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _restockItems.length,
                        itemBuilder: (context, index) {
                          final item = _restockItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Medicine Name & Generic Name
                                  Text(item.medicineName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                                  Text('Generic: ${item.genericName}', style: const TextStyle(color: Colors.black87)),
                                  Text('Supplier: ${item.supplierName}', style: const TextStyle(color: Colors.black54)),
                                  const Divider(),
                                  
                                  // Restock Quantity Management 
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded( 
                                        child: Text('Approved Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(), 
                                            icon: const Icon(Icons.remove, color: Colors.red),
                                            onPressed: _isLoading ? null : () => _updateQuantity(item, -1),
                                          ),
                                          SizedBox(
                                            width: 50, // Fixed width to prevent overflow
                                            child: TextFormField(
                                              controller: item.quantityController, 
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              readOnly: _isLoading,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
                                              ),
                                              onChanged: (value) {
                                                final newQty = int.tryParse(value) ?? 0;
                                                item.restockQuantity = newQty; 
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(), 
                                            icon: const Icon(Icons.add, color: Colors.green),
                                            onPressed: _isLoading ? null : () => _updateQuantity(item, 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // ** NEW: BATCH NUMBER INPUT **
                                  TextFormField(
                                    controller: item.batchController, 
                                    decoration: InputDecoration(
                                      labelText: 'Batch Number',
                                      hintText: 'Enter batch number (required)',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      suffixIcon: item.batchController.text.isEmpty && !_isLoading 
                                          ? const Icon(Icons.warning, color: Colors.red, size: 20)
                                          : null,
                                    ),
                                    readOnly: _isLoading,
                                    // The controller handles the state, no need for onChanged to update the model property explicitly
                                  ),
                                  // **********************************

                                  const SizedBox(height: 10),
                                  // --- DATE PICKER WIDGETS ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Manufacture Date Picker
                                      _buildDateButton(
                                        context, 
                                        'Manuf. Date:', 
                                        item.manufactureDate, 
                                        () => _selectDate(context, item, false)
                                      ),
                                      // Expiry Date Picker
                                      _buildDateButton(
                                        context, 
                                        'Expiry Date:', 
                                        item.expiryDate, 
                                        () => _selectDate(context, item, true)
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Approval Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitApproval,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('APPROVE & PROCESS ORDER', style: TextStyle(fontSize: 18)),
                      ),
                    )
                  ],
                ),
    );
  }
  
  // Helper Widget for Date Picker Buttons
  Widget _buildDateButton(BuildContext context, String label, DateTime? date, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : onPressed,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                date == null ? 'Select Date' : _dateFormat.format(date),
                style: TextStyle(fontSize: 14, color: date == null ? Colors.black54 : _primaryColor),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: BorderSide(color: _primaryColor.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}