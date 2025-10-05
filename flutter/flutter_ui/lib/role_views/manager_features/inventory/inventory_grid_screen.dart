import 'package:flutter/material.dart';
import 'inventory_detail_screen.dart';
import 'total_quantity.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://bluewhiteph.pythonanywhere.com/',
);

// NEW: Define a class to hold the paginated data response from the backend
class InventoryResponse {
  final List<TotalQuantity> items;
  final int totalCount;
  final bool hasMore;

  InventoryResponse({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });
}

class InventoryApiService {
  static const String inventoryPath = 'api/inventory/';
  static const String totalQuantitiesPath = 'api/inventory/total-quantities/';

  // MODIFIED: Accepts search and category, and returns the new InventoryResponse.
  static Future<InventoryResponse> fetchInventoryItems({
    int limit = 10,
    int offset = 0,
    String? searchQuery, // NEW parameter
    String? category, // NEW parameter
  }) async {
    try {
      // 1. Construct the base URL with pagination parameters
      String url = '$API_BASE$inventoryPath?limit=$limit&offset=$offset';

      // 2. Append search query if provided (using Uri.encodeQueryComponent for safety)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&q=${Uri.encodeQueryComponent(searchQuery)}';
      }

      // 3. Append category filter if provided
      if (category != null && category.isNotEmpty) {
        url += '&category=$category';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // MODIFIED: Decode the entire JSON response object
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Extract the list of items
        final List<dynamic> data = responseData['items'] ?? [];
        final List<TotalQuantity> items = data.map((json) => TotalQuantity.fromJson(json)).toList();

        // Return the InventoryResponse object with the total count from the server
        return InventoryResponse(
          items: items,
          totalCount: responseData['total_count'] ?? 0,
          hasMore: responseData['has_more'] ?? false,
        );
      } else {
        throw Exception('Failed to load inventory data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching inventory: $e');
    }
  }

  // ✅ Total quantity sync function (no changes)
  static Future<void> syncTotalQuantities() async {
    try {
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
  final ScrollController _scrollController = ScrollController();
  List<TotalQuantity> _items = [];
  String _selectedCategory = '';
  bool _sortAZ = true;
  bool _showSearch = false;
  String _searchQuery = '';

  // Lazy loading state variables
  int _offset = 0;
  final int _limit = 10;
  bool _isLoading = false;
  bool _hasMoreItems = true;
  // NEW: Total count of items that match the current search/filter (from backend)
  int _totalCount = 0;

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
    _scrollController.addListener(_onScroll);
    syncAndLoadInventory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // MODIFIED: Function to check if the user has reached the end of the list.
  void _onScroll() {
    // Load a little earlier (e.g., 200 pixels from the end)
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreItems) {
      loadMoreItems();
    }
  }
  
  // NEW: Handler for search query changes that triggers a full reset and API reload
  void _onSearchChanged(String value) {
     setState(() => _searchQuery = value);
     syncAndLoadInventory(); // Full reset and load with new query
  }
  
  // NEW: Handler for category changes that triggers a full reset and API reload
  void _onCategoryChanged(String value) {
     setState(() => _selectedCategory = value);
     syncAndLoadInventory(); // Full reset and load with new filter
  }

  // MODIFIED: Function to reset state and load the first page (used for initial load, search, and filter)
  Future<void> syncAndLoadInventory() async {
    setState(() {
      _items = [];
      _offset = 0;
      _totalCount = 0; // Reset total count
      _hasMoreItems = true;
    });
    await InventoryApiService.syncTotalQuantities();
    await loadInventory();
  }

  // MODIFIED: Core function to fetch data
  Future<void> loadInventory() async {
    // Prevent multiple simultaneous API calls or loading when no more items exist.
    if (_isLoading || !_hasMoreItems) return;
    setState(() => _isLoading = true);
    try {
      // MODIFIED: Pass all filter/search parameters
      final response = await InventoryApiService.fetchInventoryItems(
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery,
        category: _selectedCategory,
      );

      setState(() {
        _items.addAll(response.items);
        _offset += _limit;
        // UPDATE state based on backend response
        _totalCount = response.totalCount;
        _hasMoreItems = response.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading inventory: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> loadMoreItems() async {
    if (_isLoading || !_hasMoreItems) return;
    await loadInventory();
  }

  // MODIFIED: Renamed to _sortedItems. The backend now handles filtering/searching. 
  // This local getter only handles sorting.
List<TotalQuantity> get _sortedItems {
    // 1. Create a mutable copy of ALL loaded items
    final List<TotalQuantity> items = List.from(_items); 

    // 2. Define the comparison function (case-insensitive)
    int compareName(TotalQuantity a, TotalQuantity b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    // 3. Apply the sort based on the toggle state
    if (_sortAZ) {
      // Sort A-Z (Default behavior)
      items.sort(compareName);
    } else {
      // Sort Z-A
      items.sort((a, b) => compareName(b, a)); // Reverse comparison
    }
    
    // 4. Return the fully sorted, accumulated list.
    return items;
}

  @override
  Widget build(BuildContext context) {
    // Use the locally sorted list for display
    final displayItems = _sortedItems;

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
                // Important: When closing the search, reset the query and reload
                if (!_showSearch) {
                   _onSearchChanged(''); 
                }
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
                // MODIFIED: Use the new search handler that resets pagination
                onChanged: _onSearchChanged, 
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
                    // MODIFIED: Use the new category handler that resets pagination
                    onChanged: (value) {
                      _onCategoryChanged(value ?? '');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            // MODIFIED: Check against total count and loading state for "No medicines" message
            child: displayItems.isEmpty && !_isLoading 
                ? Center(child: Text(_totalCount == 0 ? 'No medicines available.' : 'Loading...'))
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    // MODIFIED: Use displayItems.length for the item count
                    itemCount: displayItems.length + (_isLoading && _hasMoreItems ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Check if the current index is the last item (for the loading indicator)
                      if (index == displayItems.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final item = displayItems[index];
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