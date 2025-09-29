import 'package:flutter/material.dart';
import 'inventory_detail_screen.dart';
import 'total_quantity.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000/',
);

class InventoryApiService {
  // MODIFIED: Replaced the hardcoded URL with a constant that uses the API_BASE.
  static const String inventoryPath = 'api/inventory/';
  static const String totalQuantitiesPath = 'api/inventory/total-quantities/';

  // MODIFIED: Added limit and offset parameters to support lazy loading.
  static Future<List<TotalQuantity>> fetchInventoryItems({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      // MODIFIED: Use the API_BASE constant to construct the full URL.
      // The limit and offset query parameters are appended to the URL.
      final url = '$API_BASE$inventoryPath?limit=$limit&offset=$offset';
      final response = await http.get(Uri.parse(url));

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
      // MODIFIED: Use the API_BASE constant to construct the full URL.
      final url = '$API_BASE$totalQuantitiesPath';
      final response = await http.get(Uri.parse(url));
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
  // NEW: A ScrollController to listen for scrolling events.
  final ScrollController _scrollController = ScrollController();
  List<TotalQuantity> _items = [];
  String _selectedCategory = '';
  bool _sortAZ = true;
  bool _showSearch = false;
  String _searchQuery = '';

  // NEW: State variables to manage the lazy loading process.
  int _offset = 0;
  final int _limit = 10;
  bool _isLoading = false;
  bool _hasMoreItems = true;

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
    // NEW: Add a listener to the ScrollController.
    _scrollController.addListener(_onScroll);
    syncAndLoadInventory();
  }

  @override
  void dispose() {
    // NEW: Dispose the ScrollController to prevent memory leaks.
    _scrollController.dispose();
    super.dispose();
  }

  // NEW: Function to check if the user has reached the end of the list.
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMoreItems) {
      loadMoreItems();
    }
  }

  Future<void> syncAndLoadInventory() async {
    // NEW: Reset state variables before a new data load.
    setState(() {
      _items = [];
      _offset = 0;
      _hasMoreItems = true;
    });
    await InventoryApiService.syncTotalQuantities();
    await loadInventory();
  }

  Future<void> loadInventory() async {
    // NEW: Prevent multiple simultaneous API calls.
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // MODIFIED: Pass limit and offset to the API service.
      final fetchedItems = await InventoryApiService.fetchInventoryItems(
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _items.addAll(fetchedItems);
        // NEW: Update the offset for the next fetch.
        _offset += _limit;
        // NEW: Check if there are more items to load.
        _hasMoreItems = fetchedItems.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading inventory: $e");
      setState(() => _isLoading = false);
    }
  }

  // NEW: A dedicated function to load more items when scrolled.
  Future<void> loadMoreItems() async {
    if (_isLoading || !_hasMoreItems) return;
    await loadInventory();
  }

  List<TotalQuantity> get _filteredItems {
    final filtered = _items.where((item) {
      final matchesCategory = _selectedCategory.isEmpty || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.genericName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredItems.isEmpty && !_isLoading
                ? const Center(child: Text('No medicines available.'))
                : GridView.builder(
                    // NEW: Assign the ScrollController to the GridView.
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    // NEW: Add an item for the loading indicator if more items are available.
                    itemCount: _filteredItems.length + (_isLoading && _hasMoreItems ? 1 : 0),
                    itemBuilder: (context, index) {
                      // NEW: Check if the current index is the last item.
                      if (index == _filteredItems.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
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
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 16.0,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (item.image.isNotEmpty)
                                        SizedBox(
                                          height: 125,
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
                                      const SizedBox(height: 10),
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