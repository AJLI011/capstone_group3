import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


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

  // A new state variable to track if there are any unsaved changes.
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize quantity controller with restock_quantity from the passed medicine data
    if (widget.medicine['restock_quantity'] != null) {
      _quantityController.text = widget.medicine['restock_quantity'].toString();
    }

    // Add listeners to detect changes in the text fields.
    _batchNumberController.addListener(_onTextChanged);
    _expirationDateController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // We only need to set the state once when a change is detected.
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // This is the dialog that will be shown when the user tries to exit.
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
                Navigator.of(context).pop(false); // Do not exit the page
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Exit the page
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false; // In case the user taps outside the dialog.
  }

  // New dialog for confirming save action.
  Future<bool> _showSaveConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Save?'),
          content: const Text('Are you sure you want to save the changes?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Do not save
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Proceed with save
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _submitRestock() async {
    // First, validate the form. If validation fails, show a snackbar and return.
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields')),
      );
      return;
    }

    // Show confirmation dialog before proceeding with the API call.
    final shouldSave = await _showSaveConfirmationDialog();
    if (!shouldSave) {
      // If the user chooses not to save, we simply return.
      return;
    }

    // Proceed with the save logic only if the user confirmed.
    // 🧠 Get staff ID from SharedPreferences
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
      'staff_id': staffId, // ✅ Add staff_id here!
    };


    print('Submitting restock data: $restockData');

    final url = Uri.parse('http://jallybee.pythonanywhere.com/api/inventory/add/'); 
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(restockData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      // On successful submission, reset the unsaved changes flag so we can pop
      _hasUnsavedChanges = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restock info submitted')),
        );
        Navigator.pop(context);
      }
    } else {
      print('Error submitting restock: ${response.body}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
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
    );

    if (pickedDate != null) {
      setState(() {
        _expirationDateController.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrlFromWidget = widget.medicine['image'];
    String? fullImageUrl;

    if (imageUrlFromWidget != null) {
      final cleanImageUrl = imageUrlFromWidget.startsWith('/')
          ? imageUrlFromWidget
          : '/$imageUrlFromWidget';
      fullImageUrl = 'http://jallybee.pythonanywhere.com$cleanImageUrl';
    }

    return PopScope(
      // The canPop property is now dynamically controlled by our _hasUnsavedChanges state variable.
      // If no changes have been made, _hasUnsavedChanges is false, and canPop is true,
      // allowing the back button to function normally.
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (bool didPop) async {
        // This callback only runs if canPop was false.
        // The didPop argument will be false, indicating the pop was blocked.
        if (!didPop) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop) {
            // If the user confirms, we manually pop the route.
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Restock'),
          backgroundColor: const Color(0xFF5C7C9A), // Updated color
          foregroundColor: Colors.white, // Updated color for font and icon
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fullImageUrl != null)
                  Center(
                    child: Image.network(
                      fullImageUrl,
                      height: 120,
                      errorBuilder: (context, error, stack) =>
                          const Text('Image failed to load'),
                    ),
                  ),
                const SizedBox(height: 16),

                _infoRow('Name', widget.medicine['name']),
                _infoRow('Generic Name', widget.medicine['generic_name']),
                _infoRow('Category', widget.medicine['category']),
                _infoRow('Dosage Form', widget.medicine['dosage_form']),
                _infoRow('Price', '₱${widget.medicine['price']}'),
                // You can keep or remove this display row, as the TextFormField below now handles the actual value
                // _infoRow('Quantity', '${widget.medicine['restock_quantity'] ?? 'N/A'}'), 

                const Divider(height: 32),

                TextFormField(
                  controller: _batchNumberController,
                  decoration: const InputDecoration(labelText: 'Batch Number'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a batch number' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _quantityController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  // The validator might still be useful for initial display if the value is not set
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Quantity cannot be empty'; // Changed message as it's not user input
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Invalid quantity value'; // Changed message
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _expirationDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _selectDate(context),
                  validator: (value) =>
                      value!.isEmpty ? 'Please pick an expiration date' : null,
                ),

                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitRestock,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: ${value ?? 'N/A'}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  void dispose() {
    _batchNumberController.removeListener(_onTextChanged);
    _expirationDateController.removeListener(_onTextChanged);
    _batchNumberController.dispose();
    _expirationDateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
