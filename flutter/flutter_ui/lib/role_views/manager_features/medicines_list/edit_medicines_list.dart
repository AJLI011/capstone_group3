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
    // Initialize form first with potential placeholder value
    _initializeForm();
    // Fetch suppliers, which might cause a rebuild and re-evaluation of the dropdown
    _fetchSuppliers(); 
    _fetchCategoryAndDosageChoices();
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
    
    // ⭐ FIX: Handle the '[Supplier Deleted]' placeholder
    const deletedPlaceholder = '[Supplier Deleted]';
    final currentSupplierName = med['supplier_name'];
    
    if (currentSupplierName != null && currentSupplierName != deletedPlaceholder) {
      // Set the supplier name if it is valid (not the placeholder)
      _selectedSupplier = currentSupplierName;
    } else {
      // If placeholder or null, ensure the dropdown starts as unselected (null value)
      _selectedSupplier = null; 
    }
  }

  Future<void> _fetchSuppliers() async {
    final url = Uri.parse('http://192.168.1.11:8000/api/suppliers/');
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
        'http://192.168.1.11:8000/api/medicines/${widget.medicine['id']}/');
    final request = http.MultipartRequest('PUT', uri);

    request.fields['name'] = _nameController.text;
    request.fields['generic_name'] = _genericNameController.text;
    request.fields['barcode'] = _barcodeController.text;
    request.fields['restock_quantity'] = _restockQuantityController.text;
    request.fields['price'] = _priceController.text;
    request.fields['category'] = _categoryController.text;
    request.fields['dosage_form'] = _dosageFormController.text;
    request.fields['requires_prescription'] = _requiresPrescription.toString();

    // Add staff_id from SharedPreferences
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
    request.fields['staff_id'] = staffId.toString();

    // Find the supplier ID from the selected name
    if (_selectedSupplier != null) {
      final supplier = _supplierList.firstWhere(
        (s) => s['name'] == _selectedSupplier,
        orElse: () => null,
      );
      if (supplier != null) {
        // Send the FK ID to the backend
        request.fields['supplier'] = supplier['id'].toString();
      }
    } else {
        // If _selectedSupplier is null (meaning the user cleared it or it was 
        // initialized as deleted), explicitly send 'null' for the FK.
        request.fields['supplier'] = '';
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
    final String? imageUrlFromWidget = widget.medicine['image'];
    String? fullImageUrl;

    if (imageUrlFromWidget != null) {
      final cleanImageUrl = imageUrlFromWidget.startsWith('/') ? imageUrlFromWidget : '/$imageUrlFromWidget';
      fullImageUrl = 'http://192.168.1.11:8000$cleanImageUrl';
    }

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
              // Image Display Section (Unchanged)
              if (fullImageUrl != null && _selectedImage == null)
                Image.network(
                  fullImageUrl,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Image loading error: $error');
                    return const Icon(
                      Icons.medication,
                      size: 100,
                      color: Colors.grey,
                    );
                  },
                )
              else if (_selectedImage != null)
                Image.file(_selectedImage!, height: 100, fit: BoxFit.cover,)
              else
                const Icon(
                  Icons.medication,
                  size: 100,
                  color: Colors.grey,
                ),

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
              // --- Category Dropdown FIX ---
              DropdownButtonFormField<String>(
                isExpanded: true, // ⭐ FIX: Prevents overflow for long items
                value: _categoryController.text.isNotEmpty
                    ? _categoryController.text
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((item) {
                  return DropdownMenuItem(
                    value: item, 
                    child: Text(item, overflow: TextOverflow.ellipsis), // Added overflow ellipsis
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryController.text = value!;
                  });
                },
              ),
              // --- Dosage Form Dropdown FIX ---
              DropdownButtonFormField<String>(
                isExpanded: true, // ⭐ FIX: Prevents overflow
                value: _dosageFormController.text.isNotEmpty
                    ? _dosageFormController.text
                    : null,
                decoration: const InputDecoration(labelText: 'Dosage Form'),
                items: _dosageForms.map((item) {
                  return DropdownMenuItem(
                    value: item, 
                    child: Text(item, overflow: TextOverflow.ellipsis), // Added overflow ellipsis
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _dosageFormController.text = value!;
                  });
                },
              ),
              // --- Supplier Dropdown FIX ---
              DropdownButtonFormField<String>(
                isExpanded: true, // ⭐ FIX: Prevents overflow
                // Use _selectedSupplier, which is correctly initialized to null 
                // if the supplier is deleted.
                value: _selectedSupplier, 
                decoration: const InputDecoration(labelText: 'Supplier'),
                items: _supplierList.map<DropdownMenuItem<String>>((supplier) {
                  return DropdownMenuItem(
                    value: supplier['name'],
                    // Use Text with overflow: TextOverflow.ellipsis
                    child: Text(supplier['name'], overflow: TextOverflow.ellipsis), 
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSupplier = value; // Value can be null if cleared
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