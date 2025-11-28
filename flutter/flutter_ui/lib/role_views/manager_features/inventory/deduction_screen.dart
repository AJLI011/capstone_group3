import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; 
import 'inventory_detail_screen.dart'; 
// Ensure 'inventory_detail_screen.dart' defines BatchDetail

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: '192.168.1.5:8000/', 
);

// ===================== STAFF ID RETRIEVAL (CORRECTED) =====================
Future<int?> getManagerStaffId() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? staffId = prefs.getInt('staff_id'); 
    
    if (staffId == null) {
      print('Error: Staff ID not found in Shared Preferences.');
    }
    return staffId;

  } catch (e) {
    print('Error accessing Shared Preferences: $e');
    return null;
  }
}
// =======================================================================================


// --- REASON DEFINITION ---
class DeductionReason {
  final String key;
  final String label;
  final IconData icon;

  DeductionReason(this.key, this.label, this.icon);
}

final List<DeductionReason> _commonReasons = [
  DeductionReason('missing', 'Lost/Missing Stock', Icons.search_off),
  DeductionReason('damage', 'Damaged in Transit/Storage', Icons.broken_image),
  DeductionReason('inventory_adj', 'Inventory Adjustment', Icons.inventory),
  DeductionReason('other', 'Other Reason (Specify Below)', Icons.edit_note),
];
// -----------------------------


// ===================== SERVICE: API Calls (MODIFIED) =====================
class InventoryApiService {
  static const String deductBatchStockPath = 'api/inventory/deduct-batch-stock/';

  // MODIFIED: Changed batchNumber to inventoryId (type int)
  static Future<void> deductBatchStock({
    required int inventoryId, // <--- 1. MODIFIED PARAMETER NAME/TYPE
    required int quantity, 
    required String reason, 
    required int staffId, 
  }) async {
    if (quantity <= 0) {
      throw Exception('Deduction quantity must be greater than zero.'); 
    }
    
    if (reason.trim().isEmpty) {
      throw Exception('A deduction reason is required.');
    }

    try {
      final url = 'http://$API_BASE$deductBatchStockPath'; 
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          // MODIFIED: Send inventory_id instead of batch_number
          'inventory_id': inventoryId, // <--- 2. MODIFIED JSON PAYLOAD KEY/VALUE
          'quantity': quantity,
          'reason': reason,
          'staff_id': staffId, 
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Batch stock deduction successful for Inventory ID $inventoryId');
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['detail'] ?? errorData['error'] ?? 'Unknown deduction error.';
        throw Exception('Failed to deduct batch stock: ${response.statusCode}. Detail: $errorMessage');
      }
    } catch (e) {
      final cleanError = e.toString().contains(':') ? e.toString().split(':').last.trim() : e.toString();
      throw Exception('Network or processing error during batch stock deduction: $cleanError');
    }
  }
}


// ===================== UI: Deduction Screen (UPDATED) =====================
class DeductionScreen extends StatefulWidget {
  final BatchDetail batch; 

  const DeductionScreen({super.key, required this.batch});

  @override
  State<DeductionScreen> createState() => _DeductionScreenState();
}

class _DeductionScreenState extends State<DeductionScreen> {
  late int _deductQuantity;
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  late final TextEditingController _quantityController;

  String? _selectedReason = _commonReasons.first.key; 


  @override
  void initState() {
    super.initState();
    _deductQuantity = 1; 
    _quantityController = TextEditingController(text: _deductQuantity.toString());
    _quantityController.addListener(_onQuantityTextChange);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityTextChange);
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
  
  void _onQuantityTextChange() {
    final text = _quantityController.text;
    final int? newQty = int.tryParse(text);

    if (newQty != null) {
      if (newQty < 1) {
        _deductQuantity = 1;
        _quantityController.text = '1';
        _quantityController.selection = TextSelection.fromPosition(TextPosition(offset: _quantityController.text.length));
      } else if (newQty > widget.batch.quantity) {
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

  Future<void> _executeDeduction({
    required int quantity,
    required String finalReason,
  }) async {
    if (_isProcessing) return;
    
    // 3. FETCH STAFF ID USING SHARED PREFERENCES
    final int? staffId = await getManagerStaffId();
    
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deduction Failed: Staff ID not available. Please log in.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // 3. END FETCH STAFF ID

    setState(() {
      _isProcessing = true;
    });

    try {
      // MODIFIED: Pass inventoryId (widget.batch.id) instead of batchNumber
      await InventoryApiService.deductBatchStock(
        inventoryId: widget.batch.id, // <--- 3. PASS UNIQUE ID
        quantity: quantity,
        reason: finalReason, 
        staffId: staffId, 
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deducted $quantity units ($finalReason) from Batch ${widget.batch.batchNumber}.'),
        ),
      );
      // Navigate back and pass 'true' to indicate success/refresh needed
      Navigator.pop(context, true); 

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deduction Failed: ${e.toString().split(':').last.trim()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _submitDeduction() async {
    if (!_formKey.currentState!.validate()) {
      return; 
    }
    
    String finalReason = '';
    final selectedKey = _selectedReason;
    final otherReasonText = _reasonController.text.trim();
    final int quantity = int.parse(_quantityController.text);

    if (selectedKey != null) {
      final selectedReasonObj = _commonReasons.firstWhere((r) => r.key == selectedKey);
      
      if (selectedKey == 'other') {
        finalReason = otherReasonText;
      } else {
        finalReason = selectedReasonObj.label;
      }
    }
    
    if (finalReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: const Text('Please select a reason or specify one in the text box.'),
        backgroundColor: Colors.red,
          ),
        );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Stock Deduction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are about to deduct **$quantity** unit/s of **${widget.batch.name}**.', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Reason: $finalReason'),
              const SizedBox(height: 15),
              const Text('Are you sure you want to proceed? This action cannot be undone.'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), 
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), 
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Deduct Stock'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _executeDeduction(quantity: quantity, finalReason: finalReason);
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isOtherSelected = _selectedReason == 'other';
    
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

              // --- REASON RADIO BUTTONS ---
              const Text('Reason for Deduction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              
              ..._commonReasons.map((reason) {
                return _buildReasonRadioListTile(reason, isOtherSelected);
              }).toList(),
              
              const SizedBox(height: 10),

              // Reason Input Text Field (Conditionally visible/validated)
              if (isOtherSelected) 
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Specify Other Reason (Required)',
                    hintText: 'e.g. Returned to Supplier, Loss during handling, etc.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  validator: (value) {
                    if (isOtherSelected && (value == null || value.trim().isEmpty)) {
                      return 'Please provide a detailed reason when "Other Reason" is selected.';
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
  
  Widget _buildReasonRadioListTile(DeductionReason reason, bool isOtherSelected) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(reason.icon, size: 20, color: _selectedReason == reason.key ? const Color(0xFF5C7C9A) : Colors.black54),
          const SizedBox(width: 8),
          Text(reason.label, style: const TextStyle(fontSize: 16)),
        ],
      ),
      value: reason.key,
      groupValue: _selectedReason,
      onChanged: (String? value) {
        setState(() {
          _selectedReason = value;
          if (value != 'other') {
            _reasonController.clear();
          }
        });
      },
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: const Color(0xFF5C7C9A),
    );
  }
  
  Widget _buildInfoRow(String title, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:', style: const TextStyle(color: Colors.black87, fontSize: 14)), 
          Text(value, style: style ?? const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
  
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