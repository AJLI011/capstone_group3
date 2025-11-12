import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'edit_medicines_list.dart';

import 'add_medicines_list.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Medicine {
  final int? id;
  final String? barcode;
  final String? name;
  final String? genericName;
  final String? category;
  final String? dosageForm;
  final String? supplier; // supplier ID
  final String? supplierName; // supplier name
  final bool? prescriptionRequired;
  final int? quantity;
  final double? price;
  final String? image;

  Medicine({
    this.id,
    this.barcode,
    this.name,
    this.genericName,
    this.category,
    this.dosageForm,
    this.supplier,
    this.supplierName,
    this.prescriptionRequired,
    this.quantity,
    this.price,
    this.image,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString(),
      genericName: json['generic_name']?.toString(),
      category: json['category']?.toString(),
      dosageForm: json['dosage_form']?.toString(),
      supplier: json['supplier']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      prescriptionRequired: json['requires_prescription'],
      quantity: json['restock_quantity'] != null
          ? int.tryParse(json['restock_quantity'].toString())
          : 0,
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : 0.0,
      image: json['image']?.toString(),
    );
  }

  // Add this method to convert Medicine object to a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'generic_name': genericName,
      'category': category,
      'dosage_form': dosageForm,
      'supplier': supplier,
      'supplier_name': supplierName,
      'requires_prescription': prescriptionRequired,
      'restock_quantity': quantity,
      'price': price,
      'image': image,
    };
  }
}

class MedicineListView extends StatefulWidget {
  const MedicineListView({super.key});

  @override
  State<MedicineListView> createState() => _MedicineListViewState();
}

class _MedicineListViewState extends State<MedicineListView> {
  // Updated to hold the list directly
  List<Medicine> _medicines = [];
  // State for lazy loading
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10; // Number of items to fetch per page
  final ScrollController _scrollController = ScrollController();
  
  // *** START OF ADDED CODE FOR SEARCH ***
  List<Medicine> _filteredMedicines = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  // *** END OF ADDED CODE FOR SEARCH ***

