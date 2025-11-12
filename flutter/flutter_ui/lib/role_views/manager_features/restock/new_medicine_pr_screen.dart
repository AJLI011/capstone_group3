import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// The import path is correct:
import '../../manager_features/medicines_list/add_medicines_list.dart';// This file contains AddMedicineScreen


// --- MODEL FOR NEW MEDICINE ITEM ---
class NewMedicinePrItem {
  final int id;
  final String medicineNameSnapshot;
  final int restockAmount;
  final String supplierNameSnapshot;
  final bool isSupplierRegistered;
  final bool isClickable;

  NewMedicinePrItem({
    required this.id,
    required this.medicineNameSnapshot,
    required this.restockAmount,
    required this.supplierNameSnapshot,
    required this.isSupplierRegistered,
    required this.isClickable,
  });

  factory NewMedicinePrItem.fromJson(Map<String, dynamic> json) {
    return NewMedicinePrItem(
      id: json['id'],
      medicineNameSnapshot: json['medicine_name_snapshot'] ?? 'N/A',
      restockAmount: json['restock_amount'] ?? 0,
      supplierNameSnapshot: json['supplier_name_snapshot'] ?? 'N/A',
      isSupplierRegistered: json['is_supplier_registered'] ?? false,
      isClickable: json['is_clickable'] ?? false,
    );
  }
}

// --- SCREEN WIDGET ---
class NewMedicinePrScreen extends StatefulWidget {
  const NewMedicinePrScreen({super.key});

  @override
  State<NewMedicinePrScreen> createState() => _NewMedicinePrScreenState();
}

class _NewMedicinePrScreenState extends State<NewMedicinePrScreen> {
  // Use a nullable Future variable to manage the data fetching lifecycle
  Future<List<NewMedicinePrItem>>? _fetchItemsFuture;
  
  // IMPORTANT: Replace the base URL with your actual Django server address
  final String _apiUrl = 'http://10.0.2.2:8000/api/restock/purchase-request/new-medicines/'; 

  @override
  void initState() {
    super.initState();
    // Start fetching the data immediately
    _fetchItemsFuture = _fetchNewMedicineItems();
  }
  
  // Function to refresh the list manually or after a successful item processing
  void _refreshList() {
    setState(() {
      _fetchItemsFuture = _fetchNewMedicineItems();
    });
  }

  // --- API CALL TO FETCH ITEMS ---
  Future<List<NewMedicinePrItem>> _fetchNewMedicineItems() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List itemsJson = data['items'];
        
        return itemsJson.map((json) => NewMedicinePrItem.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        // Handle no pending PR found
        return [];
      } else {
        throw Exception('Failed to load items. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  // --- ITEM TAP HANDLER ---
  void _onItemTap(NewMedicinePrItem item) async {
    if (item.isClickable) {
      // Navigate to the "Add New Medicine" screen
      
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          // FIX 1: Use the correct class name: AddMedicineScreen
          builder: (context) => AddMedicineScreen( 
            prItemId: item.id,
            initialName: item.medicineNameSnapshot,
            // We removed initialSupplierName, so we don't pass it here.
          ),
        ),
      );
      
      // FIX 2: Check if the result is an integer (the new medicine ID)
      if (result is int) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Medicine "${item.medicineNameSnapshot}" successfully onboarded and linked!')),
          );
        }
        // Refresh the list to remove the processed item
        _refreshList(); 
        
        // Return true to the previous screen (RestockMenuScreen) so it can refresh its PR status
        // We can pass a boolean back here as confirmation to the parent screen.
        Navigator.of(context).pop(true); 
      }

    } else {
      // If not clickable, show the reason (supplier not registered)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action Required: Supplier "${item.supplierNameSnapshot}" must be registered first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Medicine Requests'),
        backgroundColor: const Color(0xFF5C7C9A), // Consistent color with menu
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshList,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: FutureBuilder<List<NewMedicinePrItem>>(
        future: _fetchItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No new medicine requests pending onboarding.'),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                
                // Determine icon and color based on status
                Color tileColor = item.isClickable 
                    ? Colors.green.shade50 
                    : Colors.red.shade50; // Red tint if action is needed (not clickable)
                
                Icon leadingIcon = item.isClickable
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.warning, color: Colors.red);

                String subtitleText = item.isClickable
                    ? 'Status: Ready for Onboarding'
                    : 'Status: Supplier "${item.supplierNameSnapshot}" not yet registered.';

                return Card(
                  color: tileColor,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    onTap: item.isClickable ? () => _onItemTap(item) : null, // Disable tap if not clickable
                    leading: leadingIcon,
                    title: Text(
                      '${item.medicineNameSnapshot} (Qty: ${item.restockAmount})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Requested Supplier: ${item.supplierNameSnapshot}'),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            color: item.isClickable ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: item.isClickable
                        ? const Icon(Icons.arrow_forward_ios, size: 16)
                        : const Icon(Icons.lock, color: Colors.grey),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}