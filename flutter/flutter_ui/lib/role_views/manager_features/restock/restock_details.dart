import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Defined theme colors for the enhanced UI
const Color _primaryColor = Color(0xFF5C7C9A); // Existing color
const Color _accentColor = Color(0xFF007BFF); // A bright accent blue
const Color _cardColor = Colors.white;

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.8:8000/',
);

class RestockDetailsPage extends StatefulWidget {
  final Map<String, dynamic> medicine;

  const RestockDetailsPage({super.key, required this.medicine});

  @override
  State<RestockDetailsPage> createState() => _RestockDetailsPageState();
}

class _RestockDetailsPageState extends State<RestockDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _expirationDateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  bool _hasUnsavedChanges = false;
  late bool _isSyrup;

  @override
  void initState() {
    super.initState();
    _isSyrup = widget.medicine['dosage_form']?.toLowerCase() == 'syrup';

    if (widget.medicine['restock_quantity'] != null) {
      _quantityController.text = widget.medicine['restock_quantity'].toString();
    }

    _batchNumberController.addListener(_onTextChanged);
    _expirationDateController.addListener(_onTextChanged);
    if (_isSyrup) {
      _quantityController.addListener(_onTextChanged);
    }
  }

  // --- LOGIC (UNCHANGED) ---

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _showDiscardDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text(
              'Are you sure you want to exit? Your progress will be lost.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showSaveConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Restock'),
          content: const Text('Are you sure you want to save this restock entry?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _submitRestock() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields')),
      );
      return;
    }

    final shouldSave = await _showSaveConfirmationDialog();
    if (!shouldSave) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Staff ID not found.')),
      );
      return;
    }

    final restockData = {
      'medicine': widget.medicine['id'],
      'batch_num': _batchNumberController.text,
      'exp_date': _expirationDateController.text,
      'quantity': int.parse(_quantityController.text),
      'staff_id': staffId,
    };

    final url = Uri.parse('${API_BASE}api/inventory/add/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(restockData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _hasUnsavedChanges = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restock info submitted successfully!'), backgroundColor: Colors.green),
          );
          // Changed to pass a boolean `true` to indicate success
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          final errorBody = jsonDecode(response.body);
          final errorMessage = errorBody.toString();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}. ${errorMessage.length > 100 ? "See console for details." : errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to the server. Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _expirationDateController.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  // --- ENHANCED UI WIDGETS ---

  Widget _buildMedicineInfoCard() {
    // Helper function to format strings for display
    String formatValue(dynamic value) {
      if (value == null) return 'N/A';
      if (value is String) {
        // Simple title case for categories/forms
        return value.replaceAll('_', ' ').split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
      }
      return value.toString();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medicine Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            _infoRowEnhanced(Icons.medication_outlined, 'Name', formatValue(widget.medicine['name'])),
            _infoRowEnhanced(Icons.science_outlined, 'Generic Name', formatValue(widget.medicine['generic_name'])),
            _infoRowEnhanced(Icons.category_outlined, 'Category', formatValue(widget.medicine['category'])),
            _infoRowEnhanced(Icons.line_weight, 'Dosage Form', formatValue(widget.medicine['dosage_form'])),
            _infoRowEnhanced(Icons.money, 'Price', '₱${formatValue(widget.medicine['price'])}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRowEnhanced(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: _accentColor, size: 20),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestockInputCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restock Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 8),

            // Batch Number
            TextFormField(
              controller: _batchNumberController,
              decoration: _inputDecoration('Batch Number', Icons.local_offer_outlined),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a batch number' : null,
            ),
            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: _quantityController,
              readOnly: !_isSyrup,
              decoration: _inputDecoration(
                'Quantity',
                Icons.inventory_2_outlined,
                suffixIcon: _isSyrup ? const Icon(Icons.edit, color: _accentColor) : null,
                hintText: _isSyrup ? 'Enter number of bottles' : 'Quantity is fixed for non-syrup medicine',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Quantity cannot be empty';
                if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Invalid quantity value';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Expiration Date
            TextFormField(
              controller: _expirationDateController,
              readOnly: true,
              decoration: _inputDecoration(
                'Expiration Date',
                Icons.calendar_today,
                hintText: 'YYYY-MM-DD',
              ),
              onTap: () => _selectDate(context),
              validator: (value) =>
                  value!.isEmpty ? 'Please pick an expiration date' : null,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: _primaryColor),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
    );
  }

  // --- BUILD METHOD (ENHANCED) ---

  @override
  Widget build(BuildContext context) {
    final String? imageUrlFromWidget = widget.medicine['image'];
    String? fullImageUrl;

    if (imageUrlFromWidget != null) {
      final cleanImageUrl = imageUrlFromWidget.startsWith('/')
          ? imageUrlFromWidget
          : '/$imageUrlFromWidget';
      fullImageUrl = '$API_BASE$cleanImageUrl';
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('New Restock Entry'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Display
                if (fullImageUrl != null)
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                        color: _cardColor,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          fullImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Medicine Info Card
                _buildMedicineInfoCard(),
                const SizedBox(height: 24),

                // Restock Input Card
                _buildRestockInputCard(context),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton.icon(
                  onPressed: _submitRestock,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'SUBMIT RESTOCK',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed old _infoRow as it's replaced by _infoRowEnhanced
  @override
  void dispose() {
    _batchNumberController.removeListener(_onTextChanged);
    _expirationDateController.removeListener(_onTextChanged);
    if (_isSyrup) {
      _quantityController.removeListener(_onTextChanged);
    }
    _batchNumberController.dispose();
    _expirationDateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}