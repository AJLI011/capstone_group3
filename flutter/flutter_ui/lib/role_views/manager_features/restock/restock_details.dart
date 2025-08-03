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

  @override
  void initState() {
    super.initState();
    // Initialize quantity controller with restock_quantity from the passed medicine data
    if (widget.medicine['restock_quantity'] != null) {
      _quantityController.text = widget.medicine['restock_quantity'].toString();
    }
  }

  Future<void> _submitRestock() async {
    if (_batchNumberController.text.isEmpty ||
        _expirationDateController.text.isEmpty ||
        _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

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

      final url = Uri.parse('http://10.0.2.2:8000/api/inventory/add/'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(restockData),
      );

    if (response.statusCode == 201 || response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restock info submitted')),
      );
      Navigator.pop(context);
    } else {
      print('Error submitting restock: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${response.statusCode}')),
      );
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
      fullImageUrl = 'http://10.0.2.2:8000$cleanImageUrl';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restock')),
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
                    if (int.tryParse(value) == null || int.parse(value)! <= 0) {
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
    _batchNumberController.dispose();
    _expirationDateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}