import 'dart:async'; // Import for Timer
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'barcodeScan_medicines_list.dart'; // Assumed this path is correct

// Defined theme colors for the enhanced UI
const Color _primaryColor = Color(0xFF5C7C9A);
const Color _accentColor = Color(0xFF4CAF50); // Submit/Success Green
const Color _secondaryColor = Color(0xFF007BFF); // Scan/Utility Blue
const Color _inputFillColor = Colors.white;

// Extension to format strings for display in dropdowns (UNCHANGED)
extension StringCasingExtension on String {
  String toTitleCase() => isNotEmpty
      ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}'
      : '';
}

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _medicineNameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _restockQuantityController = TextEditingController();
  final _productPriceController = TextEditingController();

  bool _prescriptionRequired = false;
  File? _selectedImage;
  bool _isLoadingSuppliers = true; // New loading state

  // State variables for dropdowns
  String? _selectedCategory;
  String? _selectedDosageForm;
  String? _selectedSupplier; // Holds the selected supplier name (for display in dropdown)

  List<dynamic> _supplierList = []; // To store fetched suppliers (id and name)
  List<String> _categories = []; // To store static/fetched categories
  List<String> _dosageForms = []; // To store static/fetched dosage forms

  // Debounce timer for barcode validation
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchCategoryAndDosageChoices();
    _barcodeController.addListener(_onBarcodeChanged);
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _debounce?.cancel();
    _barcodeController.dispose();
    _medicineNameController.dispose();
    _genericNameController.dispose();
    _restockQuantityController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }

  // --- LOGIC (UNCHANGED) ---

  void _onBarcodeChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final String barcode = _barcodeController.text.trim();
      if (barcode.isNotEmpty) {
        final bool barcodeExists = await _checkBarcodeExistence(barcode);
        if (barcodeExists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Barcode for this medicine is already existing.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  Future<bool> _checkBarcodeExistence(String barcode) async {
    // IMPORTANT: Replace with your computer's actual local IP address!
    final url = Uri.parse('http://10.0.0.2.2:8000/api/medicines/check_barcode/$barcode/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] as bool;
      } else {
        print("Failed to check barcode existence: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error checking barcode existence: $e");
      return false;
    }
  }

  Future<void> _fetchSuppliers() async {
    setState(() {
      _isLoadingSuppliers = true;
    });
    // IMPORTANT: Replace with your computer's actual local IP address!
    final url = Uri.parse('http://10.0.0.2.2:8000/api/suppliers/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _supplierList = json.decode(response.body);
        });
      } else {
        print("Failed to fetch suppliers: ${response.statusCode} - ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load suppliers: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print("Error fetching suppliers: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error fetching suppliers: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingSuppliers = false;
      });
    }
  }

  void _fetchCategoryAndDosageChoices() {
    setState(() {
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
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Added imageQuality
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _addMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String enteredBarcode = _barcodeController.text.trim();
    if (enteredBarcode.isNotEmpty) {
      final bool barcodeExists = await _checkBarcodeExistence(enteredBarcode);
      if (barcodeExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This barcode already exists. Please enter a new one.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // IMPORTANT: Replace with your computer's actual local IP address!
    final url = Uri.parse('http://10.0.0.2.2:8000/api/medicines/');
    final request = http.MultipartRequest('POST', url);

    // Add text fields
    request.fields['name'] = _medicineNameController.text;
    request.fields['generic_name'] = _genericNameController.text;
    request.fields['barcode'] = enteredBarcode;
    request.fields['restock_quantity'] = _restockQuantityController.text;
    request.fields['price'] = _productPriceController.text;

    // Add dropdown selected values
    request.fields['category'] = _selectedCategory ?? '';
    request.fields['dosage_form'] = _selectedDosageForm ?? '';
    request.fields['requires_prescription'] = _prescriptionRequired.toString();

    // Find and send the supplier's ID
    if (_selectedSupplier != null) {
      final supplier = _supplierList.firstWhere(
            (s) => s['name'] == _selectedSupplier,
        orElse: () => null,
      );

      if (supplier != null) {
        request.fields['supplier'] = supplier['id'].toString();
        
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

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Selected supplier not found in list.')),
          );
        }
        return;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a supplier.')),
        );
      }
      return;
    }

    // Add image file
    if (_selectedImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicine added successfully!'), backgroundColor: _accentColor),
          );
        }
        Navigator.of(context).pop();
      } else {
        print('Failed to add medicine: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add medicine: ${response.body}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error adding medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding medicine: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('Are you sure you want to exit? Your progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    )) ?? false;
  }

  // --- ENHANCED UI WIDGETS ---

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7), size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      filled: true,
      fillColor: _inputFillColor,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 28),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const Expanded(child: Divider(color: _primaryColor, indent: 10, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(title, icon),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
    bool isLoading = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label, icon).copyWith(
        suffixIcon: isLoading ? const Padding(
          padding: EdgeInsets.only(right: 15.0),
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor)),
        ) : null,
      ),
      icon: isLoading ? null : const Icon(Icons.arrow_drop_down, color: _primaryColor),
      isExpanded: true,
      items: items,
      onChanged: isLoading ? null : onChanged,
      validator: validator,
      // Custom styling for the dropdown button itself
      dropdownColor: Colors.grey[50],
      style: const TextStyle(color: Colors.black87, fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50], // Light background for contrast
        appBar: AppBar(
          title: const Text('Add New Medicine'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black45,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Image and Barcode Section
                _buildCard(
                  title: 'Product Identification',
                  icon: Icons.qr_code_2,
                  children: [
                    // Image Upload
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _primaryColor, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : Icon(Icons.image_search, size: 50, color: _primaryColor.withOpacity(0.6)),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Barcode Input
                    TextFormField(
                      controller: _barcodeController,
                      decoration: _inputDecoration('Barcode', Icons.qr_code),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Please enter a barcode.' : null,
                    ),
                    const SizedBox(height: 12),

                    // Scan Barcode Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final String? scannedBarcode = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BarcodeScannerScreen(),
                          ),
                        );
                        if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
                          final bool barcodeExists = await _checkBarcodeExistence(scannedBarcode);
                          if (barcodeExists) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Barcode already exists. Please scan a new one.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            setState(() {
                              _barcodeController.text = scannedBarcode;
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Barcode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                // 2. Main Details Section
                _buildCard(
                  title: 'Product Information',
                  icon: Icons.info_outline,
                  children: [
                    // Name and Generic Name (Row layout)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _medicineNameController,
                            decoration: _inputDecoration('Medicine Name', Icons.local_hospital_outlined),
                            validator: (value) => value!.isEmpty ? 'Enter name' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _genericNameController,
                            decoration: _inputDecoration('Generic Name', Icons.science_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    _buildDropdownField(
                      label: 'Category',
                      icon: Icons.category_outlined,
                      value: _selectedCategory,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category.replaceAll('_', ' ').toTitleCase(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) => (value == null || value.isEmpty) ? 'Select category.' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dosage Form Dropdown
                    _buildDropdownField(
                      label: 'Dosage Form',
                      icon: Icons.medication_liquid_outlined,
                      value: _selectedDosageForm,
                      items: _dosageForms.map((String form) {
                        return DropdownMenuItem<String>(
                          value: form,
                          child: Text(form.toTitleCase(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDosageForm = newValue;
                        });
                      },
                      validator: (value) => (value == null || value.isEmpty) ? 'Select dosage form.' : null,
                    ),
                    const SizedBox(height: 16),

                    // Supplier Dropdown
                    _buildDropdownField(
                      label: 'Supplier Name',
                      icon: Icons.business_outlined,
                      value: _selectedSupplier,
                      isLoading: _isLoadingSuppliers,
                      items: _isLoadingSuppliers
                          ? []
                          : _supplierList.map<DropdownMenuItem<String>>((supplier) {
                        return DropdownMenuItem<String>(
                          value: supplier['name'],
                          child: Text(supplier['name'], overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSupplier = newValue;
                        });
                      },
                      validator: (value) => (value == null || value.isEmpty) ? 'Select a supplier.' : null,
                    ),
                  ],
                ),

                // 3. Inventory and Price Section
                _buildCard(
                  title: 'Inventory & Pricing',
                  icon: Icons.shopping_cart_outlined,
                  children: [
                    // Quantity and Price (Row layout)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _restockQuantityController,
                            decoration: _inputDecoration('Restock Qty', Icons.low_priority),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter quantity.';
                              if (int.tryParse(value) == null) return 'Valid number.';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _productPriceController,
                            decoration: _inputDecoration('Price (₱)', Icons.attach_money),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter price.';
                              if (double.tryParse(value) == null) return 'Valid number.';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Checkbox
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: CheckboxListTile(
                        title: const Text(
                          'Requires Prescription',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        value: _prescriptionRequired,
                        onChanged: (value) {
                          setState(() {
                            _prescriptionRequired = value ?? false;
                          });
                        },
                        checkColor: Colors.white,
                        activeColor: _primaryColor,
                        tileColor: Colors.transparent,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Submit button
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Confirm Submission'),
                          content: const Text('Are you sure you want to add this medicine?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white),
                              child: const Text('Add Medicine'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      _addMedicine();
                    }
                  },
                  icon: const Icon(Icons.save_outlined, size: 24),
                  label: const Text(
                    'ADD MEDICINE',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 7,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
