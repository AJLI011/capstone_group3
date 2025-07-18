import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
 
import 'edit_medicines_list.dart';

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
      'supplier': supplier, // This should be the supplier ID if your backend expects it for updates
      'supplier_name': supplierName, // This is usually for display, not for sending back to API
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
  late Future<List<Medicine>> futureMedicines;

  @override
  void initState() {
    super.initState();
    futureMedicines = fetchMedicines();
  }

  Future<List<Medicine>> fetchMedicines() async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/medicines/'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Medicine.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load medicines');
    }
  }

  void _editMedicine(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicinePage(medicine: medicine.toJson()), // Changed here
      ),
    ).then((_) {
      // Refresh list after editing
      setState(() {
        futureMedicines = fetchMedicines();
      });
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

    final response = await http.delete(
      Uri.parse('http://10.0.2.2:8000/api/medicines/$id/'),
    );

    if (response.statusCode == 204) {
      setState(() {
        futureMedicines = fetchMedicines();
      });
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Medicine'),
        content: const Text('Add medicine form goes here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine List'),
      ),
      body: FutureBuilder<List<Medicine>>(
        future: futureMedicines,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No medicines found.'));
          }

          final medicines = snapshot.data!;
          return ListView.builder(
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final med = medicines[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(med.name ?? 'Unnamed'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Barcode No: ${med.barcode ?? "-"}'),
                      Text('Generic Name: ${med.genericName ?? "-"}'),
                      Text('Category: ${med.category ?? "-"}'),
                      Text('Dosage Form: ${med.dosageForm ?? "-"}'),
                      Text('Supplier: ${med.supplierName ?? "-"}'),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddMedicine,
        tooltip: 'Add Medicine',
        child: const Icon(Icons.add),
      ),
    );
  }
}