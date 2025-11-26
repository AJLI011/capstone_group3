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

// Extension to format strings for display in dropdowns
extension StringCasingExtension on String {
  String toTitleCase() => isNotEmpty
      ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}'
      : '';
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

  // --- UI CONSTANTS ---
  static const Color primaryColor = Color(0xFF1E88E5); // Blue 600
  static const Color cardColor = Color(0xFFF5F5F5); // Light Gray background for cards

  @override
  void initState() {
    super.initState();
    // Initialize form first with potential placeholder value
    _initializeForm();
    // Fetch suppliers, which might cause a rebuild and re-evaluation of the dropdown
    _fetchSuppliers(); 
    _fetchCategoryAndDosageChoices();
  }
  
  // --- UI HELPER WIDGETS ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
  
  // --- EXISTING LOGIC (UNCHANGED) ---

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
    final url = Uri.parse('http://192.168.1.4:8000/api/suppliers/');
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
    
    // Show a confirmation dialog before proceeding
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Update'),
        content: const Text('Are you sure you want to save these changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;


    final uri = Uri.parse(
        'http://192.168.1.4:8000/api/medicines/${widget.medicine['id']}/');
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
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Pop with true to indicate success
      }
    } else {
      print('Failed to update medicine: ${response.body}');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update medicine: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  
  // Helper validation for numbers
  String? _validateNumber(String? value, String fieldName, {bool isInteger = true}) {
    if (value == null || value.isEmpty) {
      return 'Please enter $fieldName.';
    }
    if (isInteger) {
      if (int.tryParse(value) == null) {
        return 'Please enter a valid whole number for $fieldName.';
      }
    } else {
        if (double.tryParse(value) == null) {
        return 'Please enter a valid price (e.g., 99.99).';
      }
    }
    return null;
  }

  // --- BUILD METHOD (ENHANCED UI) ---

  @override
  Widget build(BuildContext context) {
    final String? imageUrlFromWidget = widget.medicine['image'];
    String? fullImageUrl;

    if (imageUrlFromWidget != null) {
      final cleanImageUrl = imageUrlFromWidget.startsWith('/') ? imageUrlFromWidget : '/$imageUrlFromWidget';
      fullImageUrl = 'http://192.168.1.4:8000$cleanImageUrl';
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text( // Removed TextStyle here as it's set below, but you can keep it
          'Edit Medicine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Image Section ---
              _buildImageSection(fullImageUrl),
              const SizedBox(height: 24),

              // --- General Details Card ---
              _buildCard(
                title: 'General Details',
                children: [
                  _buildTextField(
                    controller: _nameController,
                    labelText: 'Medicine Name',
                    icon: Icons.medication_liquid_outlined,
                    validator: (value) => value!.isEmpty ? 'Enter medicine name' : null,
                  ),
                  _buildTextField(
                    controller: _genericNameController,
                    labelText: 'Generic Name',
                    icon: Icons.science_outlined,
                  ),
                  _buildTextField(
                    controller: _barcodeController,
                    labelText: 'Barcode',
                    icon: Icons.qr_code_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter barcode' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Classification Card ---
              _buildCard(
                title: 'Classification',
                children: [
                  _buildDropdownField(
                    labelText: 'Category',
                    value: _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null,
                    icon: Icons.class_outlined,
                    items: _categories.map((item) {
                      return DropdownMenuItem(
                        value: item, 
                        child: Text(item.replaceAll('_', ' ').toTitleCase(), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _categoryController.text = value!;
                      });
                    },
                    validator: (value) => (value == null || value.isEmpty) ? 'Please select a category.' : null,
                  ),
                  _buildDropdownField(
                    labelText: 'Dosage Form',
                    value: _dosageFormController.text.isNotEmpty
                        ? _dosageFormController.text
                        : null,
                    icon: Icons.format_list_bulleted,
                    items: _dosageForms.map((item) {
                      return DropdownMenuItem(
                        value: item, 
                        child: Text(item.toTitleCase(), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _dosageFormController.text = value!;
                      });
                    },
                    validator: (value) => (value == null || value.isEmpty) ? 'Please select a dosage form.' : null,
                  ),
                  _buildDropdownField(
                    labelText: 'Supplier',
                    value: _selectedSupplier, 
                    icon: Icons.local_shipping_outlined,
                    items: _supplierList.map<DropdownMenuItem<String>>((supplier) {
                      return DropdownMenuItem(
                        value: supplier['name'],
                        child: Text(supplier['name'], overflow: TextOverflow.ellipsis), 
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplier = value;
                      });
                    },
                    validator: (value) => null, // Supplier can be unselected/null
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Inventory Card ---
              _buildCard(
                title: 'Inventory & Pricing',
                children: [
                  _buildTextField(
                    controller: _restockQuantityController,
                    labelText: 'Restock Quantity',
                    icon: Icons.inventory_2_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(value, 'restock quantity'),
                  ),
                  _buildTextField(
                    controller: _priceController,
                    labelText: 'Price',
                    icon: Icons.money,
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(value, 'price', isInteger: false),
                  ),
                  Card(
                    elevation: 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: CheckboxListTile(
                      title: const Text(
                        'Requires Prescription',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      value: _requiresPrescription,
                      onChanged: (value) {
                        setState(() {
                          _requiresPrescription = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: primaryColor,
                      checkColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- Submit Button ---
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(color: primaryColor, thickness: 1, height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  // ⭐ MODIFIED SECTION: Changed from ClipOval to RoundedRectangleBorder/ClipRRect for a square image
  Widget _buildImageSection(String? fullImageUrl) {
    return Column(
      children: [
        Container(
          height: 150,
          width: 250,
          // CHANGE: Use a rounded rectangle border instead of a circular one
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15), // Rounded corners for the square/rectangle
            border: Border.all(color: primaryColor, width: 3),
          ),
          // CHANGE: Use ClipRRect for rounded rectangular clipping
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12), // Slightly smaller radius for clipping
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : fullImageUrl != null
                    ? Image.network(
                        fullImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: primaryColor));
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.medication,
                            size: 80,
                            color: Colors.grey,
                          );
                        },
                      )
                    : const Icon(
                        Icons.medication,
                        size: 80,
                        color: Colors.grey,
                      ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Change Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor.withOpacity(0.9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}