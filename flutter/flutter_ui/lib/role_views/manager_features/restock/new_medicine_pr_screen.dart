import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// The import path is correct:
import '../../manager_features/medicines_list/add_medicines_list.dart';// This file contains AddMedicineScreen


// --- MODEL FOR NEW MEDICINE ITEM ---
class NewMedicinePrItem {
  final int id;
  final String medicineNameSnapshot;
  final int restockAmount; // <-- CRITICAL PARAMETER
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
  // --- API CALL TO FETCH ITEMS (Updated with Null Safety) ---
  Future<List<NewMedicinePrItem>> _fetchNewMedicineItems() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        // Handle the case where the body is empty or malformed defensively
        final Map<String, dynamic> data = json.decode(response.body);

        // 🎯 FIX APPLIED HERE: Safely cast data['items'] and provide [] as fallback
        final List itemsJson = (data['items'] as List<dynamic>?) ?? [];
        
        return itemsJson.map((json) => NewMedicinePrItem.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        // Handle no pending PR found (although 200 with empty list is better)
        return [];
      } else {
        throw Exception('Failed to load items. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Improve error message to show the original error type
      throw Exception('Failed to connect to API or parse data: $e');
    }
  }

  // --- ITEM TAP HANDLER (MODIFIED) ---
  void _onItemTap(NewMedicinePrItem item) async {
    if (item.isClickable) {
      // Navigate to the "Add New Medicine" screen
      
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddMedicineScreen( 
            prItemId: item.id,
            initialName: item.medicineNameSnapshot,
            restockAmount: item.restockAmount, // <--- NEW: Pass the restock amount
          ),
        ),
      );
      
      // The AddMedicineScreen now uses pushReplacement to navigate 
      // directly to RestockDetailsPage upon success.
      // Therefore, the result here will be what RestockDetailsPage returns, 
      // or null if the user simply navigated back.
      
      // Since the successful flow jumps past this screen, 
      // we only need to handle the case where the user pops back (result is null or false)
      // or where the RestockDetailsPage confirms completion.
      
      // If the successful flow is completed (up to RestockDetailsPage), 
      // AddMedicineScreen will have already refreshed the list implicitly by navigating away.
      
      // We check if a successful refresh/change signal was passed back (e.g., a boolean true)
      if (result == true) { 
        // This handles a clean return from the Restock flow 
        // (if RestockDetailsPage pops back to this screen)
        _refreshList(); 
        if (mounted) {
           // Optionally, pop back to the main menu if the restock flow is complete
           // Navigator.of(context).pop(true); // Uncomment if you want to pop to the RestockMenuScreen
        }
      } else if (result != null) {
          // If the result is an unexpected value but not null, refresh anyway.
          _refreshList();
      }
      
      // NOTE: The previous logic checking for 'result is int' is now handled 
      // inside AddMedicineScreen via pushReplacement to RestockDetailsPage.

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
        title: const Text('New Purchased Items'),
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