  @override
  void initState() {
    super.initState();
    // Initial fetch
    _fetchMedicines();
    // Add listener for infinite scrolling
    _scrollController.addListener(_onScroll);
    // *** ADDED LISTENER FOR SEARCH ***
    _searchController.addListener(_filterMedicines);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // *** DISPOSE OF SEARCH CONTROLLER ***
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Check if the user has scrolled to the end of the list
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Trigger fetch for the next page
      _fetchMedicines();
    }
  }

  // *** ADDED METHOD TO FILTER MEDICINES ***
  void _filterMedicines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = List.from(_medicines);
      } else {
        _filteredMedicines = _medicines
            .where((medicine) =>
                (medicine.name?.toLowerCase().contains(query) ?? false) ||
                (medicine.genericName?.toLowerCase().contains(query) ?? false) ||
                (medicine.barcode?.toLowerCase().contains(query) ?? false))
            .toList();
      }
    });
  }
  // *** END OF ADDED METHOD ***

  Future<void> _fetchMedicines() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // Construct the API URL with pagination parameters
    final uri = Uri.parse('http://10.0.2.2:8000/api/medicines/?page=$_page&page_size=$_pageSize');
    
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final newMedicines = data.map((json) => Medicine.fromJson(json)).toList();
      
      setState(() {
        // Append new data to the existing list
        _medicines.addAll(newMedicines);
        _isLoading = false;
        _page++; // Increment page for the next fetch
        // Check if we've received fewer items than the page size, meaning no more data
        if (newMedicines.length < _pageSize) {
          _hasMore = false;
        }
        // *** ADDED: FILTER MEDICINES AFTER FETCHING ***
        _filterMedicines(); 
      });
    } else {
      setState(() {
        _isLoading = false;
        // Stop trying to fetch if there's an error
        _hasMore = false;
      });
      throw Exception('Failed to load medicines');
    }
  }

  void _editMedicine(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicinePage(medicine: medicine.toJson()),
      ),
    ).then((_) {
      _refreshList();
    });
  }

  void _deleteMedicine(int? id) async {
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this medicine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Get staff ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id'); // assumes it's saved during login

    // Attach staff_id as query parameter
    final uri = Uri.parse('http://10.0.2.2:8000/api/medicines/$id/?staff_id=$staffId');

    final response = await http.delete(uri);

    if (response.statusCode == 204) {
      _refreshList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete medicine')),
      );
    }
  }

  void _onAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMedicineScreen(),
      ),
    ).then((_) {
      _refreshList();
    });
  }

  // Helper function to reset and fetch data
  // *** MODIFIED _refreshList METHOD ***
  void _refreshList() {
    setState(() {
      _medicines = [];
      _filteredMedicines = [];
      _page = 1;
      _hasMore = true;
      _searchController.clear();
      _isSearching = false;
    });
    _fetchMedicines();
  }
  // *** END OF MODIFIED _refreshList METHOD ***

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // *** MODIFIED: DYNAMIC TITLE AND SEARCH BAR ***
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            : const Text('Medicine List'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
        // *** ADDED: SEARCH BUTTON AND FUNCTIONALITY ***
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshList();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: _medicines.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator())
            // *** MODIFIED: CHECK FILTERED LIST FOR EMPTY STATE ***
            : _filteredMedicines.isEmpty && !_isLoading && !_isSearching
                ? const Center(child: Text('No medicines found.'))
                // *** MODIFIED: USE _filteredMedicines LIST FOR THE VIEWS ***
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredMedicines.length + (_hasMore && !_isSearching ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Check if this is the last item and we have more to load
                      if (index == _filteredMedicines.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final med = _filteredMedicines[index];
                      
                      // ✅ START OF NEW UI LOGIC based on ID Prioritization
                      const deletedPlaceholder = '[Supplier Deleted]';
                      
                      // 1. Check the status
                      final isSupplierDeletedPlaceholder = med.supplierName == deletedPlaceholder;
                      final isSupplierIdPresent = med.supplier != null && med.supplier!.isNotEmpty;
                      
                      String supplierDisplayString;
                      TextStyle supplierTextStyle;
                      
                      if (isSupplierDeletedPlaceholder) {
                        if (isSupplierIdPresent) {
                          // Case A: Name is placeholder, but ID is linked. Alert state.
                          supplierDisplayString = 'ID: ${med.supplier!} (Name Missing)';
                          supplierTextStyle = const TextStyle(
                          );
                        } else {
                          // Case B: Name is placeholder, and ID is NOT linked. Confirmed deleted.
                          supplierDisplayString = deletedPlaceholder;
                          supplierTextStyle = const TextStyle(
                          );
                        }
                      } else {
                        // Case C: Name is resolved/present (or null, which is handled by ?? "-")
                        supplierDisplayString = med.supplierName ?? '-';
                        supplierTextStyle = TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[700],
                        );
                      }
                      // ❌ END OF NEW UI LOGIC ❌

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(med.name ?? 'Unnamed'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Barcode No: ${med.barcode ?? "-"}'),
                              Text('Generic Name: ${med.genericName ?? "-"}'),
                              
                              // *** MODIFIED: Display and style for Supplier Name/ID ***
                              Text(
                                'Supplier: $supplierDisplayString',
                                style: supplierTextStyle,
                              ),
                              // *** END OF MODIFICATION ***
                              
                              Text('Category: ${med.category ?? "-"}'),
                              Text('Dosage Form: ${med.dosageForm ?? "-"}'),
                              Text('Prescription Required: ${med.prescriptionRequired == true ? "Yes" : "No"}'),
                              Text('Quantity: ${med.quantity ?? 0}'),
                              Text('Price: ₱${(med.price ?? 0.0).toStringAsFixed(2)}'),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editMedicine(med),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteMedicine(med.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddMedicine,
        tooltip: 'Add Medicine',
        child: const Icon(Icons.add),
      ),
    );
  }
}