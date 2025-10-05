import 'dart:async'; // Import for Timer
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'barcodeScan_medicines_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Extension to format strings for display in dropdowns
extension StringCasingExtension on String {
  String toTitleCase() => this.isNotEmpty
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
    _fetchSuppliers(); // Fetch suppliers when the screen initializes
    _fetchCategoryAndDosageChoices(); // Populate static choices
    _barcodeController.addListener(_onBarcodeChanged); // Add listener for live barcode check
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _debounce?.cancel(); // Cancel the debounce timer
    _barcodeController.dispose();
    _medicineNameController.dispose();
    _genericNameController.dispose();
    _restockQuantityController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }

  // Live barcode existence check with a debounce timer
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
                backgroundColor: Color.fromARGB(255, 83, 83, 83),
              ),
            );
          }
        }
      }
    });
  }

  // New function to check for barcode existence
  Future<bool> _checkBarcodeExistence(String barcode) async {
    // IMPORTANT: Replace with your computer's actual local IP address!
    final url = Uri.parse('http://bluewhiteph.pythonanywhere.com/api/medicines/check_barcode/$barcode/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] as bool;
      } else {
        print("Failed to check barcode existence: ${response.statusCode}");
        return false; // Assume it doesn't exist to avoid blocking
      }
    } catch (e) {
      print("Error checking barcode existence: $e");
      return false; // Assume it doesn't exist to avoid blocking
    }
  }

  // Fetches suppliers from your Django API
  Future<void> _fetchSuppliers() async {
    // IMPORTANT: Replace with your computer's actual local IP address!
    final url = Uri.parse('http://bluewhiteph.pythonanywhere.com/api/suppliers/');
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
    }
  }

  // Populates static category and dosage form choices
  void _fetchCategoryAndDosageChoices() {
    // These must exactly match the values from your Django model's choices for Category and Dosage Form
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
    final url = Uri.parse('http://bluewhiteph.pythonanywhere.com/api/medicines/');
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
        orElse: () => null, // Returns null if no matching supplier found
      );

      if (supplier != null) {
        request.fields['supplier'] = supplier['id'].toString(); // Send the ID as string
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

        request.fields['staff_id'] = staffId.toString();

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Selected supplier not found in list.')),
          );
        }
        return; // Stop the function if supplier ID can't be determined
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a supplier.')),
        );
      }
      return; // Stop the function if no supplier is selected
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

      if (response.statusCode == 201) { // 201 Created is typical for successful POST
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicine added successfully!')),
          );
        }
        Navigator.of(context).pop(); // Go back to the previous screen
      } else {
        print('Failed to add medicine: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add medicine: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print('Error adding medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding medicine: $e')),
        );
      }
    }
  }

  /// Shows a confirmation dialog when the user tries to exit the screen.
  Future<bool> _onWillPop() async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('Are you sure you want to exit? Your progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Stay on the screen
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Exit the screen
              child: const Text('Yes'),
            ),
          ],
        );
      },
    )) ?? false; // In case the user dismisses the dialog by tapping outside, return false.
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Medicine'),
          backgroundColor: const Color(0xFF5C7C9A), // Updated color
          foregroundColor: Colors.white, // Updated color for font and icon
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picking section
                Center(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, height: 150)
                      : Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    _pickImage();
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('Select Image'),
                ),
                const SizedBox(height: 24),
                // Text fields
                TextFormField(
                  controller: _medicineNameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value!.isEmpty ? 'Please enter medicine name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _genericNameController,
                  decoration: const InputDecoration(
                    labelText: 'Generic Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Barcode text field with on-the-fly validation
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a barcode.' : null,
                ),
                const SizedBox(height: 16),
                
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
                              backgroundColor: Color.fromARGB(255, 98, 98, 98),
                            ),
                          );
                        }
                        // DO NOT update the text field
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
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Dropdowns with overflow fix
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category.replaceAll('_', ' ').toTitleCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDosageForm,
                  decoration: const InputDecoration(
                    labelText: 'Dosage Form',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: _dosageForms.map((String form) {
                    return DropdownMenuItem<String>(
                      value: form,
                      child: Text(
                        form.toTitleCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDosageForm = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a dosage form.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSupplier,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: _supplierList.isEmpty
                      ? []
                      : _supplierList.map<DropdownMenuItem<String>>((supplier) {
                    return DropdownMenuItem<String>(
                      value: supplier['name'],
                      child: Text(
                        supplier['name'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSupplier = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a supplier.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Numeric fields
                TextFormField(
                  controller: _restockQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Restock Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter restock quantity.';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _productPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter price.';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Checkbox
                CheckboxListTile(
                  title: const Text('Requires Prescription'),
                  value: _prescriptionRequired,
                  onChanged: (value) {
                    setState(() {
                      _prescriptionRequired = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Confirm Submission'),
                          content: const Text('Are you sure you want to add this medicine?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Yes'),
                            ),
                          ],
                        );
                      },
                    );

                    // If user confirmed, proceed with adding the medicine
                    if (confirmed == true) {
                      _addMedicine();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add Medicine',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}