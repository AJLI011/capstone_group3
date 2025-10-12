import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.11:8000/',
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
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
          title: const Text('Confirm Save?'),
          content: const Text('Are you sure you want to save the changes?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
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
            const SnackBar(content: Text('Restock info submitted')),
          );
          // Changed to pass a boolean `true` to indicate success
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to the server. Error: $e')),
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
        appBar: AppBar(
          title: const Text('Restock'),
          backgroundColor: const Color(0xFF5C7C9A),
          foregroundColor: Colors.white,
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
                  readOnly: !_isSyrup,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    suffixIcon: _isSyrup ? const Icon(Icons.edit) : null,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Quantity cannot be empty';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Invalid quantity value';
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
    if (_isSyrup) {
      _quantityController.removeListener(_onTextChanged);
    }
    _batchNumberController.dispose();
    _expirationDateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}