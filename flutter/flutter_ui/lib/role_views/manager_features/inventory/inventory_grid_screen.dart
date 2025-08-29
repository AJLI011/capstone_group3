import 'package:flutter/material.dart';
import 'inventory_detail_screen.dart';
import 'total_quantity.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class InventoryApiService {
  static const String inventoryUrl = 'https://aaron.pythonanywhere.com/api/inventory/';

  static Future<List<TotalQuantity>> fetchInventoryItems() async {
    try {
      final response = await http.get(Uri.parse(inventoryUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => TotalQuantity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load inventory data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching inventory: $e');
    }
  }

  // ✅ Total quantity sync function
  static Future<void> syncTotalQuantities() async {
    try {
      final response = await http.get(
        Uri.parse('https://aaron.pythonanywhere.com/api/inventory/total-quantities'),
      );
      if (response.statusCode == 200) {
        print('✅ Total quantity synced');
      } else {
        print('❌ Failed to sync: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error syncing total quantity: $e');
    }
  }
}

class InventoryGridScreen extends StatefulWidget {
  const InventoryGridScreen({super.key});

  @override
  State<InventoryGridScreen> createState() => _InventoryGridScreenState();
}

class _InventoryGridScreenState extends State<InventoryGridScreen> {
  List<TotalQuantity> _items = [];
  String _selectedCategory = '';
  bool _sortAZ = true;
  bool _showSearch = false;
  String _searchQuery = '';

  final List<Map<String, String>> _categoryChoices = [
    {'value': '', 'label': 'Categories'},
    {'value': 'analgesics', 'label': 'Analgesics'},
    {'value': 'antibiotics', 'label': 'Antibiotics'},
    {'value': 'antivirals', 'label': 'Antivirals'},
    {'value': 'antihypertensives', 'label': 'Antihypertensives'},
    {'value': 'antidiabetics', 'label': 'Antidiabetics'},
    {'value': 'gastrointestinal_medicines', 'label': 'Gastrointestinal Medicines'},
    {'value': 'antihistamines', 'label': 'Antihistamines'},
    {'value': 'cough_and_cold_medicines', 'label': 'Cough and Cold Medicines'},
    {'value': 'vitamins_and_supplements', 'label': 'Vitamins and Supplements'},
    {'value': 'cardiovascular_medicines', 'label': 'Cardiovascular Medicines'},
    {'value': 'anti_asthma_and_respiratory_medicines', 'label': 'Anti-asthma and Respiratory Medicines'},
    {'value': 'antimalarials', 'label': 'Antimalarials'},
    {'value': 'antiparasitics', 'label': 'Antiparasitics'},
  ];

  @override
  void initState() {
    super.initState();
    syncAndLoadInventory();
  }

  Future<void> syncAndLoadInventory() async {
    await InventoryApiService.syncTotalQuantities();
    await loadInventory();
  }

  Future<void> loadInventory() async {
    try {
      final fetchedItems = await InventoryApiService.fetchInventoryItems();
      setState(() => _items = fetchedItems);
    } catch (e) {
      print("Error loading inventory: $e");
    }
  }

  List<TotalQuantity> get _filteredItems {
    final filtered = _items.where((item) {
      final matchesCategory =
          _selectedCategory.isEmpty || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.genericName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    filtered.sort((a, b) =>
        _sortAZ ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_sortAZ ? Icons.sort_by_alpha : Icons.sort),
            onPressed: () {
              setState(() => _sortAZ = !_sortAZ);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                _searchQuery = '';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryChoices.map((choice) {
                      return DropdownMenuItem<String>(
                        value: choice['value'],
                        child: Text(choice['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value ?? '');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF396AAB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Promo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(
                            color: const Color(0xFF396AAB),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InventoryDetailScreen(item: item),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              // I've wrapped the Column with a Center widget
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 16.0, // Added more vertical padding
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center, // Center contents vertically
                                    crossAxisAlignment: CrossAxisAlignment.center, // Center contents horizontally
                                    children: [
                                      if (item.image.isNotEmpty)
                                        SizedBox(
                                          height: 125, // Increased height
                                          child: Image.network(
                                            item.image,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                                          ),
                                        )
                                      else
                                        const SizedBox(
                                          height: 120,
                                          child: Center(
                                            child: Icon(Icons.medication, size: 80, color: Colors.grey),
                                          ),
                                        ),
                                      const SizedBox(height: 10), // Increased spacing
                                      Text(
                                        item.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.genericName,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF396AAB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Qty: ${item.totalQuantity}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}