import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

Future<void> _submitRestock() async {
  if (_batchNumberController.text.isEmpty || _expirationDateController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill out all fields')),
    );
    return;
  }

  if (!_formKey.currentState!.validate()) return;

  final restockData = {
    'medicine': widget.medicine['id'],
    'batch_num': _batchNumberController.text, // changed key
    'exp_date': _expirationDateController.text, // changed key
  };

  print('Submitting restock data: $restockData'); // <-- Added print statement

  final url = Uri.parse('http://10.0.2.2:8000/api/expiration-list/add/');
  
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
              _infoRow('Quantity', '${widget.medicine['restock_quantity']}'),

              const Divider(height: 32),

              TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a batch number' : null,
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
}
