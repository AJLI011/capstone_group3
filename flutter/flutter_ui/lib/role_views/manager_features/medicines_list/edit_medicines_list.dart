import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditMedicinePage extends StatefulWidget {
  final Map<String, dynamic> medicine;

  const EditMedicinePage({super.key, required this.medicine});

  @override
  State<EditMedicinePage> createState() => _EditMedicinePageState();
}

class _EditMedicinePageState extends State<EditMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _restockQuantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _dosageFormController = TextEditingController();

  bool _requiresPrescription = false;
  String? _selectedSupplier;
  File? _selectedImage;

  List<dynamic> _supplierList = [];
  List<String> _categories = [];
  List<String> _dosageForms = [];

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchCategoryAndDosageChoices();
    _initializeForm();
  }

  void _initializeForm() {
    final med = widget.medicine;
    _nameController.text = med['name'] ?? '';
    _genericNameController.text = med['generic_name'] ?? '';
    _barcodeController.text = med['barcode'] ?? '';
    _restockQuantityController.text = med['restock_quantity'].toString();
    _priceController.text = med['price'].toString();
    _requiresPrescription = med['requires_prescription'] ?? false;
    _categoryController.text = med['category'] ?? '';
    _dosageFormController.text = med['dosage_form'] ?? '';
    _selectedSupplier = med['supplier_name'];
  }

  Future<void> _fetchSuppliers() async {
    final url = Uri.parse('http://10.0.2.2:8000/api/suppliers/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _supplierList = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching suppliers: $e");
    }
  }

  void _fetchCategoryAndDosageChoices() {
    // These must match the values from your Django model
    _categories = [
      'analgesics',
      'antibiotics',
      'antivirals',
      'antihypertensives',
      'antidiabetics',
      'gastrointestinal_medicines',
      'antihistamines',
      'cough_and_cold_medicines',
      'vitamins_and_supplements',
      'cardiovascular_medicines',
      'anti_asthma_and_respiratory_medicines',
      'antimalarials',
      'antiparasitics',
    ];

    _dosageForms = [
      'tablet',
      'syrup',
      'capsule',
    ];
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final uri = Uri.parse(
        'http://10.0.2.2:8000/api/medicines/${widget.medicine['id']}/');
    final request = http.MultipartRequest('PUT', uri);

    request.fields['name'] = _nameController.text;
    request.fields['generic_name'] = _genericNameController.text;
    request.fields['barcode'] = _barcodeController.text;
    request.fields['restock_quantity'] = _restockQuantityController.text;
    request.fields['price'] = _priceController.text;
    request.fields['category'] = _categoryController.text;
    request.fields['dosage_form'] = _dosageFormController.text;
    request.fields['requires_prescription'] = _requiresPrescription.toString();

    // ✅ Add staff_id from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');
    if (staffId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Staff ID not found.')),
        );
      }
      return;
    }
    request.fields['staff_id'] = staffId.toString(); // ✅ Send to backend


    if (_selectedSupplier != null) {
      final supplier = _supplierList.firstWhere(
        (s) => s['name'] == _selectedSupplier,
        orElse: () => null,
      );
      if (supplier != null) {
        request.fields['supplier'] = supplier['id'].toString();
      }
    }

    if (_selectedImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 202) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine updated successfully')),
      );
      Navigator.of(context).pop();
    } else {
      print('Failed to update medicine: ${response.body}');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Start of added/modified debug code ---
    final String? imageUrlFromWidget = widget.medicine['image'];
    String? fullImageUrl;

    if (imageUrlFromWidget != null) {
      // Ensure the path starts with a '/' for correct URL construction
      final cleanImageUrl = imageUrlFromWidget.startsWith('/') ? imageUrlFromWidget : '/$imageUrlFromWidget';
      fullImageUrl = 'http://10.0.2.2:8000$cleanImageUrl';
      print('DEBUG: Attempting to load image from: $fullImageUrl');
    } else {
      print('DEBUG: Image URL from widget.medicine is null for this entry.');
    }
    // --- End of added/modified debug code ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medicine'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Display existing image from network if available and no new image selected
              if (fullImageUrl != null && _selectedImage == null)
                Image.network(
                  fullImageUrl, // Use the constructed fullImageUrl here
                  height: 100,
                  // Add error handling for network images
                  errorBuilder: (context, error, stackTrace) {
                    print('Image loading error: $error'); // Log the error
                    return const Text('Image failed to load ❌'); // Placeholder text
                  },
                ),
              // Display newly selected image from file
              if (_selectedImage != null)
                Image.file(_selectedImage!, height: 100),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Change Image'),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Enter medicine name' : null,
              ),
              TextFormField(
                controller: _genericNameController,
                decoration: const InputDecoration(labelText: 'Generic Name'),
              ),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode'),
              ),
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty
                    ? _categoryController.text
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryController.text = value!;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                value: _dosageFormController.text.isNotEmpty
                    ? _dosageFormController.text
                    : null,
                decoration: const InputDecoration(labelText: 'Dosage Form'),
                items: _dosageForms.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _dosageFormController.text = value!;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedSupplier,
                decoration: const InputDecoration(labelText: 'Supplier'),
                items: _supplierList.map<DropdownMenuItem<String>>((supplier) {
                  return DropdownMenuItem(
                    value: supplier['name'],
                    child: Text(supplier['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSupplier = value!;
                  });
                },
              ),
              TextFormField(
                controller: _restockQuantityController,
                decoration: const InputDecoration(labelText: 'Restock Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                title: const Text('Requires Prescription'),
                value: _requiresPrescription,
                onChanged: (value) {
                  setState(() {
                    _requiresPrescription = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Update Medicine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}