import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// Import BatchDetail for consistency (This is correct)
import 'inventory_detail_screen.dart'; 

// MODIFIED: API_BASE now only contains host:port without any protocol (http/https).
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: '10.0.2.2:8000/', 
);


// ===================== SERVICE: API Calls (Deduction only) =====================
// Defining the service function required by this screen
class InventoryApiService {
  static const String deductBatchStockPath = 'api/inventory/deduct-batch-stock/';

  static Future<void> deductBatchStock({
    required String batchNumber, 
    required int quantity, 
    required String reason, 
  }) async {
    if (quantity <= 0) {
      throw Exception('Deduction quantity must be greater than zero.'); 
    }
    
    try {
      // Correct URL construction: 'http://' + '10.0.2.2:8000/' + 'api/...'
      final url = 'http://$API_BASE$deductBatchStockPath'; 
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          // Authorization headers would go here in a real app
        },
        body: jsonEncode(<String, dynamic>{
          'batch_number': batchNumber, 
          'quantity': quantity,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Batch stock deduction successful for Batch $batchNumber');
      } else {
        final errorData = json.decode(response.body);
        // Extract a specific error message if available, otherwise use the status code
        final errorMessage = errorData['detail'] ?? errorData['error'] ?? 'Unknown deduction error.';
        throw Exception('Failed to deduct batch stock: ${response.statusCode}. Detail: $errorMessage');
      }
    } catch (e) {
      // Ensure the error message is clean for the user
      final cleanError = e.toString().contains(':') ? e.toString().split(':').last.trim() : e.toString();
      throw Exception('Network or processing error during batch stock deduction: $cleanError');
    }
  }
}


// ===================== UI: Deduction Screen =====================
class DeductionScreen extends StatefulWidget {
  // BatchDetail is available because of the import
  final BatchDetail batch; 

  const DeductionScreen({super.key, required this.batch});

  @override
  State<DeductionScreen> createState() => _DeductionScreenState();
}

class _DeductionScreenState extends State<DeductionScreen> {
  // Quantity starts at 1, max is the available quantity in the batch.
  late int _deductQuantity;
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  // Controller for the typable quantity field
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    // Initialize quantity to 1
    _deductQuantity = 1; 
    
    // Initialize controller and sync it with the initial state
    _quantityController = TextEditingController(text: _deductQuantity.toString());

    // Listen for manual text changes to update the internal state
    _quantityController.addListener(_onQuantityTextChange);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityTextChange);
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
  
  // Logic to handle user typing in the text field
  void _onQuantityTextChange() {
    final text = _quantityController.text;
    final int? newQty = int.tryParse(text);

    if (newQty != null) {
      if (newQty < 1) {
        // Correct the quantity if user types a value less than 1
        _deductQuantity = 1;
        _quantityController.text = '1';
        _quantityController.selection = TextSelection.fromPosition(TextPosition(offset: _quantityController.text.length));
      } else if (newQty > widget.batch.quantity) {
        // Correct the quantity if user types a value greater than available stock
        _deductQuantity = widget.batch.quantity;
        _quantityController.text = _deductQuantity.toString();
        _quantityController.selection = TextSelection.fromPosition(TextPosition(offset: _quantityController.text.length));
      } else {
        _deductQuantity = newQty;
      }
      setState(() {});
    }
  }

  void _incrementQuantity() {
    if (_deductQuantity < widget.batch.quantity) {
      setState(() {
        _deductQuantity++;
        _quantityController.text = _deductQuantity.toString();
      });
    }
  }

  void _decrementQuantity() {
    if (_deductQuantity > 1) {
      setState(() {
        _deductQuantity--;
        _quantityController.text = _deductQuantity.toString();
      });
    }
  }
  
  Future<void> _submitDeduction() async {
    if (_formKey.currentState!.validate()) {
      if (_isProcessing) return;
      
      setState(() {
        _isProcessing = true;
      });

      try {
        final int quantity = int.parse(_quantityController.text);
        final String reason = _reasonController.text.trim();

        await InventoryApiService.deductBatchStock(
          batchNumber: widget.batch.batchNumber,
          quantity: quantity,
          reason: reason,
        );
        
        // Success: Show confirmation and return 'true' to the previous screen (InventoryDetailScreen)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully deducted $quantity units from Batch ${widget.batch.batchNumber}.'),
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Deduction Failed: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deduct Stock'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.batch.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      _buildInfoRow('Generic Name', widget.batch.genericName),
                      _buildInfoRow('Batch Number', widget.batch.batchNumber),
                      _buildInfoRow('Expiration Date', widget.batch.expirationDate),
                      _buildInfoRow('Available Stock', widget.batch.quantity.toString(), 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text('Quantity to Deduct', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              
              // Quantity Input with Plus/Minus Buttons
              Row(
                children: [
                  // Minus Button
                  _buildQuantityButton(
                    icon: Icons.remove,
                    onPressed: _decrementQuantity,
                    enabled: _deductQuantity > 1,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Typable Text Field
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final int? qty = int.tryParse(value);
                        if (qty == null || qty < 1) return 'Min 1';
                        if (qty > widget.batch.quantity) return 'Max ${widget.batch.quantity}';
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Plus Button
                  _buildQuantityButton(
                    icon: Icons.add,
                    onPressed: _incrementQuantity,
                    enabled: _deductQuantity < widget.batch.quantity,
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // Reason Input
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for Deduction (Required)',
                  hintText: 'e.g. Expired, Damaged in Transit, Inventory Adjustment',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a detailed reason.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _submitDeduction,
                  icon: _isProcessing 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_forever, color: Colors.white),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Confirm Deduction',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper widget for rendering info rows
  Widget _buildInfoRow(String title, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: style ?? const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
  
  // Helper widget for quantity buttons
  Widget _buildQuantityButton({
    required IconData icon, 
    required VoidCallback onPressed, 
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF5C7C9A) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: enabled ? Colors.white : Colors.grey.shade500),
        onPressed: enabled ? onPressed : null,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}